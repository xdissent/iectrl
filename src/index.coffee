# # index

# This module exports the iectrl cli as a
# [commander.js](http://visionmedia.github.io/commander.js/) program as well as
# the `IEVM` class.

fs = require 'fs'
program = require 'commander'
colors = require 'colors'
pkg = require '../package.json'

# All available sub-commands in the cli.
subcommands = [
  'clean'
  'close'
  'install'
  'nuke'
  'list'
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

# Monkeypatch the `commandHelp` method for the sub-commands to add colors.
program.Command.prototype._commandHelp = program.Command.prototype.commandHelp
program.Command.prototype.commandHelp = ->
  for cmd in this.commands
    cmd._name = cmd._name.green
    cmd._description = cmd._description.blue
  @_commandHelp()

# Add the iectrl version and all sub-commands to the cli program.
program.version(pkg.version)
require("./commands/#{s}") program for s in subcommands

# Monkeypatch the `parse` method to show usage info when no sub-command
# is given.
program._parse = program.parse
program.parse = ->
  program._parse arguments...
  program.help() if program.rawArgs.length < 3


module.exports = program
module.exports.IEVM = require './ievm'
