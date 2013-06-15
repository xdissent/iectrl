# # IEVM

# This class represents an ievms VM and its current state, as queried through
# Virtualbox and the [modern.ie](http://modern.ie) website.

fs = require 'fs'
path = require 'path'
Q = require 'q'
url = require 'url'
http = require 'http'
child_process = require 'child_process'
debug = require('debug') 'ievms:IEVM'

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

  # A list of possible VM statuses.
  @status:
    MISSING: -1
    POWEROFF: 0
    RUNNING: 1
    PAUSED: 2
    SAVED: 3

  # A list of initial rearms available per OS.
  @rearms:
    WinXP: 0
    Vista: 0
    Win7: 5
    Win8: 0

  # ## Class Methods

  # Build a list with an IEVM instance of each available type.
  @all: -> new @ n for n in @names

  # Build a list of all IEVM instances that match the given name, which may be
  # a specific VM (`IE6 - WinXP`) or an IE version number (`9` or `7`).
  @find: (name) ->
    throw "no name specified" unless name?
    throw "invalid name" unless typeof name is 'string' or typeof name is 'number'
    return [new IEVM name] if name.match /^IE/
    throw "invalid name" unless name.match(/^\d+$/) and parseInt(name) in @versions
    new IEVM n for n in @names when n.match "IE#{name}"

  # Construct a `VBoxManage` command with arguments.
  @vbm: (cmd, args=[]) ->
    args = ("'#{a}'" for a in args).join ' '
    "VBoxManage #{cmd} #{args}"

  # Parse the output from `VBoxManage list hdds` into an object.
  @parseHdds: (s) ->
    hdds = {}
    for chunk in s.split "\n\n"
      hdd = {}
      for line in chunk.split "\n"
        pieces = line.split ':'
        hdd[pieces.shift()] = pieces.join(':').trim()
      hdds[hdd.UUID] = hdd
    hdds

  # Promise the parsed output from `VBoxManage list hdds`.
  @hdds: ->
    deferred = Q.defer()
    child_process.exec @vbm('list', ['hdds']), (err, stdout, stderr) =>
      return deferred.reject err if err?
      deferred.resolve @parseHdds stdout
    deferred.promise

  @home: -> Q.fcall -> '/Users/xdissent/.ievms'


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

  # Start the VM.
  start: (gui=true) ->
    @canStart().then (canStart) =>
      return @startError() unless canStart
      deferred = Q.defer()
      type = if gui then 'gui' else 'headless'
      child_process.exec @vbm('startvm', ['--type', type]), (err, stdout, stderr) =>
        return deferred.reject err if err?
        deferred.resolve true
      deferred.promise.then => @waitForRunning()

  # Stop the VM.
  stop: (save=true) ->
    @running().then (running) =>
      throw "not running" unless running
      deferred = Q.defer()
      cmd = if save then 'savestate' else 'poweroff'
      child_process.exec @vbm('controlvm', [cmd]), (err, stdout, stderr) =>
        return deferred.reject err if err?
        deferred.resolve true
      deferred.promise.then => @waitForNotRunning()

  # Execute a command in the VM.
  exec: (cmd, args...) ->
    @running().then (running) =>
      throw "not running" unless running
      @waitForGuestControl().then =>
        deferred = Q.defer()
        pass = if @os isnt 'WinXP' then ['--password', 'Passw0rd!'] else []
        args = [
          'exec', '--image', cmd, 
          '--wait-exit',
          '--username', 'IEUser', pass...,
          '--', args...
        ]
        gcCmd = @vbm 'guestcontrol', args
        @debug "exec: #{gcCmd}"
        child_process.exec gcCmd, (err, stdout, stderr) =>
          @debug "exec: #{cmd} (error: #{err?})"
          return deferred.reject err if err?
          deferred.resolve true
        deferred.promise

  # Open a URL in IE.
  open: (url) ->
    @running().then (running) =>
      throw "not running" unless running
      @exec 'cmd.exe', '/c', 'start', 'C:\\Program Files\\Internet Explorer\\iexplore.exe', url

  restart: ->
    @debug "restart"
    @running().then (running) =>
      throw "not running" unless running
      @exec('shutdown.exe', '/r', '/t', '00').then =>
        @waitForNoGuestControl().then => @waitForGuestControl()

  rearm: (delay=30000) ->
    @debug "rearm"
    @running().then (running) =>
      throw "not running" unless running
      @rearmsLeft().then (rearmsLeft) =>
        throw "no rearms left" unless rearmsLeft > 0
        @exec('schtasks.exe', '/run', '/tn', 'rearm').then =>
          @meta().then (meta) =>
            meta.rearms = (meta.rearms ? []).concat (new Date).getTime()
            @meta(meta).then => Q.delay(delay).then => @restart().then =>
              @exec('schtasks.exe', '/run', '/tn', 'activate').then =>
                Q.delay(delay).then => @restart()

  debug: (msg) -> debug "#{@name}: #{msg}"

  # Determine the name of the zip file as used by modern.ie.
  archive: ->
    # For the reused XP vms, override the default to point to the IE6 archive.
    return "IE6_WinXP.zip" if @name in ['IE7 - WinXP', 'IE8 - WinXP']
    # Simply replace dashes and spaces with an underscore and add `.zip`.
    "#{@name.replace ' - ', '_'}.zip"

  # Determine the name of the ova file as used by modern.ie.
  ova: ->
    return "IE6 - WinXP.ova" if @name in ['IE7 - WinXP', 'IE8 - WinXP']
    "#{@name}.ova"

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
    cmd = @vbm 'showvminfo', ['--machinereadable']
    debug "info: #{cmd}"
    child_process.exec cmd, (err, stdout, stderr) =>
      debug "info: done (error: #{err?})"
      return deferred.resolve VMState: 'missing' if stderr.match /VBOX_E_OBJECT_NOT_FOUND/
      return deferred.reject err if err?
      deferred.resolve @parse stdout
    deferred.promise

  # Promise a value from `IEVM.status` representing the vm's current status.
  status: -> @statusName().then (key) => @constructor.status[key]

  # Promise a key from `IEVM.status` representing the vm's current status.
  statusName: ->@info().then (info) -> info.VMState.toUpperCase()

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

  # Promise to set the VM metadata.
  setMeta: (data) ->
    deferred = Q.defer()
    data = JSON.stringify data
    child_process.exec @vbm('setextradata', ['ievms', data]), (err, stdout, stderr) =>
      return deferred.reject err if err?
      deferred.resolve true
    deferred.promise

  # Promise to get the VM metadata.
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

  # Promise getter/setter for VM metadata.
  meta: (data) -> if data? then @setMeta data else @getMeta()

  # Promise the UUID of the VM's hdd.
  hddUuid: -> @info().then (info) =>
    info['"SATA Controller-ImageUUID-0-0"'] ? info['"IDE Controller-ImageUUID-0-0"']

  # Promise an object representing the base hdd.
  hdd: -> @constructor.hdds().then (hdds) => @hddUuid().then (hddUuid) =>
    return null unless hddUuid? and hdds[hddUuid]
    hddUuid = hdds[hddUuid]['Parent UUID'] while hdds[hddUuid]['Parent UUID'] isnt 'base'
    hdds[hddUuid]

  # Promise an `fs.stat` object for the VM's base hdd file.
  hddStat: -> @hdd().then (hdd) => Q.nfcall fs.stat, hdd.Location

  # Promise a `Date` object representing when the VM will expire.
  expires: -> @missing().then (missing) =>
    return null if missing
    ninetyDays = 90 * 1000 * 60 * 60 * 24
    if @os is 'WinXP' then return @uploaded().then (uploaded) ->
      new Date uploaded.getTime() + ninetyDays
    @meta().then (meta) =>
      if meta.rearms? and meta.rearms.length > 0
        # Add ninety days to the most recent rearm date.
        new Date meta.rearms[meta.rearms.length - 1] + ninetyDays
      else if meta.installed?
        # Add ninety days to the install date from metadata.
        new Date meta.installed + ninetyDays
      else
        # Fall back to the original date when the hdd was last modified (created).
        @hddStat().then (stat) => new Date stat.mtime.getTime() + ninetyDays

  # Promise an array of rearm dates or empty array if none exist.
  rearms: -> @meta().then (meta) => meta.rearms ? []

  # Promise the number of rearms left for the VM.
  rearmsLeft: -> @rearms().then (rearms) => @constructor.rearms[@os] - rearms.length

  # Promise a boolean indicating whether the VM is missing.
  missing: -> @status().then (status) => status is @constructor.status.MISSING

  # Promise a boolean indicating whether the VM is running.
  running: -> @status().then (status) => status is @constructor.status.RUNNING

  # Promise a boolean indicating whether the VM is expired.
  expired: -> @expires().then (expires) => !expires? or expires < new Date

  # Promise a boolean indicating whether the archive exists on disk.
  archived: -> @constructor.home().then (home) =>
    deferred = Q.defer()
    fs.exists path.join(home, @archive()), (archived) -> deferred.resolve archived
    deferred.promise

  # Promise a boolean indicating whether the archive exists on disk.
  ovaed: -> @constructor.home().then (home) =>
    deferred = Q.defer()
    fs.exists path.join(home, @ova()), (ovaed) -> deferred.resolve ovaed
    deferred.promise

  # Promise a boolean indicating whether the VM can be started.
  canStart: -> @running().then (running) => @missing().then (missing) =>
    @expired().then (expired) => !running and !missing and !expired

  # Promise a message indicating why the VM cannot be started.
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

  _waitForStatus: (statuses, deferred, delay=1000) ->
    statuses = [].concat statuses
    @debug "waitForStatus: #{statuses}"
    return null if deferred.promise.isRejected()
    @status().then (status) =>
      @debug "waitForStatus: #{status} in #{statuses}"
      return deferred.resolve status if status in statuses
      Q.delay(delay).then => @_waitForStatus statuses, deferred, delay

  waitForRunning: (timeout=60000, delay) ->
    @debug "waitForRunning"
    deferred = Q.defer()
    @_waitForStatus @constructor.status.RUNNING, deferred, delay
    deferred.promise.timeout timeout

  waitForNotRunning: (timeout=60000, delay) ->
    @debug "waitForNotRunning"
    deferred = Q.defer()
    @_waitForStatus [
      @constructor.status.POWEROFF
      @constructor.status.PAUSED
      @constructor.status.SAVED
    ], deferred, delay
    deferred.promise.timeout timeout

  _waitForGuestControl: (deferred, delay=1000) ->
    @debug "waitForGuestControl"
    return null if deferred.promise.isRejected()
    @info().then (info) =>
      runlevel = info.GuestAdditionsRunLevel
      @debug "waitForGuestControl: runlevel #{runlevel}"
      return deferred.resolve true if runlevel? and parseInt(runlevel) > 2        
      Q.delay(delay).then => @_waitForGuestControl deferred, delay

  waitForGuestControl: (timeout=60000, delay) ->
    @waitForRunning().then =>
      deferred = Q.defer()
      @_waitForGuestControl deferred, delay
      deferred.promise.timeout timeout

  _waitForNoGuestControl: (deferred, delay=1000) ->
    @debug "waitForNoGuestControl"
    return null if deferred.promise.isRejected()
    @info().then (info) =>
      runlevel = info.GuestAdditionsRunLevel
      @debug "waitForNoGuestControl: runlevel #{runlevel}"
      return deferred.resolve true if !runlevel? or parseInt(runlevel) < 2
      Q.delay(delay).then => @_waitForNoGuestControl deferred, delay

  waitForNoGuestControl: (timeout=60000, delay) ->
    deferred = Q.defer()
    @_waitForNoGuestControl deferred, delay
    deferred.promise.timeout timeout

module.exports = IEVM