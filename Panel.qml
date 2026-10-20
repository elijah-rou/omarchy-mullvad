import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "elijahrou.mullvad"
  ipcTarget: "elijahrou.mullvad"
  manageIpc: false

  // Keyboard cursor: one flat list of row ids in display order, rebuilt from
  // what is visible, so every section navigates the same way.
  property bool cursorActive: false
  property string cursorId: "power"
  property bool pickerOpen: false
  property string locationQuery: ""
  property string expandedCountry: ""
  property bool dnsExpanded: false
  property string confirmId: ""

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  // Dimming is the bar's only on/off signal, so it applies to problem states
  // too. It fades rather than darkens: darkening reads as bolder on a light
  // theme.
  readonly property color barIconTone: mullvad.problem ? root.urgent : barForeground
  readonly property color barIconColor: mullvad.active ? barIconTone : Util.alpha(barIconTone, 0.5)

  readonly property bool showLogin: mullvad.daemonRunning && mullvad.accountKnown && !mullvad.loggedIn
  readonly property bool showConnected: mullvad.daemonRunning && mullvad.loggedIn
  // Logged out but still holding traffic: a tunnel the daemon is keeping up
  // (it blocks while it cannot authenticate) or lockdown mode. Both stay
  // undoable without an account number.
  readonly property bool showRecovery: showLogin && (mullvad.tunnelUp || settingChecked("lockdownMode"))
  readonly property var locationRows: Model.locationRows(mullvad.countries, locationQuery, expandedCountry)
  readonly property var dnsBlockers: Model.DNS_BLOCKERS
  readonly property var settingRows: [
    { kind: "autoConnect", title: "Auto-connect", detail: "Connect when the daemon starts" },
    { kind: "lockdownMode", title: "Lockdown mode", detail: "Block all traffic while the VPN is off" },
    { kind: "allowLan", title: "Local network sharing", detail: "Reach printers and other LAN devices" },
    { kind: "multihop", title: "Multihop", detail: "Route through an entry and an exit server" },
    { kind: "daita", title: "DAITA", detail: "Defend against AI-guided traffic analysis" },
    { kind: "quantumResistant", title: "Quantum-resistant tunnel", detail: "Post-quantum key exchange" },
    { kind: "ipv6", title: "In-tunnel IPv6", detail: "Carry IPv6 traffic through the tunnel" }
  ]
  readonly property int dnsBlockersOn: {
    var count = 0
    if (!mullvad.daemonSettings.ok) return 0
    for (var i = 0; i < dnsBlockers.length; i++) if (mullvad.daemonSettings.dnsBlockers[dnsBlockers[i].key]) count++
    return count
  }
  readonly property var navIds: {
    var ids = []
    if (!mullvad.daemonRunning) return ["startDaemon"]
    if (showLogin) {
      if (mullvad.tunnelUp) ids.push("unblock")
      if (settingChecked("lockdownMode")) ids.push("set:lockdownMode")
      return ids.concat(["loginField", "login", "create"])
    }
    if (!showConnected) return ids
    ids.push("power")
    ids.push("location")
    if (pickerOpen) {
      ids.push("search")
      for (var i = 0; i < locationRows.length; i++) ids.push("loc:" + locationRows[i].id)
    }
    for (var j = 0; j < settingRows.length; j++) ids.push("set:" + settingRows[j].kind)
    ids.push("dns")
    if (dnsExpanded) for (var k = 0; k < dnsBlockers.length; k++) ids.push("dns:" + dnsBlockers[k].key)
    ids.push("acct:copy")
    ids.push("acct:manage")
    ids.push("acct:logout")
    return ids
  }

  readonly property string heroMeta: {
    if (!mullvad.daemonRunning) return "Daemon is not running"
    if (!mullvad.accountKnown) return "Checking…"
    if (mullvad.pendingAction === "mullvad connect" || mullvad.tunnelState === "connecting") return "Connecting…"
    if (mullvad.pendingAction === "mullvad disconnect" || mullvad.tunnelState === "disconnecting") return "Disconnecting…"
    // Blocked or leaking traffic outranks the account state: it is what the
    // user is actually experiencing.
    if (mullvad.tunnelState === "error") return mullvad.blocking ? "Error · blocking all traffic" : "Error · traffic is not blocked"
    if (mullvad.tunnelState === "disconnected" && mullvad.lockedDown) return "Lockdown is blocking traffic"
    if (!mullvad.loggedIn) return "Not logged in"
    if (mullvad.tunnelState === "connected") return "Connected"
    return "Disconnected"
  }

  readonly property string heroDetail: {
    if (!mullvad.daemonRunning) return ""
    if (mullvad.tunnelState === "error") return [mullvad.errorCause, mullvad.blockFailure === "" ? "" : "firewall failed: " + mullvad.blockFailure].filter(function(v) { return v !== "" }).join(" · ")
    var place = [mullvad.city, mullvad.country].filter(function(v) { return v !== "" }).join(", ")
    var parts = []
    if (mullvad.connected && mullvad.hostname !== "") parts.push(mullvad.hostname)
    if (place !== "") parts.push(mullvad.connected ? place : "Visible as " + place)
    if (mullvad.ipv4 !== "") parts.push(mullvad.ipv4)
    return parts.join(" · ")
  }

  function isCursor(id) {
    return cursorActive && cursorId === id
  }

  function settingChecked(kind) {
    return mullvad.daemonSettings.ok && mullvad.daemonSettings[kind] === true
  }

  // Rows are found by walking the panel's item tree rather than kept in a
  // registry, so hot reload and repeater churn cannot leave stale entries.
  function findNavItem(item, id, depth) {
    if (!item || depth > 8) return null
    if (item.navId === id) return item
    var children = item.children || []
    for (var i = 0; i < children.length; i++) {
      var found = findNavItem(children[i], id, depth + 1)
      if (found) return found
    }
    return null
  }

  function setCursor(id) {
    cursorActive = true
    cursorId = id
  }

  function ensureCursor() {
    if (navIds.length === 0) return
    if (navIds.indexOf(cursorId) === -1) cursorId = navIds[0]
  }

  function moveCursor(dy) {
    ensureCursor()
    var index = navIds.indexOf(cursorId)
    var next = Math.max(0, Math.min(navIds.length - 1, index + dy))
    cursorActive = true
    cursorId = navIds[next]
    focusCursorTarget()
    scrollItemIntoView(findNavItem(column, cursorId, 0))
  }

  // Text fields own their keystrokes; the key catcher owns everything else.
  function focusCursorTarget() {
    if (cursorId === "loginField") loginField.forceActiveFocus()
    else if (cursorId === "search") searchField.forceActiveFocus()
    else keyCatcher.forceActiveFocus()
  }

  function leaveField(dy) {
    keyCatcher.forceActiveFocus()
    moveCursor(dy)
  }

  // Destructive or account-creating rows take a second press to confirm.
  function confirmed(id) {
    if (confirmId === id) {
      confirmId = ""
      return true
    }
    confirmId = id
    confirmTimer.restart()
    return false
  }

  function togglePicker() {
    pickerOpen = !pickerOpen
    locationQuery = ""
    expandedCountry = mullvad.location ? String(mullvad.location.country || "") : ""
    if (pickerOpen) {
      if (mullvad.countries.length === 0) mullvad.refreshRelays()
      setCursor("search")
      Qt.callLater(function() { searchField.forceActiveFocus() })
    }
  }

  function chooseLocation(row) {
    if (!row) return
    mullvad.selectLocation(row.country, row.city)
    pickerOpen = false
    setCursor("location")
    keyCatcher.forceActiveFocus()
  }

  function expandCursorCountry(expand) {
    if (cursorId.indexOf("loc:") !== 0) return
    var row = locationRowById(cursorId.substring(4))
    if (!row || locationQuery !== "") return
    if (row.kind === "city") {
      if (!expand) {
        setCursor("loc:" + row.country)
        expandedCountry = ""
      }
      return
    }
    if (row.expandable) expandedCountry = expand ? row.country : ""
  }

  function locationRowById(id) {
    for (var i = 0; i < locationRows.length; i++) if (locationRows[i].id === id) return locationRows[i]
    return null
  }

  function activate(id) {
    if (id === "startDaemon") mullvad.startDaemon()
    else if (id === "unblock") mullvad.disconnect()
    else if (id === "loginField" || id === "login") mullvad.login(loginField.text)
    else if (id === "create") {
      if (confirmed(id)) mullvad.createAccount()
    } else if (id === "power") mullvad.toggleConnection()
    else if (id === "location") togglePicker()
    else if (id === "search") chooseLocation(locationRows.length > 0 ? locationRows[0] : null)
    else if (id.indexOf("loc:") === 0) chooseLocation(locationRowById(id.substring(4)))
    else if (id.indexOf("set:") === 0) {
      var kind = id.substring(4)
      mullvad.setFlag(kind, !settingChecked(kind))
    } else if (id === "dns") dnsExpanded = !dnsExpanded
    else if (id.indexOf("dns:") === 0) mullvad.toggleDnsBlocker(id.substring(4))
    else if (id === "acct:copy") mullvad.copyAccountNumber()
    else if (id === "acct:manage") mullvad.openAccountPage()
    else if (id === "acct:logout") {
      if (confirmed(id)) mullvad.logout()
    } else console.warn("mullvad", "unknown row", id)
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!item) return
      var margin = Style.space(6)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + item.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < panelFlick.contentY + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > panelFlick.contentY + panelFlick.height - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (!opened) {
    loginField.text = ""
  } else {
    cursorActive = false
    confirmId = ""
    pickerOpen = false
    if (panelFlick) panelFlick.contentY = 0
    mullvad.refresh()
    if (showLogin) setCursor("loginField")
  }
  onNavIdsChanged: ensureCursor()

  Service {
    id: mullvad
    settings: root.settings
  }

  Timer {
    id: confirmTimer
    interval: 3000
    repeat: false
    onTriggered: root.confirmId = ""
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { mullvad.refresh(); return "ok" }
    function connect(): string { mullvad.connect(); return "ok" }
    function disconnect(): string { mullvad.disconnect(); return "ok" }
    function toggleConnection(): string { mullvad.toggleConnection(); return "ok" }
    function status(): string { return root.heroMeta }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        MullvadIcon {
          anchors.centerIn: parent
          iconSize: Style.space(13)
          color: root.barIconColor
          badgeColor: root.urgent
          warning: !mullvad.daemonRunning || (mullvad.accountKnown && !mullvad.loggedIn) || mullvad.problem
          pulsing: mullvad.transitioning
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) mullvad.toggleConnection()
      else if (buttonCode === Qt.MiddleButton) mullvad.reconnect()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    // Logged out, the account field is the only thing worth typing into.
    focusTarget: root.showLogin ? loginField : keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The catcher sees keys before its descendants, so it stands aside
      // while a text field is being typed into.
      blocked: loginField.activeFocus || searchField.activeFocus
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else root.expandCursorCountry(dx > 0)
      }
      onActivateRequested: if (root.cursorActive) root.activate(root.cursorId)
      onCloseRequested: {
        if (root.pickerOpen) {
          root.pickerOpen = false
          root.setCursor("location")
        } else {
          root.close()
        }
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "c" || t === "C") mullvad.toggleConnection()
        else if (t === "r" || t === "R") mullvad.reconnect()
        else if (t === "/" && root.showConnected && !root.pickerOpen) root.togglePicker()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            readonly property string navId: "power"
            width: parent.width
            implicitHeight: hero.implicitHeight
            // The hero's trailingControl resolves `root` to PanelHero, so it
            // reaches panel state through `header`.
            readonly property bool ringVisible: root.isCursor("power")
            function focusPower() { root.setCursor("power") }

            PanelHero {
              id: hero
              width: parent.width
              title: "Mullvad VPN"
              meta: root.heroMeta
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: mullvad.active ? 1.0 : 0.5
              iconComponent: Component {
                MullvadIcon {
                  iconSize: Style.font.display
                  color: mullvad.problem ? root.urgent : root.foreground
                  badgeColor: root.urgent
                  warning: mullvad.problem
                  pulsing: mullvad.transitioning
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: root.showConnected
                  checked: mullvad.active
                  busy: mullvad.busy || mullvad.transitioning
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusPower() }
                  onToggled: mullvad.toggleConnection()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: mullvad.active ? "Disconnect" : "Connect"
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            text: root.heroDetail
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            text: mullvad.actionStatus !== "" ? mullvad.actionStatus : mullvad.lastError
            color: mullvad.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          ActionRow {
            visible: !mullvad.daemonRunning
            width: parent.width
            navId: "startDaemon"
            glyph: "󰐥"
            title: "Start mullvad-daemon"
            detail: "Enables the system service; asks for your password"
          }

          // Logged out.

          Column {
            visible: root.showRecovery
            width: parent.width
            spacing: Style.space(4)

            ActionRow {
              visible: mullvad.tunnelUp
              width: parent.width
              navId: "unblock"
              glyph: "󰤭"
              title: "Disconnect"
              detail: "Stop the tunnel so traffic flows again"
            }

            SettingRow {
              visible: root.settingChecked("lockdownMode")
              width: parent.width
              navId: "set:lockdownMode"
              title: "Lockdown mode"
              detail: "On: all traffic is blocked while the VPN is off"
              checked: true
            }
          }

          PanelSeparator { visible: root.showLogin; foreground: root.foreground }

          Column {
            visible: root.showLogin
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "LOG IN"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            TextField {
              id: loginField
              readonly property string navId: "loginField"
              width: parent.width
              foreground: root.foreground
              placeholderText: "Account number"
              hasCursor: root.isCursor("loginField")
              inputMethodHints: Qt.ImhDigitsOnly
              validator: RegularExpressionValidator { regularExpression: /[0-9 ]{0,19}/ }
              onActiveFocusChanged: if (activeFocus) root.setCursor("loginField")
              onAccepted: mullvad.login(text)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                  root.leaveField(1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                  root.leaveField(-1)
                  event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                  keyCatcher.forceActiveFocus()
                  root.close()
                  event.accepted = true
                }
              }
              Connections {
                target: mullvad
                function onLoggedInChanged() {
                  if (!mullvad.loggedIn) return
                  loginField.text = ""
                  // The field is about to hide; hand the keyboard back.
                  if (loginField.activeFocus) keyCatcher.forceActiveFocus()
                }
              }
            }

            ActionRow {
              width: parent.width
              navId: "login"
              glyph: "󰍂"
              title: mullvad.busy && mullvad.actionStatus === "Logging in…" ? "Logging in…" : "Log in"
              detail: Model.isAccountNumber(loginField.text) ? Model.formatAccountNumber(Model.normalizeAccountInput(loginField.text)) : "Enter your 16-digit account number"
            }

            ActionRow {
              width: parent.width
              navId: "create"
              glyph: "󰐕"
              title: root.confirmId === "create" ? "Press again to create an account" : "Create a new account"
              detail: "Creates an account with no time on it and logs in"
            }
          }

          // Logged in.

          PanelSeparator { visible: root.showConnected; foreground: root.foreground }

          Column {
            visible: root.showConnected
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "LOCATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ActionRow {
              width: parent.width
              navId: "location"
              glyph: "󰇧"
              title: mullvad.locationText
              detail: root.pickerOpen ? "Choose a country or city" : (mullvad.daemonSettings.ok && mullvad.daemonSettings.multihop ? "Exit location · multihop on" : "Change location")
              trailing: root.pickerOpen ? "󰅃" : "󰅀"
              current: root.pickerOpen
            }

            Column {
              visible: root.pickerOpen
              width: parent.width
              spacing: Style.space(4)

              TextField {
                id: searchField
                readonly property string navId: "search"
                width: parent.width
                foreground: root.foreground
                placeholderText: "Search countries and cities"
                hasCursor: root.isCursor("search")
                text: root.locationQuery
                onTextChanged: root.locationQuery = text
                onActiveFocusChanged: if (activeFocus) root.setCursor("search")
                onAccepted: root.activate("search")
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    root.leaveField(1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Up) {
                    root.leaveField(-1)
                    event.accepted = true
                  } else if (event.key === Qt.Key_Escape) {
                    root.pickerOpen = false
                    root.setCursor("location")
                    keyCatcher.forceActiveFocus()
                    event.accepted = true
                  }
                }
              }

              Text {
                visible: root.locationRows.length === 0
                width: parent.width
                topPadding: Style.space(6)
                text: mullvad.countries.length === 0 ? "Loading relay list…" : "No matching locations."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
              }

              Repeater {
                model: root.locationRows
                LocationRow {
                  required property var modelData
                  width: parent.width
                  row: modelData
                }
              }
            }
          }

          PanelSeparator { visible: root.showConnected; foreground: root.foreground }

          Column {
            visible: root.showConnected
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "SETTINGS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.settingRows
              SettingRow {
                required property var modelData
                width: parent.width
                navId: "set:" + modelData.kind
                title: modelData.title
                detail: modelData.detail
                checked: root.settingChecked(modelData.kind)
              }
            }

            ActionRow {
              width: parent.width
              navId: "dns"
              glyph: "󰒃"
              title: "DNS content blockers"
              detail: !mullvad.daemonSettings.ok ? "" : (mullvad.daemonSettings.customDns ? "Custom DNS is set; blockers are off" : (root.dnsBlockersOn === 0 ? "None" : root.dnsBlockersOn + " on"))
              trailing: root.dnsExpanded ? "󰅃" : "󰅀"
            }

            Repeater {
              model: root.dnsExpanded ? root.dnsBlockers : []
              SettingRow {
                required property var modelData
                width: parent.width
                navId: "dns:" + modelData.key
                title: modelData.label
                detail: ""
                nested: true
                enabled: mullvad.daemonSettings.ok && !mullvad.daemonSettings.customDns
                checked: mullvad.daemonSettings.ok && mullvad.daemonSettings.dnsBlockers[modelData.key] === true
              }
            }
          }

          PanelSeparator { visible: root.showConnected; foreground: root.foreground }

          Column {
            visible: root.showConnected
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "ACCOUNT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            ActionRow {
              width: parent.width
              navId: "acct:copy"
              glyph: "󰆏"
              title: Model.maskAccountNumber(mullvad.accountNumber)
              detail: [mullvad.expiryText, mullvad.deviceName].filter(function(v) { return v !== "" }).join(" · ")
            }

            ActionRow {
              width: parent.width
              navId: "acct:manage"
              glyph: "󰖟"
              title: "Manage account"
              detail: "Add time or manage devices on mullvad.net"
            }

            ActionRow {
              width: parent.width
              navId: "acct:logout"
              glyph: "󰍃"
              title: root.confirmId === "acct:logout" ? "Press again to log out" : "Log out"
              detail: root.settingChecked("lockdownMode") ? "Lockdown stays on and blocks traffic until you log in" : "Disconnects and removes this device from the account"
            }
          }
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string navId: ""
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property string trailing: ""

    hasCursor: root.isCursor(navId)
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: actionInner.implicitHeight + Style.spacing.lg

    RowLayout {
      id: actionInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: actionRow.glyph
        color: actionRow.hasCursor || actionRow.current ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.preferredWidth: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: actionRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: text !== ""
          text: actionRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        visible: actionRow.trailing !== ""
        text: actionRow.trailing
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.alignment: Qt.AlignVCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(actionRow.navId)
      onClicked: {
        keyCatcher.forceActiveFocus()
        root.activate(actionRow.navId)
      }
    }
  }

  component SettingRow: CursorSurface {
    id: settingRow
    property string navId: ""
    property string title: ""
    property string detail: ""
    property bool checked: false
    property bool nested: false

    hasCursor: root.isCursor(navId)
    foreground: root.foreground
    fill: root.hoverFill
    opacity: enabled ? 1.0 : 0.5
    implicitHeight: settingInner.implicitHeight + Style.spacing.md

    RowLayout {
      id: settingInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: settingRow.nested ? Style.space(38) : Style.space(10)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: settingRow.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          visible: text !== ""
          text: settingRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      ToggleSwitch {
        checked: settingRow.checked
        interactive: false
        cursorRing: false
        busy: mullvad.busy
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: settingRow.enabled
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(settingRow.navId)
      onClicked: {
        keyCatcher.forceActiveFocus()
        root.activate(settingRow.navId)
      }
    }
  }

  component LocationRow: CursorSurface {
    id: locationRow
    property var row: null
    readonly property string navId: row ? "loc:" + row.id : ""
    readonly property bool selected: Model.isSelectedLocation(row, mullvad.location)

    hasCursor: root.isCursor(navId)
    current: selected
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: locationInner.implicitHeight + Style.spacing.md

    RowLayout {
      id: locationInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: locationRow.row && locationRow.row.nested ? Style.space(30) : Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: locationRow.row && locationRow.row.kind === "city" ? "󰍎" : "󰇧"
        color: locationRow.selected ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.preferredWidth: Style.space(18)
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText
        Layout.fillWidth: true
        text: locationRow.row ? locationRow.row.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: locationRow.selected
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        text: locationRow.row ? locationRow.row.detail : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        visible: locationRow.row && locationRow.row.expandable
        text: locationRow.row && locationRow.row.expanded ? "󰅃" : "󰅀"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.alignment: Qt.AlignVCenter

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Style.space(4)
          cursorShape: Qt.PointingHandCursor
          onClicked: root.expandedCountry = locationRow.row.expanded ? "" : locationRow.row.country
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(locationRow.navId)
      onClicked: root.chooseLocation(locationRow.row)
    }
  }
}
