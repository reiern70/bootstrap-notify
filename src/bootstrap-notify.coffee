###
# Project: Bootstrap Notify = v3.1.8
# Description: Turns standard Bootstrap alerts into "Growl-like" notifications.
# Author: Mouse0270 aka Robert McIntosh
# License: MIT License
# Website: https://github.com/mouse0270/bootstrap-growl
###

((factory) ->
  if typeof define == 'function' and define.amd
    # AMD. Register as an anonymous module.
    define [ 'jquery' ], factory
  else if typeof exports == 'object'
    # Node/CommonJS
    factory require('jquery')
  else
    # Browser globals
    factory jQuery
  return
) ($) ->
  # Create the defaults once
  defaults =
    element: 'body'
    position: null
    type: 'info'
    allow_dismiss: true
    allow_duplicates: true
    newest_on_top: false
    showProgressbar: false
    placement:
      from: 'top'
      align: 'right'
    offset: 20
    spacing: 10
    z_index: 1031
    delay: 5000
    timer: 1000
    url_target: '_blank'
    mouse_over: null
    animate:
      enter: 'animated fadeInDown'
      exit: 'animated fadeOutUp'
    onShow: null
    onShown: null
    onClose: null
    onClosed: null
    onClick: null
    icon_type: 'class'
    template: '
      <div data-notify="container" class="col-xs-11 col-sm-4 alert alert-{0}" role="alert">
        <button type="button" aria-hidden="true" class="close" data-notify="dismiss">&times;</button>
        <span data-notify="icon"></span>
        <span data-notify="title">{1}</span>
        <span data-notify="message">{2}</span>
        <div class="progress" data-notify="progressbar">
          <div class="progress-bar progress-bar-{0}" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%;">
          </div>
        </div>
        <a href="{3}" target="{4}" data-notify="url"></a>
      </div>'

  isDuplicateNotification = (notification) ->
    isDupe = false
    $('[data-notify="container"]').each (i, el) ->
      $el = $(el)
      title = $el.find('[data-notify="title"]').html().trim()
      message = $el.find('[data-notify="message"]').html().trim()
      # The input string might be different than the actual parsed HTML string!
      # (<br> vs <br /> for example)
      # So we have to force-parse this as HTML here!
      isSameTitle = title == $('<div>' + notification.settings.content.title + '</div>').html().trim()
      isSameMsg = message == $('<div>' + notification.settings.content.message + '</div>').html().trim()
      isSameType = $el.hasClass('alert-' + notification.settings.type)
      if isSameTitle and isSameMsg and isSameType
        # we found the dupe. Set the var and stop checking.
        isDupe = true
      !isDupe
    isDupe

  Notify = (element, content, options) ->
    # Setup Content of Notify
    contentObj = content:
      message: if typeof content == 'object' then content.message else content
      title: if content.title then content.title else ''
      icon: if content.icon then content.icon else ''
      url: if content.url then content.url else '#'
      target: if content.target then content.target else '-'
    options = $.extend(true, {}, contentObj, options)
    @settings = $.extend(true, {}, defaults, options)
    @_defaults = defaults
    if @settings.content.target == '-'
      @settings.content.target = @settings.url_target
    @animations =
      start: 'webkitAnimationStart oanimationstart MSAnimationStart animationstart'
      end: 'webkitAnimationEnd oanimationend MSAnimationEnd animationend'
    if typeof @settings.offset == 'number'
      @settings.offset =
        x: @settings.offset
        y: @settings.offset
    # if duplicate messages are not allowed, then only continue if this new message is not a duplicate of one that it already showing
    if @settings.allow_duplicates or !@settings.allow_duplicates and !isDuplicateNotification(this)
      @init()
    return

  String.format = ->
    args = arguments
    str = arguments[0]
    str.replace /(\{\{\d\}\}|\{\d\})/g, (str) ->
      if str.substring(0, 2) == '{{'
        return str
      num = parseInt(str.match(/\d/)[0])
      args[num + 1]

  $.extend Notify.prototype,
    init: ->
      self = this
      @buildNotify()
      if @settings.content.icon
        @setIcon()
      if @settings.content.url != '#'
        @styleURL()
      @styleDismiss()
      @placement()
      @bind()
      @notify =
        $ele: @$ele
        update: (command, update) ->
          commands = {}
          if typeof command == 'string'
            commands[command] = update
          else
            commands = command
          for cmd of commands
            if commands.hasOwnProperty(cmd)
              switch cmd
                when 'type'
                  @$ele.removeClass 'alert-' + self.settings.type
                  @$ele.find('[data-notify="progressbar"] > .progress-bar').removeClass 'progress-bar-' + self.settings.type
                  self.settings.type = commands[cmd]
                  @$ele.addClass('alert-' + commands[cmd]).find('[data-notify="progressbar"] > .progress-bar').addClass 'progress-bar-' + commands[cmd]
                when 'icon'
                  $icon = @$ele.find('[data-notify="icon"]')
                  if self.settings.icon_type.toLowerCase() == 'class'
                    $icon.removeClass(self.settings.content.icon).addClass commands[cmd]
                  else
                    if !$icon.is('img')
                      $icon.find 'img'
                    $icon.attr 'src', commands[cmd]
                  self.settings.content.icon = commands[command]
                when 'progress'
                  newDelay = self.settings.delay - (self.settings.delay * commands[cmd] / 100)
                  @$ele.data 'notify-delay', newDelay
                  @$ele.find('[data-notify="progressbar"] > div').attr('aria-valuenow', commands[cmd]).css 'width', commands[cmd] + '%'
                when 'url'
                  @$ele.find('[data-notify="url"]').attr 'href', commands[cmd]
                when 'target'
                  @$ele.find('[data-notify="url"]').attr 'target', commands[cmd]
                else
                  @$ele.find('[data-notify="' + cmd + '"]').html commands[cmd]
          posX = @$ele.outerHeight() + parseInt(self.settings.spacing) + parseInt(self.settings.offset.y)
          self.reposition posX
          return
        close: ->
          self.close()
          return
      return

    buildNotify: ->
      content = @settings.content
      @$ele = $(String.format(@settings.template, @settings.type, content.title, content.message, content.url, content.target))
      @$ele.attr 'data-notify-position', @settings.placement.from + '-' + @settings.placement.align
      if !@settings.allow_dismiss
        @$ele.find('[data-notify="dismiss"]').css 'display', 'none'
      if @settings.delay <= 0 and !@settings.showProgressbar or !@settings.showProgressbar
        @$ele.find('[data-notify="progressbar"]').remove()
      return

    setIcon: ->
      if @settings.icon_type.toLowerCase() == 'class'
        @$ele.find('[data-notify="icon"]').addClass @settings.content.icon
      else
        if @$ele.find('[data-notify="icon"]').is('img')
          @$ele.find('[data-notify="icon"]').attr 'src', @settings.content.icon
        else
          @$ele.find('[data-notify="icon"]').append '<img src="' + @settings.content.icon + '" alt="Notify Icon" />'
      return

    styleDismiss: ->
      @$ele.find('[data-notify="dismiss"]').css
        position: 'absolute'
        right: '10px'
        top: '5px'
        zIndex: @settings.z_index + 2
      return

    styleURL: ->
      @$ele.find('[data-notify="url"]').css
        backgroundImage: 'url(data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7)'
        height: '100%'
        left: 0
        position: 'absolute'
        top: 0
        width: '100%'
        zIndex: @settings.z_index + 1
      return

    isFunction = (element) ->
      return typeof element === 'function';

    placement: ->
      self = this
      offsetAmt = @settings.offset.y
      css =
        display: 'inline-block'
        margin: '0px auto'
        position: if @settings.position then @settings.position else if @settings.element == 'body' then 'fixed' else 'absolute'
        transition: 'all .5s ease-in-out'
        zIndex: @settings.z_index
      hasAnimation = false
      settings = @settings
      $('[data-notify-position="' + @settings.placement.from + '-' + @settings.placement.align + '"]:not([data-closing="true"])').each ->
        offsetAmt = Math.max(offsetAmt, parseInt($(this).css(settings.placement.from)) + parseInt($(this).outerHeight()) + parseInt(settings.spacing))
        return
      if @settings.newest_on_top == true
        offsetAmt = @settings.offset.y
      css[@settings.placement.from] = offsetAmt + 'px'
      switch @settings.placement.align
        when 'left', 'right'
          css[@settings.placement.align] = @settings.offset.x + 'px'
        when 'center'
          css.left = 0
          css.right = 0
      @$ele.css(css).addClass @settings.animate.enter
      $.each Array('webkit-', 'moz-', 'o-', 'ms-', ''), (index, prefix) ->
        self.$ele[0].style[prefix + 'AnimationIterationCount'] = 1
        return
      $(@settings.element).append @$ele
      if @settings.newest_on_top == true
        offsetAmt = parseInt(offsetAmt) + parseInt(@settings.spacing) + @$ele.outerHeight()
        @reposition offsetAmt
      if self.isFunction(self.settings.onShow)
        self.settings.onShow.call @$ele
      @$ele.one(@animations.start, ->
        hasAnimation = true
        return
      ).one @animations.end, ->
        self.$ele.removeClass self.settings.animate.enter
        if self.isFunction(self.settings.onShown)
          self.settings.onShown.call this
        return
      setTimeout (->
        if !hasAnimation
          if self.isFunction(self.settings.onShown)
            self.settings.onShown.call this
        return
      ), 600
      return

    bind: ->
      self = this
      @$ele.find('[data-notify="dismiss"]').on 'click', ->
        self.close()
        return
      if self.isFunction(self.settings.onClick)
        @$ele.on 'click', (event) ->
          if event.target != self.$ele.find('[data-notify="dismiss"]')[0]
            self.settings.onClick.call this, event
          return
      @$ele.mouseover(->
        $(this).data 'data-hover', 'true'
        return
      ).mouseout ->
        $(this).data 'data-hover', 'false'
        return
      @$ele.data 'data-hover', 'false'
      if @settings.delay > 0
        self.$ele.data 'notify-delay', self.settings.delay
        timer = setInterval((->
          delay = parseInt(self.$ele.data('notify-delay')) - (self.settings.timer)
          if self.$ele.data('data-hover') == 'false' and self.settings.mouse_over == 'pause' or self.settings.mouse_over != 'pause'
            percent = (self.settings.delay - delay) / self.settings.delay * 100
            self.$ele.data 'notify-delay', delay
            self.$ele.find('[data-notify="progressbar"] > div').attr('aria-valuenow', percent).css 'width', percent + '%'
          if delay <= -self.settings.timer
            clearInterval timer
            self.close()
          return
        ), self.settings.timer)
      return

    close: ->
      self = this
      posX = parseInt(@$ele.css(@settings.placement.from))
      hasAnimation = false
      @$ele.attr('data-closing', 'true').addClass @settings.animate.exit
      self.reposition posX
      if self.isFunction(self.settings.onClose)
        self.settings.onClose.call @$ele
      @$ele.one(@animations.start, ->
        hasAnimation = true
        return
      ).one @animations.end, ->
        $(this).remove()
        if self.isFunction(self.settings.onClosed)
          self.settings.onClosed.call this
        return
      setTimeout (->
        if !hasAnimation
          self.$ele.remove()
          if self.isFunction(self.settings.onClosed)
            self.settings.onClosed.call this
        return
      ), 600
      return

    reposition: (posX) ->
      self = this
      notifies = '[data-notify-position="' + @settings.placement.from + '-' + @settings.placement.align + '"]:not([data-closing="true"])'
      $elements = @$ele.nextAll(notifies)
      if @settings.newest_on_top == true
        $elements = @$ele.prevAll(notifies)
      $elements.each ->
        $(this).css self.settings.placement.from, posX
        posX = parseInt(posX) + parseInt(self.settings.spacing) + $(this).outerHeight()
        return
      return

  $.notify = (content, options) ->
    plugin = new Notify(this, content, options)
    plugin.notify

  $.notifyDefaults = (options) ->
    defaults = $.extend(true, {}, defaults, options)
    defaults

  $.notifyClose = (selector) ->
    if typeof selector == 'undefined' or selector == 'all'
      $('[data-notify]').find('[data-notify="dismiss"]').trigger 'click'
    else if selector == 'success' or selector == 'info' or selector == 'warning' or selector == 'danger'
      $('.alert-' + selector + '[data-notify]').find('[data-notify="dismiss"]').trigger 'click'
    else if selector
      $(selector + '[data-notify]').find('[data-notify="dismiss"]').trigger 'click'
    else
      $('[data-notify-position="' + selector + '"]').find('[data-notify="dismiss"]').trigger 'click'
    return

  $.notifyCloseExcept = (selector) ->
    if selector == 'success' or selector == 'info' or selector == 'warning' or selector == 'danger'
      $('[data-notify]').not('.alert-' + selector).find('[data-notify="dismiss"]').trigger 'click'
    else
      $('[data-notify]').not(selector).find('[data-notify="dismiss"]').trigger 'click'
    return

  return
