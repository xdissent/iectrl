Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').found()
      .then (vms) ->
        # Pull out XP vms because they share an OVA and must be 
        # installed sequentially.
        xps = (vm for vm in vms when vm.os is 'WinXP')
        rest = (vm for vm in vms when vm.os isnt 'WinXP')
        promise = Q.fcall ->
        for xp in xps
          do (xp) -> promise = promise.then -> xp.reinstall()
        Q.all promise, cli.dsl(rest).all (vm) -> vm.reinstall()