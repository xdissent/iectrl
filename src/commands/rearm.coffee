Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('rearm [names]')
  .description('rearm virtual machines')
  .option('-E, --no-expired', 'rearm the even if not expired')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing')
      .maybeWhere(!command.expired, '!expired').found()
      .then (vms) -> cli.dsl(vms)
        .where('!running')
        .then (stopped) -> cli.dsl(stopped).all((vm) -> vm.start true)
          .then -> cli.dsl(vms).all((vm) -> vm.rearm())
            .then -> cli.dsl(stopped).all (vm) -> vm.stop()