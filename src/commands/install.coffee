Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('install [names]')
  .description('install virtual machines with ievms')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms, true)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(vm.install() for vm in vms)