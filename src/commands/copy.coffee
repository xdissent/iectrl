Q = require 'q'
cli = require '../cli'
path = require 'path'

module.exports = (program) -> program
  .command('copy [names] [src] [dest]')
  .description('copy a file from host to virtual machines')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, src, dest, command) ->
    cli.fail Q.fcall ->
      if !cli.isNames names
        dest = src
        src = names
        names = null
      dest ?= '/Documents and Settings/IEUser/Desktop/'
      cli.find(names, '!missing').found()
        .maybeAutoStart(command.start, command.headless).where('running')
        .found().all (vm) -> vm.copy path.resolve(src), dest