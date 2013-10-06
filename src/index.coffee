fs = require 'fs'
Parser = require './parser'

exports.parse = (str) ->
  p = new Parser
  p.parse(str)

exports.parseFile = (file) ->
  str = file.readSync(file, {encoding: 'utf-8'})
  p = new Parser
  p.parse
