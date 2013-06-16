Q = require 'q'
colors = require 'colors'
IEVM = require './ievm'

find = (names) ->
  return IEVM.all() unless names? and names.length? and names.length > 0
  vms = []
  vms = vms.concat IEVM.find n.trim() for n in names.split ','
  vms

where = (vms, attr, invert=false) ->
  if attr[0] is '!'
    attr = attr.slice 1
    invert = !invert
  Q.all(vm[attr]() for vm in vms).then (attrs) ->
    vm for vm, i in vms when if invert then !attrs[i] else attrs[i]

dsl =
  where: (attrs...) ->
    promise = @
    for attr in attrs
      do (attr) -> promise = promise.then (vms) -> where vms, attr
    addDsl promise

  maybeWhere: (maybe, attrs...) -> if maybe then @where attrs... else @

  found: (err) -> addDsl @then (vms) ->
    err ?= 'no matching virtual machines found'
    if vms.length == 0 then throw err else Q.fcall -> vms

  all: (fn, ret=false) ->
    addDsl @then (vms) -> Q.all(Q.fcall fn, vm for vm in vms).then (vals) ->
      if ret then vals else vms

  autoStart: (headless) ->
    addDsl @then (vms) => @where('!running')
      .all((vm) -> vm.start headless).then -> vms

  maybeAutoStart: (maybe, headless) -> if maybe then @autoStart headless else @

addDsl = (promise) ->
  promise[n] = m.bind promise for n, m of dsl
  promise

exports.dsl = (vms) -> addDsl Q.fcall -> vms
exports.find = (names, attrs...) ->
  dsl.where.apply Q.fcall(-> find names), attrs
exports.fail = (promise) ->
  promise.fail (err) ->
    console.error "#{'ERROR'.red}: #{err}"
    process.exit -1