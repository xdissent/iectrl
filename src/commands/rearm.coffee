Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('rearm [names]')
  .description('rearm virtual machines')
  .option('-E, --no-expired', 'rearm the even if not expired')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.filter('missing', vms)
      .then (vms) -> cli.maybeFilter(command.expired, 'expired', true)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> cli.filter('running', vms)
      .then (stopped) -> Q.all(vm.start true for vm in stopped)
      .then -> Q.all(vm.rearm() for vm in vms)
      .then -> Q.all(vm.stop() for vm in stopped)