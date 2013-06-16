cli = require '../cli'

module.exports = (program) -> program
  .command('stop [names]')
  .description('stop virtual machines')
  .option('-S, --no-save', 'power off the virtual machine')
  .action (names, command) ->
    cli.fail cli.find(names, 'running').found().all (vm) -> vm.stop command.save