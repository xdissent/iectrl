fs = require 'fs'
program = require 'commander'
colors = require 'colors'
pkg = require '../package.json'

subcommands = [
  'clean'
  'close'
  'install'
  'nuke'
  'open'
  'rearm'
  'reinstall'
  'restart'
  'screenshot'
  'shrink'
  'start'
  'status'
  'stop'
  'uninstall'
  'uploaded'
]

program.Command.prototype._commandHelp = program.Command.prototype.commandHelp
program.Command.prototype.commandHelp = ->
  for cmd in this.commands
    cmd._name = cmd._name.green
    cmd._description = cmd._description.blue
  @_commandHelp()

program.version(pkg.version)
require("./commands/#{s}") program for s in subcommands

program._parse = program.parse
program.parse = ->
  program._parse arguments...
  program.help() if program.rawArgs.length < 3


module.exports = program

module.exports.IEVM = require './ievm'