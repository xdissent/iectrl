Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('stop [names]')
  .description('stop virtual machines')
  .option('-S, --no-save', 'power off the virtual machine')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> cli.filter('running', vms, true)
      .then (vms) -> Q.all(vm.stop command.save for vm in vms)