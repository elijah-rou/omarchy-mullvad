import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Talks to mullvad-daemon through the `mullvad` CLI. Tunnel state streams from
// `mullvad status --json listen`; settings come straight from the daemon's
// world-readable settings.json; account and relay list are polled.
Item {
  id: root

  property var settings: ({})

  readonly property string settingsPath: "/etc/mullvad-vpn/settings.json"

  property bool daemonRunning: false
  property string tunnelState: "unknown"
  property bool lockedDown: false
  property bool blocking: false
  property string blockFailure: ""
  property string errorCause: ""
  property string hostname: ""
  property string city: ""
  property string country: ""
  property string ipv4: ""
  property string ipv6: ""

  property bool accountKnown: false
  property bool loggedIn: false
  property string accountNumber: ""
  property string accountExpiry: ""
  property string deviceName: ""

  property var countries: []
  property var daemonSettings: ({ ok: false })

  property string actionStatus: ""
  property string lastError: ""
  property string pendingAction: ""

  // Optimistic target while connect/disconnect catch up, so the switch throws
  // the moment it is clicked: -1 follows the daemon, 0/1 hold off/on.
  property int _desired: -1

  readonly property bool connected: tunnelState === "connected"
  readonly property bool transitioning: tunnelState === "connecting" || tunnelState === "disconnecting"
  readonly property bool tunnelUp: tunnelState === "connected" || tunnelState === "connecting" || tunnelState === "error"
  readonly property bool active: _desired === -1 ? tunnelUp : _desired === 1
  readonly property bool busy: actionProcess.running || loginProcess.running
  readonly property bool problem: daemonRunning && (tunnelState === "error" || (tunnelState === "disconnected" && lockedDown))
  readonly property var location: daemonSettings.ok ? daemonSettings.location : null
  readonly property string locationText: Model.locationLabel(location, countries)
  readonly property string expiryText: Model.expiryLabel(accountExpiry, Date.now())
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 15, 3600)

  property string _accountOutput: ""
  property string _relaysOutput: ""
  property string _actionOutput: ""
  property string _actionError: ""
  property string _loginOutput: ""
  property string _loginError: ""
  property int _relayRetries: 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function elide(text) {
    var value = String(text || "").replace(/^Error:\s*/m, "").replace(/\s+/g, " ").trim()
    return value.length > 160 ? value.substring(0, 157) + "…" : value
  }

  function refresh() {
    if (!listenProcess.running) listenProcess.running = true
    settingsFile.reload()
    refreshAccount()
    if (countries.length === 0) refreshRelays()
  }

  function refreshAccount() {
    if (accountProcess.running) return
    _accountOutput = ""
    accountProcess.running = true
    if (!pollWatchdog.running) pollWatchdog.start()
  }

  function refreshRelays() {
    if (relaysProcess.running) return
    _relaysOutput = ""
    relaysProcess.running = true
    if (!pollWatchdog.running) pollWatchdog.start()
  }

  function applyStatus(line) {
    var parsed = Model.parseStatus(line)
    if (!parsed.ok) return
    // The daemon-down message is only true until the daemon answers again.
    if (!daemonRunning) lastError = ""
    daemonRunning = true
    tunnelState = parsed.state
    lockedDown = parsed.lockedDown
    blocking = parsed.blocking
    blockFailure = parsed.blockFailure
    errorCause = parsed.errorCause
    hostname = parsed.hostname
    city = parsed.city
    country = parsed.country
    ipv4 = parsed.ipv4
    ipv6 = parsed.ipv6
    if (_desired !== -1 && tunnelUp === (_desired === 1) && !transitioning) _desired = -1
    // Settings changes reconnect the tunnel, and settings.json is replaced
    // rather than rewritten, so a state change is the cue to re-read it.
    settingsFile.reload()
  }

  function markDaemonDown(message) {
    daemonRunning = false
    tunnelState = "unknown"
    _desired = -1
    lastError = elide(message)
  }

  function toggleConnection() {
    if (busy) return
    if (active) disconnect()
    else connect()
  }

  function connect() {
    // Connecting without an account makes the daemon block all traffic until
    // someone logs in or disconnects, so never start a tunnel while logged out.
    if (!daemonRunning || !loggedIn) {
      flash(loggedIn ? "Mullvad daemon is not running" : "Log in to a Mullvad account first")
      return
    }
    if (runAction(["mullvad", "connect"], "")) _desired = 1
  }

  function disconnect() {
    if (runAction(["mullvad", "disconnect"], "")) _desired = 0
  }

  function reconnect() {
    if (!tunnelUp) return
    runAction(["mullvad", "reconnect"], "Reconnecting…")
  }

  function selectLocation(countryCode, cityCode) {
    var command = ["mullvad", "relay", "set", "location", countryCode]
    if (cityCode !== "") command.push(cityCode)
    // Changing the location reconnects an active tunnel by itself; picking a
    // location while off should connect, like the Mullvad app.
    var connectAfter = !tunnelUp && loggedIn
    if (connectAfter) command = ["sh", "-c", command.map(Util.shellQuote).join(" ") + " && mullvad connect"]
    if (runAction(command, "") && connectAfter) _desired = 1
  }

  function setFlag(kind, on) {
    var value = on ? "on" : "off"
    var commands = {
      autoConnect: ["mullvad", "auto-connect", "set", value],
      lockdownMode: ["mullvad", "lockdown-mode", "set", value],
      allowLan: ["mullvad", "lan", "set", on ? "allow" : "block"],
      multihop: ["mullvad", "relay", "set", "multihop", value],
      quantumResistant: ["mullvad", "tunnel", "set", "quantum-resistant", value],
      daita: ["mullvad", "tunnel", "set", "daita", value],
      ipv6: ["mullvad", "tunnel", "set", "ipv6", value]
    }
    var command = commands[kind]
    if (!command) {
      console.warn("mullvad", "unknown setting", kind)
      return
    }
    runAction(command, "")
  }

  function toggleDnsBlocker(key) {
    if (!daemonSettings.ok || daemonSettings.customDns) return
    runAction(Model.dnsCommand(daemonSettings.dnsBlockers, key), "")
  }

  function login(input) {
    var number = Model.normalizeAccountInput(input)
    if (number === "") return
    if (!Model.isAccountNumber(number)) {
      flash("An account number is 16 digits")
      return
    }
    if (loginProcess.running || actionProcess.running) return
    _loginOutput = ""
    _loginError = ""
    actionStatus = "Logging in…"
    // The account number goes over stdin so it never shows in the process list.
    loginProcess.secret = number
    loginProcess.stdinEnabled = true
    loginProcess.command = ["mullvad", "account", "login"]
    loginProcess.running = true
  }

  function createAccount() {
    runAction(["mullvad", "account", "create"], "Creating account…")
  }

  function logout() {
    // Drop the tunnel first so an active connection is never left behind
    // without an account to authenticate it.
    if (runAction(["sh", "-c", "mullvad disconnect && mullvad account logout"], "Logging out…")) _desired = -1
  }

  function startDaemon() {
    runAction(["pkexec", "systemctl", "enable", "--now", "mullvad-daemon"], "Starting mullvad-daemon…")
  }

  function openAccountPage() {
    Quickshell.execDetached(["omarchy-launch-browser", "https://mullvad.net/account"])
  }

  function copyAccountNumber() {
    if (accountNumber === "" || copyProcess.running) return
    // Passed through the environment, which only this user can read, rather
    // than argv, which every user can.
    copyProcess.environment = { MULLVAD_COPY_VALUE: accountNumber }
    copyProcess.running = true
    flash("Account number copied")
  }

  function flash(message) {
    actionStatus = message
    actionStatusTimer.restart()
  }

  // Returns whether the command started; callers only record optimistic
  // state for a command that is actually running.
  function runAction(command, label) {
    if (actionProcess.running || loginProcess.running) return false
    _actionOutput = ""
    _actionError = ""
    pendingAction = command.join(" ")
    actionStatus = label
    actionProcess.command = command
    actionProcess.running = true
    return true
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.daemonSettings = Model.parseSettings(text())
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    // The daemon only downloads the relay list once an account is logged in,
    // and does it in the background after login, so poll briefly until it
    // lands instead of waiting for the next periodic refresh.
    id: relayRetryTimer
    interval: 3000
    repeat: false
    onTriggered: root.refreshRelays()
  }

  Timer {
    // A poll that hangs would block every later refresh of the same kind, so
    // reap anything still running well inside the refresh interval.
    id: pollWatchdog
    interval: 15000
    repeat: false
    onTriggered: {
      if (accountProcess.running) accountProcess.running = false
      if (relaysProcess.running) relaysProcess.running = false
    }
  }

  Timer {
    // The daemon's state is authoritative: if no matching status event arrives
    // shortly after the command finished, stop showing the optimistic one.
    id: desiredResetTimer
    interval: 5000
    repeat: false
    onTriggered: root._desired = -1
  }

  Timer {
    id: listenRestartTimer
    interval: 5000
    repeat: false
    onTriggered: if (!listenProcess.running) listenProcess.running = true
  }

  Timer {
    id: actionStatusTimer
    interval: 2600
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: listenProcess
    command: ["mullvad", "status", "--json", "listen"]
    running: false
    stdout: SplitParser { onRead: function(line) { root.applyStatus(line) } }
    stderr: StdioCollector { id: listenStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var stderr = String(listenStderr.text || "")
      root.markDaemonDown(/connect to mullvad-daemon/i.test(stderr) ? "mullvad-daemon is not running" : stderr)
      listenRestartTimer.restart()
    }
  }

  Process {
    id: accountProcess
    command: ["mullvad", "account", "get"]
    running: false
    stdout: StdioCollector { id: accountStdout; waitForEnd: true; onStreamFinished: root._accountOutput = text }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var parsed = Model.parseAccount(String(accountStdout.text || root._accountOutput || ""))
      var wasLoggedIn = root.loggedIn
      root.accountKnown = true
      root.loggedIn = parsed.loggedIn
      root.accountNumber = parsed.accountNumber
      root.accountExpiry = parsed.expiry
      root.deviceName = parsed.deviceName
      if (parsed.loggedIn && !wasLoggedIn) {
        root._relayRetries = 0
        root.refreshRelays()
      }
    }
  }

  Process {
    id: relaysProcess
    command: ["mullvad", "relay", "list"]
    running: false
    stdout: StdioCollector { id: relaysStdout; waitForEnd: true; onStreamFinished: root._relaysOutput = text }
    onExited: function(exitCode) {
      var parsed = exitCode === 0 ? Model.parseRelayList(String(relaysStdout.text || root._relaysOutput || "")) : []
      if (parsed.length > 0) {
        root.countries = parsed
        root._relayRetries = 0
      } else if (root.loggedIn && root._relayRetries < 10) {
        root._relayRetries += 1
        relayRetryTimer.restart()
      }
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true; onStreamFinished: root._actionOutput = text }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true; onStreamFinished: root._actionError = text }
    onExited: function(exitCode) {
      var stdout = String(actionStdout.text || root._actionOutput || "")
      var stderr = String(actionStderr.text || root._actionError || "")
      root.pendingAction = ""
      if (exitCode !== 0) {
        root._desired = -1
        root.lastError = root.elide(stderr || stdout || "mullvad command failed")
        root.actionStatus = ""
      } else {
        root.lastError = ""
        root.actionStatus = ""
      }
      settingsFile.reload()
      root.refreshAccount()
      if (root._desired !== -1) desiredResetTimer.restart()
      if (!listenProcess.running) listenRestartTimer.restart()
    }
  }

  Process {
    id: loginProcess
    property string secret: ""
    running: false
    command: []
    stdinEnabled: true
    onStarted: {
      write(secret + "\n")
      secret = ""
      stdinEnabled = false
    }
    stdout: StdioCollector { id: loginStdout; waitForEnd: true; onStreamFinished: root._loginOutput = text }
    stderr: StdioCollector { id: loginStderr; waitForEnd: true; onStreamFinished: root._loginError = text }
    onExited: function(exitCode) {
      var stdout = String(loginStdout.text || root._loginOutput || "")
      var stderr = String(loginStderr.text || root._loginError || "")
      if (exitCode !== 0) {
        root.lastError = root.elide(stderr || stdout || "Login failed")
        root.actionStatus = ""
      } else {
        root.lastError = ""
        root.flash("Logged in")
      }
      root.refreshAccount()
    }
  }

  Process {
    id: copyProcess
    running: false
    command: ["sh", "-c", "printf %s \"$MULLVAD_COPY_VALUE\" | wl-copy"]
    onExited: environment = {}
  }
}
