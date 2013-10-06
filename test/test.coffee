chai = require 'chai'
chai.should()
parse = require('../src/index').parse

fs = require 'fs'
path = require 'path'
read = fs.readFileSync
readdir = fs.readdirSync;

#from https://github.com/visionmedia/css-parse/blob/master/test/css-parse.js
describe('parse(str)',() ->
  readdir('test/cases').forEach((file) -> 
    return if ~file.indexOf('json') or !~file.indexOf('smi')
    file = path.basename(file, '.smi');
    it('should parse ' + file, () ->
      css = read(path.join('test', 'cases', file + '.smi'), 'utf8');
      json = read(path.join('test', 'cases', file + '.json'), 'utf8');
      ret = parse(css, { position: true });
      ret = JSON.stringify(ret, null, 2);
      ret.should.equal(json);
    )
  )
)