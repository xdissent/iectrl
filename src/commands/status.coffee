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
]

formatStatusName = (status) ->
  color = switch status
    when 'MISSING' then 'red'
    when 'RUNNNG' then 'green'
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
  "#{rearmsLeft[color]} rearms left"

formatFile = (name, present) ->
  msg = if present then 'present'.green else 'missing'.red
  "#{name} #{msg}"

formatOvaed = (ovaed) -> formatFile 'ova', ovaed
formatArchived = (archived) -> formatFile 'archive', archived

columns = (cols...) ->
  ("#{c}                                ".slice 0, 32 for c in cols).join ''

formatStatus = (vm) -> Q.all(vm[attr]() for attr in statusAttrs)
  .spread (statusName, ovaed, archived, expires, rearmsLeft) ->
    status = formatStatusName statusName
    ovaed = formatOvaed ovaed
    archived = formatArchived archived
    expires = formatExpires expires
    rearms = formatRearms if statusName is 'MISSING' then null else rearmsLeft
    columns vm.name, status, ovaed, archived, expires, rearms

module.exports = (program) -> program
  .command('status [names]')
  .description('report the status of one or more vms')
  .option('-m, --missing', 'show VMs that are not installed')
  .action (names, command) ->
    cli.catchFail cli.findVms(names)
      .then (vms) -> cli.maybeFilter(!command.missing, 'missing', vms)
      .then (vms) -> cli.ensureFound(vms, 'no matching vms found')
      .then (vms) -> Q.all(formatStatus vm for vm in vms)
      .then (statuses) -> console.log status for status in statuses