Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .option('-s, --stop', 'stop and reinstall if running')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').maybeWhere(!command.stop, '!running')
      .found().then (vms) ->
        xps = (vm for vm in vms when vm.os is 'WinXP')
        reinstallXp = Q.fcall ->
        for xp in xps
          do (xp) -> reinstallXp = reinstallXp.then -> xp.reinstall()

        rest = (vm for vm in vms when vm.os isnt 'WinXP')
        reinstallRest = cli.dsl(rest).all (vm) -> vm.reinstall()

        cli.dsl(vms).where('running').all((vm) -> vm.stop false)
          .then -> Q.all reinstallXp, reinstallRest