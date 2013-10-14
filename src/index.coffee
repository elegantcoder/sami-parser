fs = require 'fs'
parse = require './parser'

module.exports = {
  parse: (str, options = {}) ->
    parse(str, options)

  parseFile: (file, options) ->
    str = fs.readSync(file, {encoding: 'utf-8'})
    @parse(str, options)
}