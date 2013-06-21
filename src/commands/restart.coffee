Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('restart [names]')
  .description('restart virtual machines')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing')
      .maybeWhere(!command.start, 'running').found()
      .then (vms) ->
        Q.all [
          cli.dsl(vms).where('running').all (vm) -> vm.restart()
          cli.dsl(vms).where('!running').all (vm) -> vm.start command.headless
        ]