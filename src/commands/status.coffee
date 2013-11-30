Q = require 'q'
colors = require 'colors'
moment = require 'moment'
cli = require '../cli'

statusAttrs = [
  'statusName'
  'ovaed'
  'archived'
  'expires'
  'rearmsLeft'
  'ievmsVersion'
]

formatStatusName = (status) ->
  color = switch status
    when 'MISSING' then 'red'
    when 'RUNNING' then 'green'
    else 'yellow'
  status[color]

formatExpires = (expires) ->
  return '' unless expires?
  days = moment(expires).diff new Date, 'days'
  msg = if days < 1 then 'expired' else 'expires'
  color = if days <= 1 then 'red' else if days <= 7 then 'yellow' else 'green'
  "#{msg[color]} #{moment(expires).fromNow()}".trim()

formatRearms = (rearmsLeft) ->
  return '' unless rearmsLeft?
  color = switch rearmsLeft
    when 0 then 'red'
    when 1 then 'yellow'
    else 'green'
  rearms = "#{rearmsLeft}"[color]
  "#{rearms} rearms left"

formatFile = (name, present) ->
  msg = if present then 'present'.green else 'missing'.red
  "#{name} #{msg}"

formatOvaed = (ovaed) -> formatFile 'ova', ovaed
formatArchived = (archived) -> formatFile 'archive', archived

formatStatus = (vm) -> Q.all(vm[attr]() for attr in statusAttrs)
  .spread (statusName, ovaed, archived, expires, rearmsLeft, version) ->
    status = formatStatusName statusName
    ovaed = formatOvaed ovaed
    archived = formatArchived archived
    expires = formatExpires expires
    rearms = if statusName is 'MISSING' then '' else formatRearms rearmsLeft
    version = "ievms v#{version ? 'unknown'.red}"
    cli.columns vm.name, status, ovaed, archived, expires, rearms, version

module.exports = (program) -> program
  .command('status [names]')
  .description('report the status of one or more vms')
  .option('-m, --missing', 'show VMs that are not installed')
  .action (names, command) ->
    cli.fail cli.find(names).maybeWhere(!command.missing, '!missing').found()
      .all(formatStatus, true).then (statuses) ->
        console.log status for status in statuses
