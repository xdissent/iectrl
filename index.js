try {
  module.exports = require('./lib');
} catch(error) {
  require('coffee-script');
  module.exports = require('./src');
}