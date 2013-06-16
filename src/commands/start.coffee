cli = require '../cli'

module.exports = (program) -> program
  .command('start [names]')
  .description('start virtual machines')
  .option('-h, --headless', 'start in headless (non-gui) mode')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing', '!running').found().all (vm) ->
      vm.start command.headless