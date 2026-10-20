// Pure parsers for mullvad CLI output and the daemon's settings.json, kept
// free of QML so they can be exercised with node.

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, error: "Empty status" }
  var data
  try {
    data = JSON.parse(text)
  } catch (e) {
    return { ok: false, error: "Could not parse mullvad status" }
  }
  var details = data.details || {}
  var location = details.location || {}
  var state = String(data.state || "unknown")
  // An error state is { cause: { reason, details }, block_failure }; a null
  // block_failure means the firewall is blocking traffic as intended.
  var isError = state === "error"
  return {
    ok: true,
    state: state,
    lockedDown: details.locked_down === true,
    blocking: isError && (details.block_failure === null || details.block_failure === undefined),
    blockFailure: isError && details.block_failure ? describeCause(details.block_failure) : "",
    errorCause: isError ? describeCause(details.cause) : "",
    hostname: String(location.hostname || ""),
    city: String(location.city || ""),
    country: String(location.country || ""),
    ipv4: String(location.ipv4 || ""),
    ipv6: String(location.ipv6 || ""),
    mullvadExitIp: location.mullvad_exit_ip === true,
    entryHostname: String(location.entry_hostname || "")
  }
}

function describeCause(cause) {
  if (!cause || typeof cause !== "object") return String(cause || "").replace(/_/g, " ")
  if (cause.reason !== undefined) {
    var reason = String(cause.reason).replace(/_/g, " ")
    var extra = cause.details
    if (extra === null || extra === undefined) return reason
    return reason + ": " + (typeof extra === "object" ? describeCause(extra) : String(extra))
  }
  var keys = Object.keys(cause)
  if (keys.length === 0) return ""
  var key = keys[0]
  var value = cause[key]
  var label = key.replace(/_/g, " ")
  if (value === null || value === undefined || typeof value === "object") return label
  return label + ": " + String(value)
}

// `mullvad relay list` prints
//   Country (cc)
//   \tCity (ccc) @ lat°N, lon°W
//   \t\thostname (addresses) - hosted by provider (ownership)
// with a blank line after each country.
function parseRelayList(raw) {
  var countries = []
  var country = null
  var city = null
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.trim() === "") continue
    if (line.indexOf("\t\t") === 0) {
      if (city) city.relays += 1
      continue
    }
    if (line.indexOf("\t") === 0) {
      var cityMatch = line.trim().match(/^(.+?) \(([a-z0-9-]+)\)/)
      if (!country || !cityMatch) continue
      city = { name: cityMatch[1], code: cityMatch[2], relays: 0 }
      country.cities.push(city)
      continue
    }
    var countryMatch = line.trim().match(/^(.+?) \(([a-z]{2})\)$/)
    if (!countryMatch) continue
    country = { name: countryMatch[1], code: countryMatch[2], cities: [] }
    city = null
    countries.push(country)
  }
  return countries
}

// `mullvad account get` prints padded "Label:  value" lines, or a single
// "Not logged in on any account" line.
function parseAccount(raw) {
  var text = String(raw || "")
  var result = { loggedIn: false, accountNumber: "", expiry: "", deviceName: "" }
  if (/not logged in/i.test(text)) return result
  var lines = text.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^([^:]+):\s+(.*)$/)
    if (!match) continue
    var key = match[1].trim().toLowerCase()
    var value = match[2].trim()
    if (key === "mullvad account") result.accountNumber = value
    else if (key === "expires at") result.expiry = value
    else if (key === "device name") result.deviceName = value
  }
  result.loggedIn = result.accountNumber !== ""
  return result
}

// chrono prints "2026-11-20 12:00:00 +01:00" (sometimes with fractional
// seconds); Date only accepts the ISO shape.
function parseExpiry(value) {
  var match = String(value || "").match(/^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})(?:\.\d+)?\s*([+-]\d{2}:?\d{2}|Z|UTC)?/)
  if (!match) return null
  var zone = match[3] || "Z"
  if (zone === "UTC") zone = "Z"
  else if (zone !== "Z" && zone.indexOf(":") === -1) zone = zone.substring(0, 3) + ":" + zone.substring(3)
  var date = new Date(match[1] + "T" + match[2] + zone)
  return isNaN(date.getTime()) ? null : date
}

function expiryLabel(value, nowMs) {
  var date = parseExpiry(value)
  if (!date) return value ? "Expires " + value : ""
  var days = Math.floor((date.getTime() - nowMs) / 86400000)
  if (date.getTime() <= nowMs) return "Out of time"
  if (days < 1) return "Expires today"
  if (days === 1) return "1 day left"
  return days + " days left"
}

function formatAccountNumber(number) {
  var digits = String(number || "").replace(/\s+/g, "")
  return digits.replace(/(.{4})(?=.)/g, "$1 ")
}

function maskAccountNumber(number) {
  var digits = String(number || "").replace(/\s+/g, "")
  if (digits.length <= 4) return digits
  return "•••• •••• •••• " + digits.substring(digits.length - 4)
}

function normalizeAccountInput(text) {
  return String(text || "").replace(/\s+/g, "")
}

function isAccountNumber(text) {
  return /^\d{16}$/.test(normalizeAccountInput(text))
}

var DNS_BLOCKERS = [
  { key: "block_ads", flag: "--block-ads", label: "Ads" },
  { key: "block_trackers", flag: "--block-trackers", label: "Trackers" },
  { key: "block_malware", flag: "--block-malware", label: "Malware" },
  { key: "block_gambling", flag: "--block-gambling", label: "Gambling" },
  { key: "block_adult_content", flag: "--block-adult-content", label: "Adult content" },
  { key: "block_social_media", flag: "--block-social-media", label: "Social media" }
]

function constraintLocation(constraint) {
  if (!constraint || constraint === "any" || !constraint.only) return null
  var only = constraint.only
  if (only.location) {
    return {
      country: String(only.location.country || ""),
      city: String(only.location.city || ""),
      hostname: String(only.location.hostname || "")
    }
  }
  if (only.custom_list) return { customList: String(only.custom_list.list_id || only.custom_list || "") }
  return null
}

function parseSettings(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return { ok: false }
  }
  var normal = data.relay_settings && data.relay_settings.normal ? data.relay_settings.normal : {}
  var wg = normal.wireguard_constraints || {}
  var tunnel = data.tunnel_options || {}
  var wgOptions = tunnel.wireguard || {}
  var dns = tunnel.dns_options || {}
  var defaults = dns.default_options || {}
  var blockers = {}
  for (var i = 0; i < DNS_BLOCKERS.length; i++) blockers[DNS_BLOCKERS[i].key] = defaults[DNS_BLOCKERS[i].key] === true
  return {
    ok: true,
    location: constraintLocation(normal.location),
    autoConnect: data.auto_connect === true,
    lockdownMode: data.lockdown_mode === true,
    allowLan: data.allow_lan === true,
    multihop: wg.use_multihop === true,
    quantumResistant: wgOptions.quantum_resistant === "on",
    daita: !!(wgOptions.daita && wgOptions.daita.enabled === true),
    ipv6: !!(tunnel.generic && tunnel.generic.enable_ipv6 === true),
    customDns: dns.state === "custom",
    dnsBlockers: blockers
  }
}

function dnsCommand(blockers, toggledKey) {
  var command = ["mullvad", "dns", "set", "default"]
  for (var i = 0; i < DNS_BLOCKERS.length; i++) {
    var item = DNS_BLOCKERS[i]
    var on = blockers && blockers[item.key] === true
    if (item.key === toggledKey) on = !on
    if (on) command.push(item.flag)
  }
  return command
}

function findCountry(countries, code) {
  for (var i = 0; i < countries.length; i++) if (countries[i].code === code) return countries[i]
  return null
}

function findCity(country, code) {
  if (!country) return null
  for (var i = 0; i < country.cities.length; i++) if (country.cities[i].code === code) return country.cities[i]
  return null
}

function locationLabel(location, countries) {
  if (!location) return "Any location"
  if (location.customList !== undefined) return "Custom list"
  var country = findCountry(countries, location.country)
  var countryName = country ? country.name : location.country.toUpperCase()
  if (location.hostname) return location.hostname
  if (location.city) {
    var city = findCity(country, location.city)
    return (city ? city.name : location.city.toUpperCase()) + ", " + countryName
  }
  return countryName
}

// Rows for the location picker. With no query: every country, plus the
// cities of the expanded one. With a query: matching countries and cities,
// flat, so typing a city name finds it without expanding anything.
function locationRows(countries, query, expandedCountry) {
  var q = String(query || "").trim().toLowerCase()
  var rows = []
  for (var i = 0; i < countries.length; i++) {
    var country = countries[i]
    var countryMatches = q === "" || country.name.toLowerCase().indexOf(q) !== -1 || country.code === q
    if (countryMatches) {
      rows.push({
        kind: "country",
        id: country.code,
        country: country.code,
        city: "",
        title: country.name,
        detail: country.cities.length === 1 ? country.cities[0].name : country.cities.length + " cities",
        expandable: country.cities.length > 1,
        expanded: q === "" && expandedCountry === country.code
      })
    }
    var showCities = q === "" ? expandedCountry === country.code && country.cities.length > 1 : true
    if (!showCities) continue
    for (var j = 0; j < country.cities.length; j++) {
      var city = country.cities[j]
      if (q !== "" && !countryMatches && city.name.toLowerCase().indexOf(q) === -1 && city.code !== q) continue
      rows.push({
        kind: "city",
        id: country.code + "-" + city.code,
        country: country.code,
        city: city.code,
        title: city.name,
        detail: q === "" ? (city.relays === 1 ? "1 server" : city.relays + " servers") : country.name,
        expandable: false,
        expanded: false,
        nested: q === ""
      })
    }
  }
  return rows
}

function isSelectedLocation(row, location) {
  if (!row || !location || location.customList !== undefined || location.hostname) return false
  if (row.kind === "country") return location.country === row.country && !location.city
  return location.country === row.country && location.city === row.city
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    describeCause: describeCause,
    parseRelayList: parseRelayList,
    parseAccount: parseAccount,
    parseExpiry: parseExpiry,
    expiryLabel: expiryLabel,
    formatAccountNumber: formatAccountNumber,
    maskAccountNumber: maskAccountNumber,
    normalizeAccountInput: normalizeAccountInput,
    isAccountNumber: isAccountNumber,
    DNS_BLOCKERS: DNS_BLOCKERS,
    constraintLocation: constraintLocation,
    parseSettings: parseSettings,
    dnsCommand: dnsCommand,
    findCountry: findCountry,
    findCity: findCity,
    locationLabel: locationLabel,
    locationRows: locationRows,
    isSelectedLocation: isSelectedLocation
  }
}
