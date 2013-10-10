fs = require 'fs'
Parser = require './parser'

module.exports = {
  parse: (str) ->
    p = new Parser
    p.parse(str)

  parseFile: (file) ->
    str = fs.readSync(file, {encoding: 'utf-8'})
    @parse(str)
}