ConsoleView = require './console'

module.exports =
  class Display
    constructor: ->
      @console = new ConsoleView

    destroy: ->
      @console.destroy()
      @console = null

    spawn: (res, clear = true) ->
      @console.createOutput res
      @console.showBox()
      @console.setHeader("#{res.name} of #{res.project}")
      @console.clear() if clear
      @console.unlock()

    stdout: (data) =>
      @console.stdout.in data

    stderr: (data) =>
      @console.stderr.in data

    finish: (exitcode) ->
      @console.finishConsole exitcode

    setHeader: (name) ->
      @console.setHeader name

    hide: ->
      @console.hideOutput()

    lock: ->
      @console.lock()

    showConsole: ->
      @console.showBox()

    hideConsole: ->
      @console.hideBox()
