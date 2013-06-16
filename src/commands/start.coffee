Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('start [names]')
  .description('start virtual machines')
  .option('-h, --headless', 'start in headless (non-gui) mode')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> cli.filter('running', vms)
      .then (vms) -> Q.all(vm.start command.headless for vm in vms)