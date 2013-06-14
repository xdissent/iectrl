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

statusesStopped = ['POWEROFF', 'PAUSED', 'SAVED']

expireMsg = (exp) ->
  return '' unless exp?
  days = moment(exp).diff new Date, 'days'
  msg = if days < 1 then 'expired' else 'expires'
  c = if days <= 1 then 'red' else if days <= 7 then 'yellow' else 'green'
  msg[c]

oneOrAll = (name, err=null, missing=false, running=true, stopped=true) ->
  Q.fcall(-> if name? then IEVM.find name else IEVM.all()).then (vms) ->
    Q.all(vm.statusKey() for vm in vms).then (status) ->
      vms = (vm for vm, i in vms when (status[i] isnt 'MISSING' or missing) and 
          (status[i] isnt 'RUNNING' or running) and 
          (status[i] not in statusesStopped or stopped))
      throw "#{name} #{err}" if err? and name? and vms.length == 0
      vms

catchFail = (promise) ->
  promise.fail (err) ->
    console.error "#{'ERROR'.red}: #{err}"
    process.exit -1

program
  .version(pkg.version)
  .option('-m, --missing', 'show VMs that are not installed')
  .option('-R, --no-reuse-xp', 'do not reuse the XP VM when applicable')
  .option('-H, --no-gui', 'launch vms in headless (non-gui) mode')
  .option('-S, --no-save', 'power off vm when stopping rather than saving vm state')

# ## Status
program
  .command('status [name|version]')
  .description('report the status of one or more vms')
  .action (name) ->
    catchFail oneOrAll(name, 'not found', program.missing).then (vms) ->
      Q.all(vm.statusKey() for vm in vms).then (status) ->
        Q.all(vm.expires() for vm in vms).then (expires) ->
          Q.all(vm.rearmsLeft() for vm in vms).then (rearmsLeft) ->
            for vm, i in vms
              s = status[i][statusColors[status[i]]]
              f = if expires[i]? then moment(expires[i]).fromNow() else ''
              e = "#{expireMsg expires[i]} #{f}"
              rc = switch rearmsLeft[i]
                when 0 then "#{rearmsLeft[i]}".red
                when 1 then "#{rearmsLeft[i]}".yellow
                when 2 then "#{rearmsLeft[i]}".green
              r = if status[i] is 'MISSING' then '' else "#{rc} rearms left"
              console.log vm.name, s, e, r

# ## Start
program
  .command('start [name|version]')
  .description('start one or all stopped vms')
  .action (name) ->
    catchFail oneOrAll(name, null, false, false).then (vms) ->
      Q.all(vm.start program.gui for vm in vms)

# ## Stop
program
  .command('stop [name|version]')
  .description('stop one or all running vms')
  .action (name) ->
    catchFail oneOrAll(name, 'not running', false, true, false).then (vms) ->
      Q.all(vm.stop program.save for vm in vms)

# ## Open
program
  .command('open [name|version] [url]')
  .description('open a URL in IE in one or all running vms')
  .action (name, url) ->
    catchFail Q.fcall ->
      throw "must specify url" unless name?
      if !url? and (!name.match(/^IE/) or !name.match /^\d/)
        url = name
        name = null
      console.log name, url
      oneOrAll(name, 'not running', false, true, false).then (vms) ->
        Q.all(vm.open url for vm in vms)

# ## Rearm
program
  .command('rearm [name|version]')
  .description('rearm one or all running vms')
  .action (name) ->
    catchFail oneOrAll(name, 'not rearmable', false, true, false).then (vms) ->
      Q.all(vm.rearm() for vm in vms)

# ## Reset
program
  .command('reset [name]')
  .description('restore one or more vms to the clean snapshot')
  .action (name) -> console.log 'RESET'

# ## Install
program
  .command('install [name|version]')
  .description('install a given IE version or all missing IE vms')
  .action (name) -> console.log 'INSTALL'

# ## Uninstall
program
  .command('destroy [name|version]')
  .description('install a given IE version or all missing IE vms')
  .action (name) -> console.log 'INSTALL'

module.exports = program