{$,View} = require 'atom'
parser = require './build-parser.coffee'
ml = require './message-list.coffee'

module.exports =
class BuildToolsCommandOutput extends View
  @content: ->
    @div class: 'build-tools-cpp', outlet: 'btdiv', =>
      @div class: 'commandheader', outlet: 'cheader', =>
          @div class: 'commandname'
          @div class: 'commandsettings'
          @div class: 'commandclose'
      @div class: 'commandoutput build-tools-cpp-hidden', outlet: 'cmd_output'

  visible:
    header: false
    settings: false
    output: false
  lockoutput: false

  initialize: ->
    $(document).on 'click','.commandclose', =>
      @hideBox()
    $(document).on 'click','.commandsettings', =>
      @showSettings()
    $(document).on 'click','.commandsettingsup', =>
      @hideSettings()
    $(document).on 'mousedown', '.commandheader', @startResize
    return

  serialize: ->

  destroy: ->
    @detach()

  attach: ->
    atom.workspaceView.appendToBottom(this)

  toggleSettings: ->
    if @visible.settings
      @hideSettings()
    else
      @showBox()
      @showSettings()

  showSettings: ->
    if not @visible.settings
      @cheader.after(ml.settings)
      $(document).find('.settings').addClass('settings-abs') if @visible.output
      $(document).find('.commandsettings').removeClass('commandsettings').addClass('commandsettingsup')
      @visible.settings = true

  hideSettings: ->
    if @visible.settings
      ml.settings.detach()
      $(document).find('.commandsettingsup').removeClass('commandsettingsup').addClass('commandsettings')
      @visible.settings = false

  toggleBox: ->
    if @visible.header
      @hideBox()
    else
      @showBox()

  hideBox: ->
    @detach() if @visible.header
    @visible.header = false

  showBox: ->
    @attach() if not @visible.header
    @visible.header = true

  cancel: ->
    if @visible.settings
      @hideSettings()
    else if @visible.output
      @hideOutput()
    else
      @hideBox()

  startResize: =>
    $(document).on 'mousemove', @resize
    $(document).on 'mouseup', @endResize

  endResize: =>
    $(document).off 'mousemove', @resize
    $(document).off 'mouseup', @endResize

  resize: ({pageY, which}) =>
    return @endResize() unless which is 1
    if @visible.settings then pageY = pageY + ml.settings.height()
    $(document).find('.commandoutput').height($(document.body).height() - pageY)

  hideOutput: ->
    $(document).find('.commandoutput').addClass('build-tools-cpp-hidden')
    @visible.output = false

  showOutput: ->
    $(document).find('.commandoutput').removeClass('build-tools-cpp-hidden')
    @visible.output = true

  clear: ->
    $(document).find('.commandoutput').text('')
    parser.clearVars()

  outputLineParsed: (line,script) =>
    line = line.toString()
    parser.toLine line, script, @printLine

  openFile: (element) ->
    lineno = parseInt($(this).attr('row'))
    linecol= parseInt($(this).attr('col'))
    if $(this).attr('name') isnt ''
      atom.workspaceView.open($(this).attr('name')).then (editor) ->
        if lineno isnt 0
          editor.setCursorBufferPosition([lineno-1,linecol-1])

  finishConsole: ->
    parser.poplines(@printLine)
    $(document).find('.filelink').on 'click', @openFile

  printLine: (message) =>
    @showOutput() if !@lockoutput
    @cmd_output.append(message)
    @cmd_output.scrollTop(@cmd_output[0].scrollHeight)

  setHeader: (name) ->
    $(document).find('.commandname').html("<b>#{name}</b>")

  lock: ->
    @lockoutput = true

  unlock: ->
    @lockoutput = false
