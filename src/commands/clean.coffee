Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('clean [names]')
  .description('restore virtual machines to the clean snapshot')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.clean() for vm in vms)