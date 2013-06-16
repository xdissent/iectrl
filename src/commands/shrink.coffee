Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('shrink [names]')
  .description('shrink disk usage for virtual machines if archive is present')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('ovaed', vms, true)
      .then (vms) -> cli.filter('archived', vms, true)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.unova() for vm in vms)