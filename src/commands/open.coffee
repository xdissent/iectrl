Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('open [names] [url]')
  .description('open a URL in IE')
  .option('-s, --start', 'start virtual machine if not running')
  .option('-h, --headless', 'start in headless (non-gui) mode if not running')
  .action (names, url, command) ->
    cli.catchFail Q.fcall ->
      throw "must specify url" unless names?
      if !url? and names.match /^http/
        url = names
        names = null
      cli.findVms(names)
        .then (vms) -> cli.filter('missing', vms)
        .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
        .then (vms) -> cli.maybeAutoStart(command.start, command.headless, vms)
        .then (vms) -> cli.filter('running', vms, true)
        .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
        .then (vms) -> Q.all(vm.open url for vm in vms)