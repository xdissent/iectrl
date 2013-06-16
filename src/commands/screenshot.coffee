path = require 'path'
Q = require 'q'
cli = require '../cli'

module.exports = (program) -> program
  .command('screenshot [names] [output]')
  .description('save screenshots for virtual machines')
  .action (names, output, command) ->
    cli.fail Q.fcall ->
      if names? and !output? and names.match /^[\.\~\/]/
        output = names
        names = null
      output ?= process.cwd()
      cli.find(names, 'running').found().then (vms) ->
        screenshots = []
        for vm in vms
          do (vm) ->
            file = path.join output, "#{vm.name}.png"
            screenshots.push Q.fcall -> vm.screenshot file
        Q.all screenshots