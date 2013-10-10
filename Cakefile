# from https://github.com/libgit2/node-gitteh/blob/master/Cakefile
{spawn} = require 'child_process' 

showinfo = (args) -> console.info("Spawn: ", args.join(" ")) 

module.exports = 
  passthru: (args...) -> 
    callback = -> 
    callback = args.pop() if "function" == typeof args[args.length-1] 
    showinfo(args) 
    proc = spawn '/usr/bin/env', args 
    proc.stdout.pipe process.stdout 
    proc.stderr.pipe process.stderr 
    proc.on 'exit', (code) -> 
      console.info("Exited with status: " + code) if code 
      callback(code) 

task 'build', 'Compile CoffeeScript to JavaScript.', -> 
  module.exports.passthru 'coffee', '-o', 'lib/', '-c', 'src/' , (codes) ->
    module.exports.passthru 'cp', 'src/lang_codes.js', 'lib/'

task 'test', 'Run the unit tests.', -> 
  module.exports.passthru './node_modules/.bin/mocha', '--compilers', 'coffee:coffee-script', './test/test.coffee'

task "watch", "Watch coffee/ for changes and compile them to lib/", ->
  module.exports.passthru "coffee", "-o", "lib/", "-w", "-c", "src/"