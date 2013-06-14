# # IEVM

# This class represents an ievms VM and its current state, as queried through
# Virtualbox and the [modern.ie](http://modern.ie) website.

fs = require 'fs'
Q = require 'q'
url = require 'url'
http = require 'http'
child_process = require 'child_process'

class IEVM
  # ## Class Properties

  # A list of all available IE versions for validation.
  @versions: [6, 7, 8, 9, 10]

  # A list of all available OS names for validation.
  @oses: ['WinXP', 'Vista', 'Win7', 'Win8']

  # A list of all possible ievms VM names.
  @names: [
    'IE6 - WinXP'
    'IE7 - WinXP'
    'IE8 - WinXP'
    'IE7 - Vista'
    'IE8 - Win7'
    'IE9 - Win7'
    'IE10 - Win8'
  ]

  # ## Class Methods

  # Build a list with an IEVM instance of each available type.
  @all: -> new @ n for n in @names

  @find: (name) ->
    throw "no name specified" unless name?
    throw "invalid name" unless typeof name is 'string' or typeof name is 'number'
    return [new IEVM name] if name.match /^IE/
    throw "invalid name" unless name.match(/^\d+$/) and parseInt(name) in @versions
    new IEVM n for n in @names when n.match "IE#{name}"

  @status:
    MISSING: -1
    POWEROFF: 0
    RUNNING: 1
    PAUSED: 2
    SAVED: 3

  @maxRearms:
    WinXP: 0
    Win7: 5
    Win8: 0

  @rearmDays:
    WinXP: 90
    Win7: 10
    Win8: 90

  @vbm: (cmd, args=[]) ->
    args = ("'#{a}'" for a in args).join ' '
    "VBoxManage #{cmd} #{args}"

  @parseHdds: (s) ->
    hdds = {}
    for chunk in s.split "\n\n"
      hdd = {}
      for line in chunk.split "\n"
        pieces = line.split ':'
        hdd[pieces.shift()] = pieces.join(':').trim()
      hdds[hdd.UUID] = hdd
    hdds

  @hdds: ->
    deferred = Q.defer()
    child_process.exec @vbm('list', ['hdds']), (err, stdout, stderr) =>
      return deferred.reject err if err?
      deferred.resolve @parseHdds stdout
    deferred.promise

  # ## Instance Methods

  # Create a new IEVM object for a given ievms VM name. The name is validated
  # against all possible names ievms generates. The IE version is extracted from
  # the name and validated as well.
  constructor: (@name) ->
    throw "Invalid name: '#{@name}'" unless @name in @constructor.names
    pieces = @name.split ' '
    @version = parseInt pieces[0].replace 'IE', ''
    throw "Invalid version: '#{@version}'" unless @version in @constructor.versions
    @os = pieces.pop()
    throw "Invalid OS: '#{@os}'" unless @os in @constructor.oses

  # Determine the name of the zip file as used by modern.ie.
  archive: ->
    # For the reused XP vms, override the default to point to the IE6 archive.
    return "IE6_WinXP.zip" if @name in ['IE7 - WinXP', 'IE8 - WinXP']
    # Simply replace dashes and spaces with an underscore and add `.zip`.
    "#{@name.replace ' - ', '_'}.zip"

  # Generate the full URL to the modern.ie archive.
  url: -> "http://virtualization.modern.ie/vhd/IEKitV1_Final/VirtualBox/OSX/#{@archive()}"

  # Build the command string for a given `VBoxManage` command and arguments.
  vbm: (cmd, args=[]) -> @constructor.vbm cmd, [@name].concat args

  # Parse the "machinereadable" `VBoxManage` output format.
  parse: (s) ->
    obj = {}
    for line in s.split "\n"
      pieces = line.split '='
      obj[pieces.shift()] = pieces.join('=').replace(/^"/, '').replace /"$/, ''
    obj

  # Promise the parsed vm info as returned by `VBoxManage showvminfo`.
  info: ->
    deferred = Q.defer()
    child_process.exec @vbm('showvminfo', ['--machinereadable']), (err, stdout, stderr) =>
      return deferred.resolve VMState: 'missing' if stderr.match /VBOX_E_OBJECT_NOT_FOUND/
      return deferred.reject err if err?
      deferred.resolve @parse stdout
    deferred.promise

  # Promise a value from `IEVM.status` representing the vm's current status.
  status: -> @statusKey().then (key) => @constructor.status[key]

  # Promise a key from `IEVM.status` representing the vm's current status.
  statusKey: ->@info().then (info) -> info.VMState.toUpperCase()

  # Promise a `Date` object representing when the archive was last uploaded to
  # the modern.ie website.
  uploaded: ->
    # Return the cached uploaded date if available.
    return (Q.fcall => @_uploaded) if @_uploaded?
    # Defer a 'HEAD' request to the archive URL to determine the `last-modified`
    # time and date.
    deferred = Q.defer()
    opts = url.parse @url()
    opts.method = 'HEAD'
    req = http.request opts, (res) =>
      res.on 'data', (chunk) -> # Node needs this or it delays for a second.
      # Cache the result as property.
      @_uploaded = new Date res.headers['last-modified']
      deferred.resolve @_uploaded
    req.on 'error', (err) -> deferred.reject err
    # Send the request and return a promise for the deferred result.
    req.end()
    deferred.promise

  setMeta: (data) ->
    deferred = Q.defer()
    data = JSON.stringify data
    child_process.exec @vbm('setextradata', ['ievms', data]), (err, stdout, stderr) =>
      return deferred.reject err if err?
      deferred.resolve true
    deferred.promise

  getMeta: ->
    deferred = Q.defer()
    child_process.exec @vbm('getextradata', ['ievms']), (err, stdout, stderr) =>
      return deferred.resolve {} if err?
      try
        data = JSON.parse stdout.replace 'Value: ', ''
      catch err
        return deferred.resolve {}
      deferred.resolve data
    deferred.promise

  meta: (data) -> if data? then @setMeta data else @getMeta()

  hddUuid: -> @info().then (info) =>
    info['"SATA Controller-ImageUUID-0-0"'] ? info['"IDE Controller-ImageUUID-0-0"']

  hdd: -> @constructor.hdds().then (hdds) => @hddUuid().then (hddUuid) =>
    return null unless hddUuid? and hdds[hddUuid]
    hddUuid = hdds[hddUuid]['Parent UUID'] while hdds[hddUuid]['Parent UUID'] isnt 'base'
    hdds[hddUuid]

  hddStat: -> @hdd().then (hdd) => Q.nfcall fs.stat, hdd.Location

  # Promise a `Date` object representing when the VM will expire.
  expires: ->
    thirtyDays = 30 * 1000 * 60 * 60 * 24
    ninetyDays = 3 * thirtyDays
    if @os is 'WinXP' then return @uploaded().then (uploaded) ->
      new Date uploaded.getTime() + ninetyDays
    @missing().then (missing) =>
      return null if missing
      @meta().then (meta) =>
        if meta.rearms? and meta.rearms.length > 0
          new Date meta.rearms[meta.rearms.length - 1] + thirtyDays
        else if meta.installed?
          new Date meta.installed + thirtyDays
        else
          @hddStat().then (stat) => new Date stat.mtime.getTime() + thirtyDays

  rearms: -> @meta().then (meta) => meta.rearms ? []

  rearmsLeft: ->
    return Q.fcall(-> 0) if @os is 'WinXP'
    @rearms().then (rearms) -> 2 - rearms.length

  canStart: -> @running().then (running) => @missing().then (missing) => @expired().then (expired) =>
    @expires().then (expires) => !running and !missing and !expired

  missing: -> @status().then (status) => status is @constructor.status.MISSING

  running: -> @status().then (status) => status is @constructor.status.RUNNING

  expired: -> @expires().then (expires) => !expires? or expires < new Date

  startError: ->
    @running().then (running) =>
      reason = if running
        Q.fcall -> "already running"
      else
        @missing().then (missing) =>
          return "missing" if missing
          @expired().then (expired) ->
            return "expired" if expired
            "unknown"
      reason.then (reason) -> throw "Cannot start #{@name}: #{reason}"

  start: (gui=true) ->
    @canStart().then (canStart) =>
      return @startError() unless canStart
      deferred = Q.defer()
      type = if gui then 'gui' else 'headless'
      child_process.exec @vbm('startvm', ['--type', type]), (err, stdout, stderr) =>
        return deferred.reject err if err?
        deferred.resolve true
      deferred.promise

  stop: (save=true) ->
    @running().then (running) =>
      throw "not running" unless running?
      deferred = Q.defer()
      cmd = if save then 'savestate' else 'poweroff'
      child_process.exec @vbm('controlvm', [cmd]), (err, stdout, stderr) =>
        return deferred.reject err if err?
        deferred.resolve true
      deferred.promise

  exec: (cmd, args...) ->
    deferred = Q.defer()
    pass = if @os isnt 'WinXP' then ['--password', 'Passw0rd!'] else []
    args = [
      'exec', '--image', cmd, 
      '--wait-exit',
      '--username', 'IEUser', pass...,
      '--', args...
    ]
    child_process.exec @vbm('guestcontrol', args), (err, stdout, stderr) =>
      return deferred.reject err if err?
      deferred.resolve true
    deferred.promise

  open: (url) ->
    @running().then (running) =>
      throw "not running" unless running?
      @exec 'cmd.exe', '/c', 'start', 'C:\\Program Files\\Internet Explorer\\iexplore.exe', url

  rearm: ->
    @running().then (running) =>
      throw "not running" unless running?
      @rearmsLeft().then (rearmsLeft) =>
        throw "no rearms left" unless rearmsLeft > 0
        @exec 'schtasks.exe', '/Run', '/TN', 'rearm'


module.exports = IEVM