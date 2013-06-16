cli = require '../cli'

module.exports = (program) -> program
  .command('clean [names]')
  .description('restore virtual machines to the clean snapshot')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').found().all (vm) -> vm.clean()