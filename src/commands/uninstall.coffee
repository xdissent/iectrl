Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('uninstall [names]')
  .description('uninstall virtual machines')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> cli.filter('running', vms, true)
      .then (running) -> Q.all(vm.stop(false) for vm in running)
      .then -> Q.all(vm.uninstall() for vm in vms)