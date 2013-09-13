Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('exec [names] <cmd> [args...]')
  .description('execute a command')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .option('-w, --wait', 'wait for the command to exit before returning')
  .action (names, cmd, args, command) ->
    cli.fail Q.fcall ->
      if !cli.isNames names
        args.unshift cmd
        cmd = names
        names = null
      cli.find(names, '!missing').found()
        .maybeAutoStart(command.start, command.headless).where('running')
        .found().all (vm) ->
          if command.wait
            vm.exec cmd, args...
          else
            vm.exec 'cmd.exe', '/c', 'start', cmd, args...