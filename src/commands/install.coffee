Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('install [names]')
  .description('install virtual machines with ievms')
  .action (names, command) ->
    cli.fail cli.find(names, 'missing').found().then (vms) ->
      # Pull out XP vms because they share an OVA and must be
      # installed sequentially.
      xps = (vm for vm in vms when vm.os is 'WinXP')
      installXp = Q.fcall ->
      for xp in xps
        do (xp) -> installXp = installXp.then -> xp.install()

      rest = (vm for vm in vms when vm.os isnt 'WinXP')
      installRest = cli.dsl(rest).all (vm) -> vm.install()

      Q.all [installXp, installRest]