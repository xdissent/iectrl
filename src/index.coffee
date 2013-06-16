fs = require 'fs'
Q = require 'q'
program = require 'commander'
colors = require 'colors'
moment = require 'moment'
pkg = require '../package.json'
IEVM = require './ievm'

statusColors =
  MISSING: 'red'
  POWEROFF: 'yellow'
  RUNNING: 'green'
  PAUSED: 'yellow'
  SAVED: 'yellow'

expireMsg = (exp) ->
  return '' unless exp?
  days = moment(exp).diff new Date, 'days'
  msg = if days < 1 then 'expired' else 'expires'
  c = if days <= 1 then 'red' else if days <= 7 then 'yellow' else 'green'
  msg[c]

catchFail = (promise) ->
  promise.fail (err) ->
    console.error "#{'ERROR'.red}: #{err}"
    process.exit -1

findVms = (names) -> Q.fcall ->
  return IEVM.all() unless names? and names.length? and names.length > 0
  vms = []
  vms = vms.concat IEVM.find n.trim() for n in names.split ','
  vms

filter = (attr, vms, invert=false) ->
  Q.all(vm[attr]() for vm in vms).then (attrs) ->
    vm for vm, i in vms when if invert then attrs[i] else !attrs[i]

maybeFilter = (maybe, attr, vms, invert=false) ->
  if maybe then filter attr, vms, invert else Q.fcall -> vms

autoStart = (headless, vms) ->
  filter('running', vms).then (stopped) ->
    Q.all(vm.start headless for vm in stopped).then -> vms

maybeAutoStart = (maybe, headless, vms) ->
  if maybe then autoStart headless, vms else Q.fcall -> vms

ensureFound = (vms, err) ->
  if vms.length == 0 then throw err else Q.fcall -> vms

program.version(pkg.version)

# ## Status
program
  .command('status [names]')
  .description('report the status of one or more vms')
  .option('-m, --missing', 'show VMs that are not installed')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> maybeFilter(!command.missing, 'missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.statusName() for vm in vms)
      .then (status) -> Q.all(vm.expires() for vm in vms)
      .then (expires) -> Q.all(vm.rearmsLeft() for vm in vms)
      .then (rearmsLeft) -> Q.all(vm.ovaed() for vm in vms)
      .then (ovaed) -> Q.all(vm.archived() for vm in vms)
      .then (archived) ->
        for vm, i in vms
          s = "#{status[i]}     ".slice 0, 8
          s = s[statusColors[status[i]]]
          f = if expires[i]? then moment(expires[i]).fromNow() else ''
          e = "#{expireMsg expires[i]} #{f}"
          rc = switch rearmsLeft[i]
            when 0 then "#{rearmsLeft[i]}".red
            when 1 then "#{rearmsLeft[i]}".yellow
            else "#{rearmsLeft[i]}".green
          r = if status[i] is 'MISSING' then '' else "#{rc} rearms left"
          missing = 'missing'.red
          present = 'present'.green
          o = "ova #{if ovaed[i] then present else missing}"
          a = "archive #{if archived[i] then present else missing}"
          console.log "#{vm.name}\t\t#{s}\t\t#{o}\t\t#{a}\t\t#{e}\t\t#{r}"

# ## Start
program
  .command('start [names]')
  .description('start virtual machines')
  .option('-h, --headless', 'start in headless (non-gui) mode')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> filter('running', vms)
      .then (vms) -> Q.all(vm.start command.headless for vm in vms)

# ## Stop
program
  .command('stop [names]')
  .description('stop virtual machines')
  .option('-S, --no-save', 'power off the virtual machine')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> filter('running', vms, true)
      .then (vms) -> Q.all(vm.stop command.save for vm in vms)

# ## Restart
program
  .command('restart [names]')
  .description('restart virtual machines (or start if not running)')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> maybeFilter(!command.start, 'running', vms, true)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.running() for vm in vms)
      .then (running) ->
        Q.all((
          if running[i]
            vm.restart()
          else
            if command.start then vm.start command.headless else Q.fcall ->
        ) for vm, i in vms)

# ## Open
program
  .command('open [names] [url]')
  .description('open a URL in IE')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, url, command) ->
    catchFail Q.fcall ->
      throw "must specify url" unless names?
      if !url? and names.match /^http/
        url = names
        names = null
      findVms(names)
        .then (vms) -> filter('missing', vms)
        .then (vms) -> ensureFound(vms, 'no matching vms found')
        .then (vms) -> maybeAutoStart(command.start, command.headless, vms)
        .then (vms) -> filter('running', vms, true)
        .then (vms) -> ensureFound(vms, 'no matching vms found')
        .then (vms) -> Q.all(vm.open url for vm in vms)

# ## Rearm
program
  .command('rearm [names]')
  .description('rearm virtual machines')
  .option('-E, --no-expired', 'rearm the even if not expired')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> maybeFilter(command.expired, 'expired', true)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> filter('running', vms)
      .then (stopped) -> Q.all(vm.start true for vm in stopped)
      .then -> Q.all(vm.rearm() for vm in vms)
      .then -> Q.all(vm.stop() for vm in stopped)

# ## Install
program
  .command('install [names]')
  .description('install virtual machines with ievms')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms, true)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.install() for vm in vms)

# ## Uninstall
program
  .command('uninstall [names]')
  .description('uninstall virtual machines')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> filter('running', vms, true)
      .then (running) -> Q.all(vm.stop(false) for vm in running)
      .then -> Q.all(vm.uninstall() for vm in vms)

# ## Reinstall
program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.reinstall() for vm in vms)

# ## Clean
program
  .command('clean [names]')
  .description('restore virtual machines to the clean snapshot')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('missing', vms)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.clean() for vm in vms)

# ## Shrink
program
  .command('shrink [names]')
  .description('shrink disk usage for virtual machines if archive is present')
  .action (names, command) ->
    catchFail findVms(names)
      .then (vms) -> filter('ovaed', vms, true)
      .then (vms) -> filter('archived', vms, true)
      .then (vms) -> ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.unova() for vm in vms)

# ## Nuke
program
  .command('nuke [name|version]')
  .description('remove all traces of a given IE version or all vms')
  .action (name) ->
    catchFail oneOrAll(name, null, true, false, true).then (vms) ->
      for vm, i in vms
        vm.uninstall(true).then -> vm.unova(true).then -> vm.unarchive true

module.exports = program