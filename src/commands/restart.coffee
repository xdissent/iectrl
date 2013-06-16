Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('restart [names]')
  .description('restart virtual machines (or start if not running)')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.maybeFilter(!command.start, 'running', vms, true)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.running() for vm in vms)
      .then (running) ->
        Q.all((
          if running[i]
            vm.restart()
          else
            if command.start then vm.start command.headless else Q.fcall ->
        ) for vm, i in vms)