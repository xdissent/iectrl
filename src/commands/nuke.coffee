cli = require '../cli'

module.exports = (program) -> program
  .command('nuke [names]')
  .description('remove all traces of virtual machines')
  .action (names, command) -> console.log 'NUKE'.red