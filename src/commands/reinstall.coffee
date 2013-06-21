Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('reinstall [names]')
  .description('reinstall virtual machines')
  .option('-s, --shrink', 'Shrink the virtual machines after installing')
  .action (names, command) ->
    cli.fail cli.find(names, '!missing').found().then (vms) ->
      cli.dsl(vms).where('running').all((vm) -> vm.stop false).then ->
        cli.dsl(vms).groupReused (xps, win7s, rest) ->
          r = (vm) -> vm.reinstall()
          Q.all([xps.seq(r), win7s.seq(r), rest.all(r)]).then ->
            return null unless command.shrink
            xps.then (xps) -> win7s.then (win7s) -> rest.then (rest) ->
              rest.push xps[0] if xps.length > 0
              rest.push win7s[0] if win7s.length > 0
              cli.dsl(rest).where('ovaed').all (vm) -> vm.unova()