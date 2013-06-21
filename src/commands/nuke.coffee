Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('nuke [names]')
  .description('remove all traces of virtual machines')
  .action (names, command) ->
    cli.fail cli.find(names).found().then (vms) ->
      cli.dsl(vms).where('running').all((vm) -> vm.stop false).then ->
        cli.dsl(vms).where('!missing').groupReused (xps, win7s, rest) ->
          u = (vm) -> vm.uninstall()
          Q.all([xps.seq(u), win7s.seq(u), rest.all(u)]).then ->
            cli.dsl(vms).groupReused (xps, win7s, rest) ->
              xps.then (xps) -> win7s.then (win7s) -> rest.then (rest) ->
                rest.push xps[0] if xps.length > 0
                rest.push win7s[0] if win7s.length > 0
                cli.dsl(rest).all (vm) ->
                  vm.unova()
                  vm.unarchive()