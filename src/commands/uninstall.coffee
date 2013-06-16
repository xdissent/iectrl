cli = require '../cli'

module.exports = (program) -> program
  .command('uninstall [names]')
  .description('uninstall virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').found()
      .then (vms) -> cli.dsl(vms)
        .where('running').all((vm) -> vm.stop false)
        .then -> cli.dsl(vms).all (vm) -> vm.uninstall()