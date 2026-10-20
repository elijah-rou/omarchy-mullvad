'use strict'

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const Model = require('../Model.js')

// Shapes follow the mullvad CLI: `relay list` text, `account get` text, and
// one `status --json` object per line.
const RELAYS = [
  'Albania (al)',
  '\tTirana (tia) @ 41.32795°N, 19.81902°W',
  '\t\tal-tia-wg-001 (31.171.153.66, 2a04:27c0:0:3::f001) - hosted by iRegister (rented)',
  '\t\tal-tia-wg-002 (31.171.153.67) - hosted by iRegister (rented)',
  '',
  'USA (us)',
  '\tNew York, NY (nyc) @ 40.73061°N, -73.93524°W',
  '\t\tus-nyc-wg-301 (1.2.3.4) - hosted by M247 (rented)',
  '\tLos Angeles, CA (lax) @ 34.05224°N, -118.24368°W',
  '\t\tus-lax-wg-101 (1.2.3.5) - hosted by xtom (Mullvad-owned)',
  '',
  ''
].join('\n')

function testRelayList() {
  const countries = Model.parseRelayList(RELAYS)
  assert.equal(countries.length, 2)
  assert.deepEqual(countries[0], { name: 'Albania', code: 'al', cities: [{ name: 'Tirana', code: 'tia', relays: 2 }] })
  assert.equal(countries[1].cities[0].name, 'New York, NY')
  assert.equal(countries[1].cities[1].code, 'lax')
  assert.deepEqual(Model.parseRelayList(''), [])
}

function testLocationRows() {
  const countries = Model.parseRelayList(RELAYS)
  let rows = Model.locationRows(countries, '', 'us')
  assert.deepEqual(rows.map(r => r.id), ['al', 'us', 'us-nyc', 'us-lax'])
  assert.equal(rows[0].expandable, false)
  assert.equal(rows[0].detail, 'Tirana')
  assert.equal(rows[1].expanded, true)
  assert.equal(rows[2].nested, true)

  rows = Model.locationRows(countries, 'angel', '')
  assert.deepEqual(rows.map(r => r.id), ['us-lax'])
  assert.equal(rows[0].detail, 'USA')

  // A matching country lists all of its cities while searching.
  rows = Model.locationRows(countries, 'us', '')
  assert.deepEqual(rows.map(r => r.id), ['us', 'us-nyc', 'us-lax'])
}

function testStatus() {
  const disconnected = Model.parseStatus('{"state":"disconnected","details":{"location":{"ipv4":"203.0.113.7","ipv6":null,"mullvad_exit_ip":false,"hostname":null,"city":"Cape Town","country":"South Africa"},"locked_down":false}}')
  assert.equal(disconnected.ok, true)
  assert.equal(disconnected.state, 'disconnected')
  assert.equal(disconnected.ipv6, '')
  assert.equal(disconnected.hostname, '')
  assert.equal(disconnected.blocking, false)

  const blocked = Model.parseStatus('{"state":"error","details":{"cause":{"reason":"auth_failed","details":"invalid_account"},"block_failure":null}}')
  assert.equal(blocked.errorCause, 'auth failed: invalid_account')
  assert.equal(blocked.blocking, true)
  assert.equal(blocked.blockFailure, '')

  // A firewall failure means traffic is not blocked, and that must show.
  const leaking = Model.parseStatus('{"state":"error","details":{"cause":{"reason":"is_offline"},"block_failure":{"reason":"generic"}}}')
  assert.equal(leaking.blocking, false)
  assert.equal(leaking.errorCause, 'is offline')
  assert.equal(leaking.blockFailure, 'generic')

  assert.equal(Model.parseStatus('{"state":"connected","details":{"location":{}}}').blocking, false)
  assert.equal(Model.parseStatus('garbage').ok, false)
  assert.equal(Model.parseStatus('').ok, false)
}

function testAccount() {
  assert.equal(Model.parseAccount('Not logged in on any account\n').loggedIn, false)
  const account = Model.parseAccount([
    'Mullvad account:    1234567890123456',
    'Expires at:         2026-11-20 12:00:00 +01:00',
    'Device name:        Happy Mole',
    ''
  ].join('\n'))
  assert.equal(account.loggedIn, true)
  assert.equal(account.accountNumber, '1234567890123456')
  assert.equal(account.deviceName, 'Happy Mole')

  const now = Date.parse('2026-10-20T12:00:00Z')
  assert.equal(Model.expiryLabel(account.expiry, now), '30 days left')
  assert.equal(Model.expiryLabel('2026-10-01 00:00:00.123 +00:00', now), 'Out of time')
  assert.equal(Model.expiryLabel('', now), '')
}

function testAccountNumbers() {
  assert.equal(Model.maskAccountNumber('1234567890123456'), '•••• •••• •••• 3456')
  assert.equal(Model.formatAccountNumber('1234567890123456'), '1234 5678 9012 3456')
  assert.equal(Model.isAccountNumber('1234 5678 9012 3456'), true)
  assert.equal(Model.isAccountNumber('12345'), false)
  assert.equal(Model.isAccountNumber('123456789012345a'), false)
}

function testSettings() {
  const raw = fs.readFileSync(path.join(__dirname, 'fixtures', 'settings.json'), 'utf8')
  const settings = Model.parseSettings(raw)
  assert.equal(settings.ok, true)
  assert.deepEqual(settings.location, { country: 'se', city: 'got', hostname: '' })
  assert.equal(settings.quantumResistant, true)
  assert.equal(settings.lockdownMode, false)
  assert.equal(settings.allowLan, true)
  assert.equal(settings.daita, false)
  assert.equal(settings.customDns, false)
  assert.equal(settings.dnsBlockers.block_ads, true)
  assert.equal(settings.dnsBlockers.block_malware, false)
  assert.equal(Model.parseSettings('not json').ok, false)

  const countries = Model.parseRelayList(RELAYS)
  assert.equal(Model.locationLabel(settings.location, []), 'GOT, SE')
  assert.equal(Model.locationLabel({ country: 'us', city: 'lax', hostname: '' }, countries), 'Los Angeles, CA, USA')
  assert.equal(Model.locationLabel(null, countries), 'Any location')
  assert.equal(Model.isSelectedLocation({ kind: 'city', country: 'us', city: 'lax' }, { country: 'us', city: 'lax', hostname: '' }), true)
  assert.equal(Model.isSelectedLocation({ kind: 'country', country: 'us', city: '' }, { country: 'us', city: 'lax', hostname: '' }), false)
}

function testDnsCommand() {
  assert.deepEqual(Model.dnsCommand({ block_ads: true, block_malware: false }, 'block_malware'),
    ['mullvad', 'dns', 'set', 'default', '--block-ads', '--block-malware'])
  assert.deepEqual(Model.dnsCommand({ block_ads: true }, 'block_ads'), ['mullvad', 'dns', 'set', 'default'])
}

testRelayList()
testLocationRows()
testStatus()
testAccount()
testAccountNumbers()
testSettings()
testDnsCommand()
console.log('model tests passed')
