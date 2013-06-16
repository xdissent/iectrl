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
module.exports = program