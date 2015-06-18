{$, $$, ScrollView,TextEditorView} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'
_p = require 'path'

highlight_translation =
  "nh": "No highlighting"
  "ha": "Highlight all"
  "ht": "Highlight tags"
  "hc": "GCC/Clang highlighting"

module.exports =
  class SettingsView extends ScrollView
    CommandView: null
    commandview: null

    DependencyView: null
    dependencyview: null

    ImportView: null
    importview: null

    @content: ->
      @div class:'settings pane-item native-key-bindings', tabindex:-1, =>
        @div class:'project-menu', =>
          @ul class:'list-group', outlet:'project_list', =>
        @div class:'panel', =>
          @div class:'project-header', outlet: 'title'
          @div class:'section', =>
            @div class:'section-header', 'Key bindings'
            @div class:'key-bindings', =>
              @div class:'key-bind', =>
                @div class:'key-desc text-padded', =>
                  @span class:'text-subtle', 'Make Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+O'
                @div id:'make', class:'key-value', =>
                  @div class:'btn-group', =>
                    @button id:'local', class:'btn selected', 'Local'
                    @button id:'custom-value', class:'btn hidden'
                    @button id:'custom', class:'btn', 'Custom'
              @div class:'key-bind', =>
                @div class:'key-desc text-padded', =>
                  @span class:'text-subtle', 'Configure Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+I'
                @div id:'configure', class:'key-value', =>
                  @div class:'btn-group', =>
                    @button id:'local', class:'btn selected', 'Local'
                    @button id:'custom-value', class:'btn hidden'
                    @button id:'custom', class:'btn', 'Custom'
              @div class:'key-bind', =>
                @div class:'key-desc text-padded', =>
                  @span class:'text-subtle', 'Pre-Configure Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+U'
                @div id:'preconfigure', class:'key-value', =>
                  @div class:'btn-group', =>
                    @button id:'local', class:'btn selected', 'Local'
                    @button id:'custom-value', class:'btn hidden'
                    @button id:'custom', class:'btn', 'Custom'
          @div class:'section', =>
            @div =>
              @div class:'section-header', 'Commands'
              @div id:'add-command-button', class:'inline-block btn btn-xs', 'Add command'
              @div id:'import-command-button', class:'inline-block btn btn-xs', 'Import command'
            @div class:'command-container', =>
              @div class:'key-info', =>
                @div class: 'key-desc text-subtle', =>
                  @span class:'text-padded', 'Local Make Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+O'
                @div class: 'key-desc text-subtle', =>
                  @span class:'text-padded', 'Local Configure Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+I'
                @div class: 'key-desc text-subtle', =>
                  @span class:'text-padded', 'Local Pre-Configure Command'
                  @span class:'text-highlight text-padded', 'Ctrl+L Ctrl+U'
              @div class:'command-menu', =>
                @div class:'command-list', outlet: 'command_list', =>
          @div class:'section', =>
            @div =>
              @div class:'section-header', 'Dependencies'
              @div id:'add-dependency-button', class:'inline-block btn btn-xs', 'Add dependency'
              @div id:'import-dependency-button', class:'inline-block btn btn-xs', 'Import dependency'
            @div class:'dependency-list', outlet:'dependency_list', =>

    initialize: ({@uri,@projects}) ->
      super
      @reload()
      @CommandView=null
      @commandview=null
      @DependencyView=null
      @dependencyview=null
      ImportView=null
      importview=null
      @on 'click', '#add-command-button', (e) =>
        @CommandView ?= require './command-view'
        @commandview ?= new @CommandView(@editccb)
        @commandview.show(null, null, @activeProject)
      @on 'click', '#add-dependency-button', (e) =>
        @DependencyView ?= require './dependency-view'
        @dependencyview ?= new @DependencyView(@editdcb, @projects)
        @dependencyview.show(@activeProject.path)
      @on 'click', '#import-command-button', (e) =>
        @ImportView ?= require './import-view'
        @importview ?= new @ImportView(@projects)
        @importview.show(false, @importccb, @activeProject.path)
      @on 'click', '#import-dependency-button', (e) =>
        @ImportView ?= require './import-view'
        @importview ?= new @ImportView(@projects)
        @importview.show(true, @importdcb, @activeProject.path)
      @on 'click', '.key-value .btn-group .btn', (e) =>
        key = e.currentTarget.parentNode.parentNode.id
        if e.currentTarget.id is 'local'
          @activeProject.clearKey key
          group = $(e.currentTarget.parentNode)
          group.find('.selected').removeClass('selected')
          e.currentTarget.classList.add('selected')
          @activeProject.clearKey key
        else if e.currentTarget.id is 'custom'
          @ImportView ?= require './import-view'
          @importview ?= new @ImportView(@projects)
          @importview.show(false, (command) =>
            @selectccb(key, command)
          , @activeProject.path)
        else
          group = $(e.currentTarget.parentNode)
          group.find('.selected').removeClass('selected')
          e.currentTarget.classList.add('selected')
      return

    destroy: ->
      @detach()
      @commandview?.destroy()
      @CommandView=null
      @commandview=null
      @dependencyview?.destroy()
      @DependencyView=null
      @dependencyview=null
      importview?.destroy()
      ImportView=null
      importview=null
      @projects = null

    attached: ->
      @filechange = @projects?.onFileChange @reload

    detached: ->
      @filechange?.dispose()
      @filechange = null

    getURI: ->
      @uri

    getTitle: ->
      'Build Tools Settings'

    getIconName: ->
      'tools'

    updateProjects: ->
      paths = atom.project.getPaths()
      @project_list.empty()
      small_paths = @removeSharedPath paths
      for name,i in small_paths
        @addProject name, paths[i]
      @project_list.on 'click', '.project-item', (e) =>
        @setActiveProject e.currentTarget

    addProject: (name, path) ->
      item = $$ ->
        @li class:'list-item project-item', =>
          @div class:'icon icon-book', name
          @div class:'text-subtle', path
      @project_list.append(item)
      @projects.addProject(path) if not @projects.getProject(path)?

    removeSharedPath: (paths) ->
      if paths.length is 1 then return paths
      path_elements = (e.split(_p.sep) for e in paths)
      item = ''
      finished = false

      while not finished
        for e,i in path_elements
          if i is 0
            item = e.splice(0,1)[0]
          else
            if e[0] is item
              e.splice(0,1)
            else
              finished = true
              for j in [0..i-1]
                path_elements[j].splice(0,1,item)
              break
      (e.join(_p.sep) for e in path_elements)

    setActiveProject: (e) ->
      name = e.children[0].innerHTML
      path = e.children[1].innerHTML
      @activeProject = @projects.getProject path
      @markAsActive e
      @setContent name, path

    getElement: (path) ->
      for e in @project_list.children()
        if e.children[1].innerHTML is path
          return e

    setContent: (name, path) ->
      @clearAll()
      @title.html name
      if (project = @projects.getProject(path))?
        @setKeybinding 'make', project.key.make
        @setKeybinding 'configure', project.key.configure
        @setKeybinding 'preconfigure', project.key.preconfigure
        for command in project.commands
          @addCommand command
        for dependency in project.dependencies
          @addDependency dependency

    setKeybinding: (key, binding) ->
      if binding?
        btn_group = @find("\##{key}")
        btn = btn_group.find('#custom-value')
        btn.html("#{binding.project}:#{binding.command}")
        btn_group.find('.selected').removeClass('selected')
        btn.removeClass('hidden')
        btn.addClass('selected')
      else
        btn_group = @find("\##{key}")
        btn_group.find('#custom-value').addClass('hidden')
        btn_group.find('.selected').removeClass('selected')
        btn_group.find('#local').addClass('selected')

    clearAll: ->
      @command_list.empty()
      @dependency_list.empty()

    clearDependencies: ->
      @dependency_list.empty()

    reload: =>
      if @commandview?.visible()
        @commandview.hide()
      if @dependencyview?.visible()
        @dependencyview.hide()
      if @importview?.visible()
        @importview.hide()
      @updateProjects()
      if @activeProject?
        if @projects.getProject(@activeProject.path)? and (e=@getElement(@activeProject.path))?
          @setActiveProject e
        else
          @setActiveProject @project_list.children()[0]
      else
        @setActiveProject @project_list.children()[0]

    markAsActive: (e) ->
      @project_list.find('.active').removeClass('active')
      e.classList.add('active')

    editccb: (oldname, items) =>
      if oldname?
        @activeProject.replaceCommand oldname, items
      else
        @activeProject.addCommand items

    editdcb: (oldid, items) =>
      if oldid?
        @activeProject.replaceDependency oldid, items
      else
        @activeProject.addDependency items

    importccb: (command) =>
      @CommandView ?= require './command-view'
      @commandview ?= new @CommandView(@editccb)
      @commandview.show(null, command, @activeProject)

    importdcb: (dependency) =>
      @DependencyView ?= require './dependency-view'
      @dependencyview ?= new @DependencyView(@editdcb, @projects)
      @dependencyview.show(dependency.from.project, dependency, null)

    selectccb: (key, command) =>
      @activeProject.setKey key,
        project: command.project
        command: command.name

    addCommand: (items) ->
      item = $$ ->
        @div class:'command', =>
          @div class:'top', =>
            @div id:'info', class:'align', =>
              @div class:'icon-expand expander'
              @div id:'name', items.name
            @div id:'options', class:'align', =>
              @div class:'icon-edit'
              @div class:'icon-up'
              @div class:'icon-down'
              @div class:'icon-close'
          @div class:'info hidden', =>
            @div id:'general', =>
              @div =>
                @div class:'text-padded', "Command"
                @div class:'text-padded', "Working Directory"
                @div class:'text-padded', "Shell"
                @div class:'text-padded', "Wildcards"
              @div class:'values', =>
                @div class:'text-highlight text-padded', items.command
                @div class:'text-highlight text-padded', items.wd
                @div class:'text-highlight text-padded', items.shell.toString()
                @div class:'text-highlight text-padded', items.wildcards.toString()
            @div class:'streams', =>
              @div id:'stdout', class:'stream', =>
                @div =>
                  @div class:'text-padded', "Mark paths (stdout)"
                  @div class:'text-padded', "Highlighting (stdout)"
                  @div class:'text-padded', "Use Linter (stdout)"
                @div class:'values', =>
                  @div class:'text-highlight text-padded', items.stdout.file.toString()
                  @div class:'text-highlight text-padded', highlight_translation[items.stdout.highlighting]
                  @div class:'text-highlight text-padded', if /ht|hc/.test(items.stdout.highlighting) then items.stdout.lint.toString() else 'Disabled'
              @div id:'stderr', class:'stream', =>
                @div =>
                  @div class:'text-padded', "Mark paths (stderr)"
                  @div class:'text-padded', "Highlighting (stderr)"
                  @div class:'text-padded', "Use Linter (stderr)"
                @div class:'values', =>
                  @div class:'text-highlight text-padded', items.stderr.file.toString()
                  @div class:'text-highlight text-padded', highlight_translation[items.stderr.highlighting]
                  @div class:'text-highlight text-padded', if /ht|hc/.test(items.stderr.highlighting) then items.stderr.lint.toString() else 'Disabled'
      item.on 'click', '.icon-expand', (e) =>
        @reduceAll e.currentTarget.parentNode.parentNode.parentNode.parentNode
        @expandCommand e.currentTarget
      item.on 'click', '.icon-down', (e) =>
        target = e.currentTarget
        if target.classList.contains('expander')
          @reduceCommand target
        else
          @moveCommandDown target.parentNode.parentNode.parentNode
      item.on 'click', '.icon-up', (e) =>
        @moveCommandUp e.currentTarget.parentNode.parentNode.parentNode
      item.on 'click', '.icon-close', (e) =>
        @removeCommand e.currentTarget.parentNode.parentNode.parentNode
      item.on 'click', '.icon-edit', (e) =>
        @editCommand e.currentTarget.parentNode.parentNode.parentNode
      @command_list.append(item)

    addDependency: (items) ->
      item = $$ ->
        @div class:'dependency', =>
          @div class:'align', =>
            @span class:'text-success', items.from.command
            @span class:'dep', ' depends on '
            @span class:'text-success', items.to.project
            @span ':'
            @span class:'text-success', items.to.command
          @div id:'options', =>
            @div class:'icon-edit'
            @div class:'icon-up'
            @div class:'icon-down'
            @div class:'icon-close'
      item.on 'click', '.icon-edit', (e) =>
        @editDependency e.currentTarget.parentNode.parentNode
      item.on 'click', '.icon-up', (e) =>
        @moveDependencyUp e.currentTarget.parentNode.parentNode
      item.on 'click', '.icon-down', (e) =>
        @moveDependencyDown e.currentTarget.parentNode.parentNode
      item.on 'click', '.icon-close', (e) =>
        @removeDependency e.currentTarget.parentNode.parentNode
      @dependency_list.append(item)

    expandCommand: (target) ->
      target.classList.remove 'icon-expand'
      target.classList.add 'icon-down'
      target.parentNode.parentNode.parentNode.children[1].classList.remove('hidden')
      target.parentNode.parentNode.classList.add('top-expanded')

    reduceCommand: (target) ->
      target.classList.remove 'icon-down'
      target.classList.add 'icon-expand'
      target.parentNode.parentNode.parentNode.children[1].classList.add('hidden')
      target.parentNode.parentNode.classList.remove('top-expanded')

    editCommand: (target) ->
      @CommandView ?= require './command-view'
      @commandview ?= new @CommandView(@editccb)
      id = Array.prototype.indexOf.call(target.parentNode.childNodes, target)
      cmd = @activeProject.getCommandByIndex id
      @commandview.show(cmd.name, cmd, @activeProject)

    editDependency: (target) ->
      @DependencyView ?= require './dependency-view'
      @dependencyview ?= new @DependencyView(@editdcb, @projects)
      id = Array.prototype.indexOf.call(target.parentNode.childNodes, target)
      @dependencyview.show(@activeProject.path, @activeProject.dependencies[id], id)

    reduceAll: (target) ->
      $(target).find('.expander').each (i,e) =>
        @reduceCommand e

    moveCommandDown: (target) ->
      node = $(target)
      if node.index() isnt target.parentNode.childElementCount-1
        @activeProject.moveCommand $(target).find('#name').html(), 1

    moveDependencyDown: (target) ->
      node = $(target)
      if node.index() isnt target.parentNode.childElementCount-1
        id = Array.prototype.indexOf.call(target.parentNode.childNodes, target)
        @activeProject.moveDependency id, 1

    moveCommandUp: (target) ->
      node = $(target)
      if node.index() isnt 0
        @activeProject.moveCommand $(target).find('#name').html(), -1

    moveDependencyUp: (target) ->
      node = $(target)
      if node.index() isnt 0
        id = Array.prototype.indexOf.call(target.parentNode.childNodes, target)
        @activeProject.moveDependency id, -1

    removeCommand: (target) ->
      @activeProject.removeCommand $(target).find('#name').html()

    removeDependency: (target) ->
      id = Array.prototype.indexOf.call(target.parentNode.childNodes, target)
      @activeProject.removeDependency id
