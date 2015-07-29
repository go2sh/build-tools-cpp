command = require './command'
ll = require './linter-list'
Profiles = require './profiles/profiles'

{CompositeDisposable, BufferedProcess} = require 'atom'

settingsviewuri = 'atom://build-tools-settings'
SettingsView = null
settingsview = null

Display = null
display = null

SelectionView = null
selectionview = null

createDisplay = ->
  Display ?= require './display'
  display = new Display

createSelectionView = ->
  SelectionView ?= require './selection-view.coffee'
  selectionview ?= new SelectionView

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  settingsview = new SettingsView(state)
  settingsview

module.exports =

  process: null
  subscriptions: null

  Projects: null
  projects: null

  command_list: null

  createProjectInstance: ->
    @Projects ?= require './projects'
    @projects ?= new @Projects()

  activate: (state) ->
    @createProjectInstance()
    createDisplay()
    atom.workspace.addOpener (uritoopen) =>
      if uritoopen is settingsviewuri
        createSettingsView({uri: uritoopen, @projects, profiles: Profiles})

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'build-tools:third-command': => @execute(2)
      'build-tools:second-command': => @execute(1)
      'build-tools:first-command': => @execute(0)
      'build-tools:show': @show
      'build-tools:settings': ->
        atom.workspace.open(settingsviewuri)
      'build-tools:commands': => @selection()
      'core:cancel': => @cancel()
      'core:close': => @cancel()
    @subscriptions.add atom.project.onDidChangePaths ->
      settingsview?.reload()

  deactivate: ->
    @process?.kill()
    @process = null
    @subscriptions.dispose()
    display.destroy()
    display = null
    Display = null
    selectionview?.destroy()
    selectionview = null
    SelectionView = null
    settingsview?.destroy()
    settingsview = null
    SettingsView = null
    @projects?.destroy()
    @Projects = null
    @projects = null

  show: ->
    display.showConsole()

  kill: ->
    @process?.kill()
    @process = null

  cancel: ->
    @kill()
    display.hideConsole()

  selection: ->
    if (path=atom.workspace.getActiveTextEditor()?.getPath())?
      if (projectpath=@projects.getNextProjectPath path) isnt ''
        project = @projects.getProject projectpath
        createSelectionView()
        selectionview.show project, (name) =>
          if (command = project.getCommand name)?
            @command_list = @projects.generateDependencyList command
            @spawn @command_list.splice(0,1)[0]

  saveall: ->
    for editor in atom.workspace.getTextEditors()
      editor.save() if editor.isModified() and editor.getPath()?

  lint: ->
    atom.commands.dispatch(atom.views.getView(atom.workspace), "linter:lint")

  spawn: (res, clear = true) ->
    {cmd,args,env,cwd} = res.parseCommand()
    display.spawn res, clear
    ll.messages = [] if clear
    @kill()
    @process = new BufferedProcess(
      command: cmd
      args: args
      options:
        cwd: cwd,
        env: env
      stdout: display.stdout
      stderr: display.stderr
      exit: (exitcode) =>
        if (@command_list.length is 0) or exitcode isnt 0
          display.finish(exitcode)
        if exitcode is 0
          display.setHeader(
            "#{res.name} of #{res.project}: finished with exitcode #{exitcode}"
          )
          if (@command_list.length isnt 0)
            @spawn @command_list.splice(0,1)[0], false
        else
          display.setHeader(
            "#{res.name} of #{res.project}:" +
            "<span class='error'>finished with exitcode #{exitcode}</span>"
          )
        @lint() if (@command_list.length is 0) or exitcode isnt 0
        @process = null
      )
    @process.onWillThrowError ({error, handle}) =>
      display.hide()
      display.setHeader("#{res.name} of #{res.project}: received #{error}")
      display.lock()
      @command_list = []
      @process = null
      handle()

  execute: (id) ->
    @saveall() if atom.config.get('build-tools.SaveAll')
    if (path=atom.workspace.getActiveTextEditor()?.getPath())?
      if (projectpath=@projects.getNextProjectPath path) isnt ''
        project = @projects.getProject projectpath
        bindings = ['make','configure','preconfigure']
        if (b = bindings[id])?
          if (key = project.key[b])?
            project = @projects.getProject key.project
            command = project.getCommand key.command
          else
            command = project.getCommandByIndex id
        else
          command = project.getCommandByIndex id
        if command?
          @command_list = @projects.generateDependencyList command
          ll.messages = []
          @spawn @command_list.splice(0,1)[0]

  provideLinter: ->
    grammarScopes: ['*']
    scope: 'project'
    lintOnFly: false
    lint: ->
      ll.messages

  config:
    SaveAll:
      title: 'Save all'
      description: 'Save all files before executing your build command'
      type: 'boolean'
      default: true
    ShellCommand:
      title: 'Shell Command'
      description: 'Shell command to execute when "Execute in Shell" is enabled'
      type: 'string'
      default: 'bash -c'
    CloseOnSuccess:
      title: 'Close console on success'
      description: '-1 to keep console pane, 0 to hide console on success, >0 to hide console after x seconds'
      type: 'integer'
      default: -1
