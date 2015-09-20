Command = require './command'
ll = require './linter-list'
Profiles = require './profiles/profiles'

{CompositeDisposable, BufferedProcess} = require 'atom'

settingsviewuri = 'atom://build-tools-settings'
SettingsView = null
settingsview = null

LocalSettingsView = null
localsettingsview = null

ConsoleView = null
consoleview = null

SelectionView = null
selectionview = null

AskView = null
askview = null

Projects = null

createAskView = ->
  AskView ?= require './ask-view'
  askview ?= new AskView

createConsoleView = ->
  ConsoleView ?= require './console'
  consoleview ?= new ConsoleView()

createSelectionView = ->
  SelectionView ?= require './selection-view.coffee'
  selectionview ?= new SelectionView

createSettingsView = (state) ->
  SettingsView ?= require './settings-view'
  settingsview = new SettingsView(state)
  settingsview

createLocalSettingsView = (state) ->
  LocalSettingsView ?= require './local-settings-view'
  localsettingsview = new LocalSettingsView(state)
  localsettingsview

module.exports =

  process: null
  subscriptions: null

  Projects: null
  projects: null

  command_list: null

  createProjectInstance: ->
    Projects ?= require './projects'
    @projects ?= new Projects()

  activate: (state) ->
    @createProjectInstance()
    if atom.config.get('build-tools.CloseOnSuccess') is -1
      atom.config.set('build-tools.CloseOnSuccess', 3)

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'build-tools:third-command': => @execute(2)
      'build-tools:second-command': => @execute(1)
      'build-tools:first-command': => @execute(0)
      'build-tools:third-command-ask': => @execute(2, true)
      'build-tools:second-command-ask': => @execute(1, true)
      'build-tools:first-command-ask': => @execute(0, true)
      'build-tools:show': @show
      'build-tools:settings': ->
        atom.workspace.open(settingsviewuri)
      'build-tools:commands': => @selection()
      'core:cancel': => @cancel()
      'core:close': => @cancel()
    @subscriptions.add atom.project.onDidChangePaths ->
      settingsview?.reload()
    @subscriptions.add atom.workspace.addOpener (uritoopen) =>
      if uritoopen is settingsviewuri
        createSettingsView({uri: uritoopen, @projects})
      else if uritoopen.endsWith('.build-tools.cson') and (project = Projects.loadLocalFile uritoopen)?
        createLocalSettingsView({uri: uritoopen, @projects, project})

  deactivate: ->
    @process?.kill()
    @process = null
    @subscriptions.dispose()
    consoleview?.destroy()
    consoleview = null
    ConsoleView = null
    askview?.destroy()
    askview = null
    AskView = null
    selectionview?.destroy()
    selectionview = null
    SelectionView = null
    settingsview?.destroy()
    settingsview = null
    SettingsView = null
    localsettingsview?.destroy()
    localsettingsview = null
    LocalSettingsView = null
    @projects?.destroy()
    @Projects = null
    @projects = null

  show: ->
    createConsoleView()
    consoleview?.showBox()

  kill: ->
    @process?.kill()
    @process = null

  cancel: ->
    @kill()
    consoleview?.cancel()

  selection: ->
    createConsoleView()
    if (path = atom.workspace.getActiveTextEditor()?.getPath())?
      if (projectpath = @projects.getNextProjectPath path) isnt ''
        project = null
        if Projects.hasLocal projectpath
          project = Projects.loadLocal projectpath
        project ?= @projects.getProject projectpath
        createSelectionView()
        selectionview.show project, (name) =>
          if (command = project.getCommand name)?
            @saveall() if command.save_all
            @command_list = @projects.generateDependencyList command
            consoleview?.setQueueCount(@command_list.length)
            ll.messages = []
            @spawn @command_list.splice(0, 1)[0]

  saveall: ->
    for editor in atom.workspace.getTextEditors()
      editor.save() if editor.isModified() and editor.getPath()?

  lint: ->
    atom.commands.dispatch(atom.views.getView(atom.workspace), 'linter:lint')

  spawn: (res, clear = true) ->
    {command, cmd, args, env} = res.parseCommand()
    consoleview?.createOutput command
    consoleview?.showBox()
    consoleview?.setHeader("#{res.name} of #{res.project}")
    consoleview?.clear() if clear
    ll.messages = [] if clear
    consoleview?.unlock()
    @kill()
    @process = new BufferedProcess(
      command: cmd
      args: args
      options:
        cwd: command.wd,
        env: env
      stdout: (data) ->
        consoleview?.stdout?.in data
      stderr: (data) ->
        consoleview?.stderr?.in data
      exit: (exitcode) =>
        if (@command_list.length is 0) or exitcode isnt 0
          consoleview?.finishConsole(exitcode)
        if exitcode is 0
          consoleview?.setQueueLength(@command_list.length)
          if @command_list.length isnt 0
            @spawn @command_list.splice(0, 1)[0], false
          else
            consoleview?.setHeader(
              "#{res.name} of #{res.project}: finished with exitcode #{exitcode}"
            )
            @command_list = []
        else
          if consoleview.queue is 1
            consoleview?.setQueueCount(0)
          consoleview?.setHeader(
            "#{res.name} of #{res.project}:" +
            "<span class='error'>finished with exitcode #{exitcode}</span>"
          )
          @command_list = []
        @lint() if (@command_list.length is 0) or exitcode isnt 0
        @process = null
      )
    @process.onWillThrowError ({error, handle}) =>
      consoleview?.hideOutput()
      consoleview?.setHeader("#{res.name} of #{res.project}: received #{error}")
      consoleview?.lock()
      @command_list = []
      @process = null
      handle()

  execute: (id, ask = false) ->
    createConsoleView()
    if (path = atom.workspace.getActiveTextEditor()?.getPath())?
      if (projectpath = @projects.getNextProjectPath path) isnt ''
        project = null
        if Projects.hasLocal projectpath
          project = Projects.loadLocal projectpath
        project ?= @projects.getProject projectpath
        if project?
          bindings = ['make', 'configure', 'preconfigure']
          if (b = bindings[id])?
            if (key = project.key[b])?
              project = @projects.getProject key.project
              command = project.getCommand key.command
            else
              command = project.getCommandByIndex id
          else
            command = project.getCommandByIndex id
          if command?
            if ask
              createAskView()
              askview.show command.command, (c) =>
                _command = new Command(command, c)
                @saveall() if command.save_all
                @command_list = @projects.generateDependencyList _command
                consoleview?.setQueueCount(@command_list.length)
                ll.messages = []
                @spawn @command_list.splice(0, 1)[0]
            else
              @command_list = @projects.generateDependencyList command
              consoleview?.setQueueCount(@command_list.length)
              ll.messages = []
              @saveall() if @command_list[0].save_all
              @spawn @command_list.splice(0, 1)[0]

  provideLinter: ->
    grammarScopes: ['*']
    scope: 'project'
    lintOnFly: false
    lint: ->
      ll.messages

  consumeProfile: ({key, profile}) ->
    Profiles.addProfile key, profile

  config:
    SaveAll:
      title: 'Save all'
      description: 'Default value used in command settings. Save all files before executing your build command'
      type: 'boolean'
      default: true
    ShellCommand:
      title: 'Shell Command'
      description: 'Shell command to execute when "Execute in Shell" is enabled'
      type: 'string'
      default: 'bash -c'
    CloseOnSuccess:
      title: 'Close console on success'
      description: 'Value is used in command settings. 0 to hide console on success, >0 to hide console after x seconds'
      type: 'integer'
      default: 3
