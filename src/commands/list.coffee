cli = require '../cli'
colors = require 'colors'

module.exports = (program) -> program
  .command('list')
  .description('list available virtual machines')
  .action (names, command) ->
    cli.find(null, '!missing').then (vms) ->
      heading = "Available virtual machines:\n".green
      message = vms.reduce (string, vm) ->
        string + "\n#{vm.name.blue}"
      , heading
      console.log(message)
