cli = require '../cli'

module.exports = (program) -> program
  .command('shrink [names]')
  .description('shrink disk usage for virtual machines')
  .option('-f, --force', 'force if archive not present (must be redownloaded)')
  .action (names, command) ->
    cli.fail cli.find(names, 'ovaed').maybeWhere(!command.force, 'archived')
      .found().groupReused (xps, win7s, rest) ->
        xps.then (xps) -> win7s.then (win7s) -> rest.then (rest) ->
          rest.push xps[0] if xps.length > 0
          rest.push win7s[0] if win7s.length > 0
          cli.dsl(rest).all (vm) -> vm.unova()