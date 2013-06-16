cli = require '../cli'

module.exports = (program) -> program
  .command('install [names]')
  .description('install virtual machines with ievms')
  .action (names, command) ->
    cli.fail cli.find(names, 'missing').found().all (vm) -> vm.install()