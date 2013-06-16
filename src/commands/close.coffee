cli = require '../cli'

module.exports = (program) -> program
  .command('close [names]')
  .description('close all running IE processes in virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names, 'running').found().all (vm) -> vm.close()