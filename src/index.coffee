fs = require 'fs'
parse = require './parser'

module.exports = {
  parse: (str) ->
    parse(str)

  parseFile: (file) ->
    str = fs.readSync(file, {encoding: 'utf-8'})
    @parse(str)
}