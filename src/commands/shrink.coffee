cli = require '../cli'

module.exports = (program) -> program
  .command('shrink [names]')
  .description('shrink disk usage for virtual machines if archive is present')
  .action (names, command) ->
    cli.fail cli.find(names, 'ovaed', 'archived').found().all (vm) -> vm.unova()