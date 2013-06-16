Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('nuke [names]')
  .description('remove all traces of virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names).found().then (vms) ->
      # Stop running and uninstall installed.
      uninstall = cli.dsl(vms).where('running').all((vm) -> vm.stop false)
        .then -> cli.dsl(vms).where('!missing').all (vm) -> vm.uninstall()

      # Pull out XP vms because they share an OVA and only one should try
      # to delete it.
      xps = (vm for vm in vms when vm.os is 'WinXP')
      rest = (vm for vm in vms when vm.os isnt 'WinXP')
      rest.push xps[0] if xps.length > 0

      # Uninstall and remove OVA and archive.
      uninstall.then -> cli.dsl(rest).all (vm) -> vm.unova(); vm.unarchive()