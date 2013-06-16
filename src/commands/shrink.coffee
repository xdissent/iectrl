cli = require '../cli'

module.exports = (program) -> program
  .command('shrink [names]')
  .description('shrink disk usage for virtual machines')
  .option('-f, --force', 'force if archive not present (must be redownloaded)')
  .action (names, command) ->
    cli.fail cli.find(names, 'ovaed').maybeWhere(!command.force, 'archived')
      .found()
      .then (vms) ->
        # Pull out XP vms because they share an OVA and only one should try
        # to delete it.
        xps = (vm for vm in vms when vm.os is 'WinXP')
        rest = (vm for vm in vms when vm.os isnt 'WinXP')
        rest.push xps[0] if xps.length > 0
        cli.dsl(rest).all (vm) -> vm.unova()