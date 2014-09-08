# # IEVM

# This class represents an ievms VM and its current state, as queried through
# Virtualbox and the [modern.ie](http://modern.ie) website.

fs = require 'fs'
path = require 'path'
Q = require 'q'
url = require 'url'
http = require 'http'
child_process = require 'child_process'
debug = require 'debug'

class IEVM

  # ## Class Properties

  # A list of all available IE versions.
  @versions: [6, 7, 8, 9, 10, 11]

  # A list of all available OS names.
  @oses: ['WinXP', 'Vista', 'Win7', 'Win8']

  # A list of all supported ievms version/OS combos.
  @names: [
    'IE6 - WinXP'
    'IE7 - WinXP'
    'IE8 - WinXP'
    'IE7 - Vista'
    'IE8 - Win7'
    'IE9 - Win7'
    'IE10 - Win7'
    'IE10 - Win8'
    'IE11 - Win7'
  ]

  # A list of possible VM statuses.
  @status:
    MISSING: -1
    POWEROFF: 0
    RUNNING: 1
    PAUSED: 2
    SAVED: 3

  # A list of initial rearms available per OS. Hilarious.
  @rearms:
    WinXP: 0
    Vista: 0
    Win7: 5
    Win8: 0

  # The ievms home (`INSTALL_PATH` in ievms parlance).
  @ievmsHome: process.env.INSTALL_PATH ? path.join process.env.HOME, '.ievms'

  # The ievms script URL.
  @ievmsUrl: 'https://raw.githubusercontent.com/xdissent/ievms/master/ievms.sh'

  # The command used to install virtual machines via ievms.
  @ievmsCmd: process.env.IEVMS_CMD ? "curl -s #{@ievmsUrl} | bash"

  # The host IP as seen by the VM.
  @hostIp = '10.0.2.2'

  # ## Class Methods

  # Run ievms shell script with a given environment. A debug function may be
  # passed (like `console.log`) which will be called for each line of ievms
  # output. Returns a promise which will resolve when ievms is finished.
  @ievms: (env, debug) ->
    deferred = Q.defer()
    cmd = ['bash', '-c', @ievmsCmd]
    debug "ievms: #{cmd.join ' '}" if debug?
    ievms = child_process.spawn cmd.shift(), cmd, env: env
    ievms.on 'error', (err) -> deferred.reject err
    ievms.on 'exit', -> deferred.resolve true
    if debug? then ievms.stdout.on 'readable', ->
      out = ievms.stdout.read()
      debug "ievms: #{l}" for l in out.toString().trim().split "\n" if out?
    deferred.promise

  # Build an array with one instance of each possible IEVM type.
  @all: -> new @ n for n in @names

  # Build an array of all IEVM instances that match the given name, which may be
  # a specific VM (`IE6 - WinXP`), an IE version number (`9` or `7`) or an OS
  # name (`WinXP` or `Vista`).
  @find: (name) ->
    throw new Error 'No name specified' unless name?
    if typeof name isnt 'string' and typeof name isnt 'number'
      throw new Error "Invalid name: '#{name}'"
    return [new IEVM name] if name.match /^IE/
    if name.match /^(Win|Vista)/
      return (new IEVM n for n in @names when n.match "- #{name}")
    if !name.match(/^\d+$/) or parseInt(name) not in @versions
      throw new Error "Invalid name: '#{name}'"
    new IEVM n for n in @names when n.match "IE#{name}"

  # Construct a `VBoxManage` command with arguments. Adds single quotes to all
  # arguments for shell "safety".
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

  # Determine the status name for a given status value.
  @statusName: (status) -> (k for k, v of @status when v is status)[0]

  # ## Instance Methods

  # ### Constructor

  # Create a new IEVM instance for a given ievms VM name. The name is validated
  # against all supported ievms names. The IE version and OS are extracted from
  # the name and validated as well.
  constructor: (@name) ->
    if @name not in @constructor.names
      throw new Error "Invalid name: '#{@name}'"
    pieces = @name.split ' '
    @version = parseInt pieces[0].replace 'IE', ''
    if @version not in @constructor.versions
      throw new Error "Invalid version: '#{@version}'"
    @os = pieces.pop()
    throw new Error "Invalid OS: '#{@os}'" unless @os in @constructor.oses

  # ### Validation Helpers

  # Throw an exception if the virtual machine is missing (not installed).
  ensureMissing: ->
    @missing().then (missing) -> missing or throw new Error 'not missing'

  # Throw an exception if the virtual machine is *not* missing (is installed).
  ensureNotMissing: ->
    @missing().then (missing) -> !missing or throw new Error 'missing'

  # Throw an exception if the virtual machine is running.
  ensureRunning: ->
    @running().then (running) -> running or throw new Error 'not running'

  # Throw an exception if the virtual machine is *not* running (saved/off).
  ensureNotRunning: ->
    @running().then (running) -> !running or throw new Error 'running'

  # Throw an exception if the virtual machine has zero rearms left.
  ensureRearmsLeft: -> @rearmsLeft().then (rearmsLeft) ->
    rearmsLeft > 0 or throw new Error 'no rearms left'

  # Throw an exception if the virtual machine's archive file is missing.
  ensureArchived: ->
    @archived().then (archived) ->
      archived or throw new Error 'archive not present'

  # Throw an exception if the virtual machine's ova file is missing.
  ensureOvaed: ->
    @ovaed().then (ovaed) -> ovaed or throw new Error 'ova not present'

  # ### Action Methods

  # Start the virtual machine. Throws an exception if it is already running or
  # cannot be started. If the `headless` argument is `false` (the default) then
  # the VM will be started in GUI mode.
  start: (headless=false) -> @ensureNotMissing().then =>
    @ensureNotRunning().then =>
      type = if headless then 'headless' else 'gui'
      @debug "start: #{type}"
      @vbm('startvm', '--type', type).then => @waitForRunning()

  # Stop the virtual machine. Throws an exception if it is not running. If the
  # `save` argument is true (the default) then the VM state is saved. Otherwise,
  # the VM is powered off immediately which may result in data loss.
  stop: (save=true) -> @ensureNotMissing().then => @ensureRunning().then =>
    type = if save then 'savestate' else 'poweroff'
    @debug "stop: #{type}"
    @vbm('controlvm', type).then => @waitForNotRunning()

  # Gracefully restart the virtual machine by calling `shutdown.exe`. Throws an
  # exception if it is not running.
  restart: -> @ensureNotMissing().then => @ensureRunning().then =>
    @debug 'restart'
    @exec('shutdown.exe', '/r', '/t', '00').then =>
      # TODO: Should return before GC comes back online but timing is hard.
      # TODO: Bullshit Vista pops up the activation thing.
      @waitForNoGuestControl().then => @waitForGuestControl()

  # Open a URL in IE within the virtual machine. Throws an exception if it is
  # not running.
  open: (url, wait=false) -> @ensureNotMissing().then =>
    @ensureRunning().then => @waitForNetwork().then =>
      @debug "open: #{url}"
      if wait
        return @exec 'C:\\Program Files\\Internet Explorer\\iexplore.exe', url
      @exec 'cmd.exe', '/c', 'start',
        'C:\\Program Files\\Internet Explorer\\iexplore.exe', url

  # Close running IE windows in the virtual machine, failing silently if IE is
  # not currently running.
  close: -> @ensureNotMissing().then => @ensureRunning().then =>
    @debug 'close'
    @exec('taskkill.exe', '/f', '/im', 'iexplore.exe').fail -> Q(true)

  # Rearm the virtual machine, extending the license for 90 days. Unfortunately,
  # rearming is only supported by the Win7 virtual machines at this time.
  rearm: (delay=30000) -> @ensureNotMissing().then => @ensureRunning().then =>
    @ensureRearmsLeft().then => @waitForNetwork().then =>
      @debug 'rearm'
      @rearmPrep('rearm').then => @ievmsTask().then => @meta().then (meta) =>
        meta.rearms = (meta.rearms ? []).concat (new Date).getTime()
        @meta(meta).then => Q.delay(delay).then => @restart().then =>
          @rearmPrep('ato').then => @ievmsTask().then =>
            Q.delay(delay).then => @restart()

  # Uninstall the virtual machine. Removes the virtual machine and hdd from
  # VirtualBox, keeping the archive or ova on disk.
  uninstall: -> @ensureNotMissing().then => @ensureNotRunning().then =>
    @debug 'uninstall'
    @vbm 'unregistervm', '--delete'

  # Install the virtual machine through ievms. Throws an exception if it is
  # already installed.
  install: -> @ensureMissing().then =>
    @debug 'install'
    @constructor.ievms @ievmsEnv(), @debug.bind @

  # Reinstall the virtual machine through ievms. Throws an exception if it is
  # running or not installed.
  reinstall: -> @uninstall().then => @install()

  # Restore the virtual machine to the `clean` snapshot created by ievms. Throws
  # an exception if it is missing or currently running.
  clean: -> @ensureNotMissing().then => @ensureNotRunning().then =>
    @debug 'clean'
    @vbm('snapshot', 'restore', 'clean').then => @meta().then (meta) =>
      meta.rearms = []
      @meta meta

  # Delete the archive file for the virtual machine. If the ova is not present,
  # the archive must be redownloaded to reinstall the virtual machine. Throws
  # an exception if the archive is not present.
  unarchive: -> @ensureArchived().then =>
    @debug 'unarchive'
    Q.nfcall fs.unlink, @fullArchive()

  # Delete the ova file for the virtual machine. If the archive is not present,
  # it must be redownloaded to reinstall the virtual machine. Throws an
  # exception if the ova is not present.
  unova: -> @ensureOvaed().then =>
    @debug 'unova'
    Q.nfcall fs.unlink, @fullOva()

  # Execute a command in the virtual machine. Throws an exception if it is
  # not installed or not running, or if the command fails. Waits for guest
  # control before proceeding.
  exec: (cmd, args...) -> @ensureNotMissing().then => @ensureRunning().then =>
    @waitForGuestControl().then =>
      @ievmsVersion().then (version) =>
        @debug "exec: #{cmd} #{args.join ' '}"
        pass = ['--password', 'Passw0rd!']
        pass = [] if @os is 'WinXP' and !version?
        args = [
          'exec', '--image', cmd,
          '--wait-exit',
          '--username', 'IEUser', pass...,
          '--', args...
        ]
        @vbm 'guestcontrol', args...

  # Take a screenshot of the virtual machine and save it to disk. Throws an
  # exception if it is not installed or not running, or if the screenshot
  # command fails.
  screenshot: (file) -> @ensureNotMissing().then => @ensureRunning().then =>
    @debug 'screenshot'
    @vbm 'controlvm', 'screenshotpng', file

  # ### Attribute Methods

  # Determine the name of the zip file as used by modern.ie.
  archive: ->
    # For the reused XP vms, override the default to point to the IE6 archive.
    return 'IE6_WinXP.zip' if @name in ['IE7 - WinXP', 'IE8 - WinXP']
    return 'IE9_Win7.zip' if @name in ['IE10 - Win7', 'IE11 - Win7']
    # Simply replace dashes and spaces with an underscore and add `.zip`.
    "#{@name.replace ' - ', '_'}.zip"

  # Determine the full path to the archive file.
  fullArchive: -> path.join @constructor.ievmsHome, @archive()

  # Determine the name of the ova file as used by modern.ie.
  ova: ->
    return 'IE6 - WinXP.ova' if @name in ['IE7 - WinXP', 'IE8 - WinXP']
    return 'IE9 - Win7.ova' if @name in ['IE10 - Win7', 'IE11 - Win7']
    "#{@name}.ova"

  # Determine the full path to the ova file.
  fullOva: -> path.join @constructor.ievmsHome, @ova()

  # Generate the full URL to the modern.ie archive.
  url: -> 'http://virtualization.modern.ie/vhd/IEKitV1_Final/VirtualBox/OSX/' +
    @archive()

  # Retrieve and parse the virtual machine info from `VBoxManage showvminfo`.
  # If `E_ACCESSDENIED` is caught, the command will be retried up to 3 times
  # before rejecting the promise.
  info: (retries=3, delay=250) ->
    @vbm('showvminfo', '--machinereadable').then(@parseInfo).fail (err) =>
      return Q VMState: 'missing' if err.message.match /VBOX_E_OBJECT_NOT_FOUND/
      if retries > 0 and err.message.match /E_ACCESSDENIED/
        @debug "info: retrying (#{retries - 1} retries left)"
        return @info retries - 1, delay
      throw err

  # Promise a value from `IEVM.status` representing the vm's current status.
  status: -> @statusName().then (key) => @constructor.status[key]

  # Promise a key from `IEVM.status` representing the vm's current status.
  statusName: -> @info().then (info) -> info.VMState.toUpperCase()

  # Promise a `Date` object representing when the archive was last uploaded to
  # the modern.ie website. Caches the date as a property on the instance.
  uploaded: ->
    return Q @_uploaded if @_uploaded?
    deferred = Q.defer()
    opts = url.parse @url()
    opts.method = 'HEAD'
    req = http.request opts, (res) =>
      res.on 'data', (chunk) ->
      @_uploaded = new Date res.headers['last-modified']
      deferred.resolve @_uploaded
    req.on 'error', (err) -> deferred.reject err
    req.end()
    deferred.promise

  # Promise getter/setter for VM metadata.
  meta: (data) -> if data? then @setMeta data else @getMeta()

  # Promise a boolean indicating whether the VM is missing.
  missing: -> @status().then (status) => status is @constructor.status.MISSING

  # Promise a boolean indicating whether the VM is running.
  running: -> @status().then (status) => status is @constructor.status.RUNNING

  # Promise a boolean indicating whether the VM is expired.
  expired: -> @expires().then (expires) => !expires? or expires < new Date

  # Promise a boolean indicating whether the archive exists on disk.
  archived: ->
    deferred = Q.defer()
    fs.exists @fullArchive(), (archived) -> deferred.resolve archived
    deferred.promise

  # Promise a boolean indicating whether the archive exists on disk.
  ovaed: ->
    deferred = Q.defer()
    fs.exists @fullOva(), (ovaed) -> deferred.resolve ovaed
    deferred.promise

  # Promise a `Date` object representing when the VM will expire.
  expires: -> @missing().then (missing) =>
    return null if missing
    thirtyDays = 30 * 1000 * 60 * 60 * 24
    ninetyDays = thirtyDays * 3

    # XP virtual machines expire after 30 days from creation. Others get 90.
    if @os is 'WinXP' then return @hddCreated().then (created) ->
      new Date created.getTime() + thirtyDays

    # Try to fetch last rearm date from metadata.
    @rearmDates().then (rearms) =>
      if rearms.length > 0
        # Add ninety days to the most recent rearm date.
        new Date rearms[rearms.length - 1].getTime() + ninetyDays
      else
        # Fall back to the original date when the hdd was last modified.
        @hddCreated().then (created) -> new Date created.getTime() + ninetyDays

  # Promise an array of rearm dates or empty array if none exist.
  rearmDates: -> @meta().then (meta) =>
    return [] unless meta.rearms? and meta.rearms.length?
    new Date d for d in meta.rearms

  # Promise the number of rearms left for the VM.
  rearmsLeft: -> @rearmDates().then (rearms) =>
    @constructor.rearms[@os] - rearms.length

  # Promise the version of ievms which created this VM.
  ievmsVersion: -> @meta().then (meta) -> meta.version

  # ### Utilities

  # Output a debug message for the virtual machine.
  debug: (msg) ->
    @_debug ?= debug "iectrl:#{@name}"
    @_debug msg

  # Build an environment hash to pass to ievms for installation.
  ievmsEnv: ->
    IEVMS_VERSIONS: @version
    REUSE_XP: if @version in [7, 8] and @os is 'WinXP' then 'yes' else 'no'
    REUSE_WIN7: if @version in [10, 11] and @os is 'Win7' then 'yes' else 'no'
    INSTALL_PATH: @constructor.ievmsHome
    HOME: process.env.HOME
    PATH: process.env.PATH

  # Run a `VBoxManage` command and promise the stdout contents.
  vbm: (args...) ->
    @_vbmQueue = Q() if !@_vbmQueue? or @_vbmQueue.isRejected()
    @_vbmQueue = @_vbmQueue.then =>
      deferred = Q.defer()
      command = @constructor.vbm args.shift(), [@name].concat args
      child_process.exec command, (err, stdout, stderr) =>
        return deferred.reject err if err?
        deferred.resolve stdout
      deferred.promise

  # Parse the "machinereadable" `VBoxManage` vm info output format.
  parseInfo: (s) ->
    obj = {}
    for line in s.trim().split "\n"
      pieces = line.split '='
      obj[pieces.shift()] = pieces.join('=').replace(/^"/, '').replace /"$/, ''
    obj

  # Parse the ievms meta data stored in the VirtualBox `extradata`.
  parseMeta: (data) -> JSON.parse data.replace 'Value: ', ''

  # Promise to set the VM metadata.
  setMeta: (data) -> @vbm 'setextradata', 'ievms', JSON.stringify data

  # Promise to get the VM metadata. Returns empty object on failure.
  getMeta: -> @vbm('getextradata', 'ievms').then(@parseMeta).fail (err) -> Q {}

  # Seed the `ievms.bat` file in the virtual machine with a `slmgr` command.
  rearmPrep: (cmd) -> @exec 'cmd.exe', '/c',
    "echo slmgr.vbs /#{cmd} >C:\\Users\\IEUser\\ievms.bat"

  # Execute the `ievms` scheduled task in the virtual machine.
  ievmsTask: -> @exec 'schtasks.exe', '/run', '/tn', 'ievms'

  # Promise the UUID of the VM's hdd.
  hddUuid: -> @info().then (info) =>
    info['"SATA Controller-ImageUUID-0-0"'] ?
      info['"IDE Controller-ImageUUID-0-0"']

  # Promise an object representing the base hdd.
  hdd: -> @constructor.hdds().then (hdds) => @hddUuid().then (uid) =>
    return null unless uid? and hdds[uid]
    uid = hdds[uid]['Parent UUID'] while hdds[uid]['Parent UUID'] isnt 'base'
    hdds[uid]

  # Promise an `fs.stat` object for the VM's base hdd file.
  hddStat: -> @hdd().then (hdd) => Q.nfcall fs.stat, hdd.Location

  # Promise a `Date` object representing when the hdd file was created.
  hddCreated: -> @hddStat().then (stat) => stat.mtime

  # ### Waiting Room

  _waitForStatus: (statuses, deferred, delay=1000) ->
    statuses = [].concat statuses
    statusNames = (@constructor.statusName s for s in statuses).join ', '
    @debug "_waitForStatus: #{statusNames}"
    return null if deferred.promise.isRejected()
    @status().then (status) =>
      return deferred.resolve status if status in statuses
      Q.delay(delay).then => @_waitForStatus statuses, deferred, delay

  waitForRunning: (timeout=60000, delay) ->
    @debug 'waitForRunning'
    deferred = Q.defer()
    @_waitForStatus(@constructor.status.RUNNING, deferred, delay).fail (err) ->
      deferred.reject err
    deferred.promise.timeout timeout

  waitForNotRunning: (timeout=60000, delay) ->
    @debug 'waitForNotRunning'
    deferred = Q.defer()
    @_waitForStatus([
      @constructor.status.POWEROFF
      @constructor.status.PAUSED
      @constructor.status.SAVED
    ], deferred, delay).fail (err) -> deferred.reject err
    deferred.promise.timeout timeout

  _waitForGuestControl: (deferred, delay=1000) ->
    @debug '_waitForGuestControl'
    return null if deferred.promise.isRejected()
    @info().then (info) =>
      runlevel = info.GuestAdditionsRunLevel
      @debug "_waitForGuestControl: runlevel #{runlevel}"
      return deferred.resolve true if runlevel? and parseInt(runlevel) > 2
      Q.delay(delay).then => @_waitForGuestControl deferred, delay

  waitForGuestControl: (timeout=60000, delay) ->
    @waitForRunning().then =>
      deferred = Q.defer()
      @_waitForGuestControl(deferred, delay).fail (err) -> deferred.reject err
      deferred.promise.timeout timeout

  _waitForNoGuestControl: (deferred, delay=1000) ->
    @debug '_waitForNoGuestControl'
    return null if deferred.promise.isRejected()
    @info().then (info) =>
      runlevel = info.GuestAdditionsRunLevel
      @debug "waitForNoGuestControl: runlevel #{runlevel}"
      return deferred.resolve true if !runlevel? or parseInt(runlevel) < 2
      Q.delay(delay).then => @_waitForNoGuestControl deferred, delay

  waitForNoGuestControl: (timeout=60000, delay) ->
    deferred = Q.defer()
    @_waitForNoGuestControl(deferred, delay).fail (err) -> deferred.reject err
    deferred.promise.timeout timeout

  waitForNetwork: (host=@constructor.hostIp, retries=5, delay=3000) ->
    @debug 'waitForNetwork'
    @exec('ping.exe', host, '-n', '1').fail (err) =>
      throw err if retries <= 0
      Q.delay(delay).then =>
        @waitForNetwork host, retries - 1, delay if retries > 0

module.exports = IEVM