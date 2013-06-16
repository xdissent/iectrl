Q = require 'q'
colors = require 'colors'
IEVM = require './ievm'

exports.catchFail = (promise) ->
  promise.fail (err) ->
    console.error "#{'ERROR'.red}: #{err}"
    process.exit -1

exports.findVms = (names) -> Q.fcall ->
  return IEVM.all() unless names? and names.length? and names.length > 0
  vms = []
  vms = vms.concat IEVM.find n.trim() for n in names.split ','
  vms

exports.filter = (attr, vms, invert=false) ->
  Q.all(vm[attr]() for vm in vms).then (attrs) ->
    vm for vm, i in vms when if invert then attrs[i] else !attrs[i]

exports.maybeFilter = (maybe, attr, vms, invert=false) ->
  if maybe then exports.filter attr, vms, invert else Q.fcall -> vms

exports.autoStart = (headless, vms) ->
  exports.filter('running', vms).then (stopped) ->
    Q.all(vm.start headless for vm in stopped).then -> vms

exports.maybeAutoStart = (maybe, headless, vms) ->
  if maybe then exports.autoStart headless, vms else Q.fcall -> vms

exports.ensureFound = (vms, err) ->
  if vms.length == 0 then throw err else Q.fcall -> vms