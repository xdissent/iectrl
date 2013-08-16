Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('install [names]')
  .description('install virtual machines with ievms')
  .option('-X, --no-reuse-xp', 'Do not reuse the XP VM for IE7 and IE8')
  .option('-7, --no-reuse-7', 'Do not reuse the Win7 VM for IE10 and IE11')
  .option('-s, --shrink', 'Shrink the virtual machines after installing')
  .action (names, command) ->
    cli.fail cli.find(names).found().then (vms) ->
      names = names.split '' if names?
      names ?= []

      # Lookout below =/
      if command.reuseXp
        if 'IE7 - Vista' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE7 - Vista')
        if 'IE8 - Win7' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE8 - Win7')
      else
        if 'IE7 - WinXP' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE7 - WinXP')
        if 'IE8 - WinXP' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE8 - WinXP')
      if command.reuse7
        if 'IE10 - Win8' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE10 - Win8')
      else
        if 'IE10 - Win7' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE10 - Win7')
        if 'IE11 - Win7' not in names
          vms = (vm for vm in vms when vm.name isnt 'IE11 - Win7')

      cli.dsl(vms).found().groupReused (xps, win7s, rest) ->
        i = (vm) -> vm.install()
        Q.all([xps.seq(i), win7s.seq(i), rest.all(i)]).then ->
          return null unless command.shrink
          xps.then (xps) -> win7s.then (win7s) -> rest.then (rest) ->
            rest.push xps[0] if xps.length > 0
            rest.push win7s[0] if win7s.length > 0
            cli.dsl(rest).where('ovaed').all (vm) -> vm.unova()