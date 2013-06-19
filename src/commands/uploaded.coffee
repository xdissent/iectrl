moment = require 'moment'
cli = require '../cli'

module.exports = (program) -> program
  .command('uploaded [names]')
  .description('report the last time the VM was uploaded to modern.ie')
  .action (names, command) ->
    cli.fail cli.find(names).found().then (vms) ->
      cli.dsl(vms).all(((vm) -> vm.uploaded()), true).then (uploaded) ->
        for vm, i in vms
          relDate = moment(uploaded[i]).fromNow()
          console.log cli.columns vm.name, relDate, uploaded[i]