fs = require 'fs'
program = require 'commander'
pkg = require '../package.json'

subcommands = [
  'clean'
  'install'
  'nuke'
  'open'
  'rearm'
  'reinstall'
  'restart'
  'shrink'
  'start'
  'status'
  'stop'
  'uninstall'
]

program.version(pkg.version)
require("./commands/#{s}") program for s in subcommands
program._parse = program.parse
program.parse = ->
  program._parse arguments...
  program.help() if program.rawArgs.length < 3
module.exports = program