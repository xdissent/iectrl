cli = require '../cli'

module.exports = (program) -> program
  .command('close [names] [url]')
  .description('close all running IE processes in virtual machines')
  .action (names, url, command) ->
    cli.fail cli.find(names, 'running').found().all (vm) -> vm.close()