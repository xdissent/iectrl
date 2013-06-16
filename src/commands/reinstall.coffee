cli = require '../cli'

module.exports = (program) -> program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').found().all (vm) -> vm.reinstall()