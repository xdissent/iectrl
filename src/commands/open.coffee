Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('open [names] [url]')
  .description('open a URL in IE')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .option('-w, --wait', 'wait for IE to exit before returning')
  .action (names, url, command) ->
    cli.fail Q.fcall ->
      throw new Error "must specify url" unless names?
      if !url? and names.match /^http/
        url = names
        names = null
      cli.find(names, '!missing').found()
        .maybeAutoStart(command.start, command.headless).where('running')
        .found().all (vm) -> vm.open url, command.wait