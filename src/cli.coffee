# # cli

# Hi there. This gets pretty gross in here but it's just a simple promise-based
# query api for groups of IEVM instances. I called it a `dsl` for some
# reason. The module's also called `cli` so nothing really makes sense. Just
# give me a pass on this one for the time being.

Q = require 'q'
colors = require 'colors'
IEVM = require './ievm'

exports.columns = (cols...) ->
  ("#{c}                                ".slice 0, 32 for c in cols).join ''

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

  seq: (fn) -> @then (vms) ->
    seq = Q()
    for vm in vms
      do (vm) -> seq = seq.then -> Q.fcall fn, vm
    seq

  autoStart: (headless) -> addDsl @then (vms) =>
    @where('!running').all((vm) -> vm.start headless).then -> vms

  maybeAutoStart: (maybe, headless) -> if maybe then @autoStart headless else @

  groupReused: (fn) ->
    group = (vms) ->
      win7Names = ['IE9 - Win7', 'IE10 - Win7', 'IE11 - Win7']
      xps = (vm for vm in vms when vm.os is 'WinXP')
      win7s = (vm for vm in vms when vm.name in win7Names)
      rest = (vm for vm in vms when vm.os isnt 'WinXP' and
        vm.name not in win7Names)
      [xps, win7s, rest]
    @then(group).spread (xps, win7s, rest) ->
      fn addDsl(Q(xps)), addDsl(Q(win7s)), addDsl(Q(rest))

addDsl = (promise) ->
  promise[n] = m.bind promise for n, m of dsl
  promise

exports.dsl = (vms) -> addDsl Q(vms)
exports.find = (names, attrs...) ->
  dsl.where.apply Q.fcall(-> find names), attrs
exports.fail = (promise) ->
  promise.fail (err) ->
    console.error "#{'ERROR'.red}: #{err}"
    process.exit -1