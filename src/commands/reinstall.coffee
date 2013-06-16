Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.reinstall() for vm in vms)