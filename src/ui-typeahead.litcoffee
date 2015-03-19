#ui-typeahead
Typeahead control that handles the common typeahead functionality by the following:
- Captures and debouncing user input per the `debounce` attribute
- Allows keypress and click navigation and selection of provided child `ui-typeahead-item` elements
- Publishes two events, `inputchange` that the containing page can use to retrieve the relevant data and template
  in the `ui-typeahead-items`, and `change` which fires when the selected item changes

    require '../node_modules/ui-styles/polyfill.js'

    lastEmittedValue = null
    backspaceBufferCount = 0
    keys =
      up: 38
      down: 40
      enter: 13
      escape: 27
      backspace: 8
      tab: 9


    Polymer 'ui-typeahead',

##Attributes
###value
This is the data value bound picked currently.

      valueChanged: (oldValue, newValue) ->
        selectedTemplate = @querySelector 'template[value]'
        if selectedTemplate
          if Array.isArray @value
            selectedTemplate.setAttribute 'repeat', '{{value}}'
          else if @value
            selectedTemplate.setAttribute 'if', '{{value}}'
            selectedTemplate.setAttribute 'bind', '{{value}}'
            if @value
              @$.input.setAttribute 'placeholder', ''
            else
              @$.input.setAttribute 'placeholder', '{{placeholder}}'
          selectedTemplate.model = value: @value
        @job 'change', ->
          @fire 'change', @value
          if @hasAttribute 'focused'
            @fire 'edit', @value
        , 300

###valueFilter
This function, if present, maps data bound items from the
selection list so that the `value` isn't just limited to exactly the values
in the dropdown list.

###sticky
Allow the menu section to remain open
Can have value for different behaviors: 
  "always" "notempty"
If none are specified then "notempty"

##Events

### change
Change fires when the selected `ui-typeahead-item` changes.

### edit
Fires along with change when a real human is editing.

### inputchange
inputChange fires when user changes the text input of the typehead.  This event is debounced per the debounce property (in milliseconds) and only fires
When the value is different that the previously emitted value.  The event detail contains a single `value` property with the input text, or null if it's been cleared.

###itemadded
With `multiselect`, this fires when a new item is added, with the item as detail.

###itemremoved
With `multiselect`, this fires when a new item is removed, with the item as detail.

##Methods

### open and close

      focus: ->
        @$.input.focus()

      open: ->
        @$.results.setAttribute 'open', ''

      isSticky: ->
        return false unless @.hasAttribute 'sticky'
        @sticky == "always" || (@sticky != "always" && @$.input.value) # the default case is not always with a value; backwards compatibility

      close: (useSticky=true) ->
        return if useSticky && @isSticky()
        if @$.results.hasAttribute 'open'
          @$.results.removeAttribute 'open'
          @clearValue()

### selectItem and clear
Selecting an item means we pull in the data from the rendered `ui-typeahead-item`
and either settting the value or buffering it in an array

      selectItem: (item) ->
        # allow typeahead items to be non-selectable: group headers, messages alternately use diffent element tags
        return if !item or item.nodeName is "UI-TYPEAHEAD-SECTION"

        selectedValue = (@valueFilter or (x) -> x)(item?.templateInstance?.model)
        if @multiselect?
          if not Array.isArray(@value)
            @value = []
          @value.push selectedValue
          @fire 'itemadded', selectedValue
        else
          @value = selectedValue
          @$.input.blur()
          @fire 'itemselected', selectedValue
        @clearValue()

      clear: () ->
        @clearValue()
        if @multiselect?
          if not Array.isArray(@value)
            @value = []
          if @value.length
            item = @value[@value.length-1]
            for value in @querySelectorAll('value')
              if value.templateInstance.model is item
                for element in value.querySelectorAll('*')
                  if element.fireRemove
                    element.fireRemove()
                    return
            #fallthrough to here if the item didn't claim it with fireRemove
            item = @value.pop()
            @fire 'itemremoved', item
        else
          @value = null

### Make sure we clear the value and its hidden backing state + the backspace buffer

      clearValue: ->
        backspaceBufferCount = 0
        @$.input.value = null
        lastEmittedValue = null

##Event Handlers

      focusIn: ->
        @setAttribute 'focused', ''

      focusOut: ->
        @removeAttribute 'focused'

      inputChanged: (evt) ->
        evt.stopPropagation()
        if @$.input.value
          @open()
          @fire 'inputchange', value: @$.input.value
        else
          @close()

### documentClick
Since we stop click propagation from within our element, anything
bubbling up to the document handler is outside us and should unfocus the element

      documentClick: (evt) -> 
        @close(false)

### click
Clicks on a ui-typeahead-item mark it as selected, all clicks within ui-typeahead
are swallowed at this point

      clickResults: (evt) ->
        evt.stopPropagation()
        if evt.target.tagName is "UI-TYPEAHEAD-ITEM"
          @selectItem evt.target

### keyup
On keyup, the typeahead checks for control keypresses.

      keyup: (evt) ->
        focusedItem = @querySelector('ui-typeahead-item[focused]')

        if evt.which in [ keys.enter, keys.tab ]
          @selectItem focusedItem
        else if evt.which is keys.escape
          @close(false)
        else if evt.which is keys.backspace
          @clear() if not @$.input.value and backspaceBufferCount > 0
          backspaceBufferCount += 1
        else
          backspaceBufferCount = 0

Size the results panel so that it doesn't fall off the page, instead -- make it
scroll.

        bottom = window.scrollY + window.innerHeight
        top = @$.results.getBoundingClientRect().top
        height = @$.results.scrollHeight
        if (top + height) > bottom
          maxHeight = bottom - top
          @$.results.style.maxHeight = "#{maxHeight}px"
          if @querySelector('[focused]')?.offsetTop > maxHeight
            @$.results.scrollTop = @querySelector('[focused]')?.offsetTop
          if @querySelector('[focused]')?.offsetTop < @$.results.scrollTop
            @$.results.scrollTop = @querySelector('[focused]')?.offsetTop
        else
          @$.results.style.maxHeight = ''

### keydown
Let's let the user hold a key like up/down to nav the list
Also make sure items scroll into view for long lists

      keydown: (evt) ->
        return unless evt.which in [keys.down,keys.up]
        items = [].slice.call(@querySelectorAll('ui-typeahead-item'))
        focused = @querySelector('ui-typeahead-item[focused]')
        focusIndex = items.indexOf focused

        if evt.which is keys.down
          focused?.removeAttribute 'focused'
          items[ (focusIndex+1)%items.length ]?.setAttribute 'focused', ''

          if items[focusIndex]? && items[focusIndex].offsetTop + items[focusIndex].offsetHeight >= @$.results.offsetHeight
            @$.results.scrollTop += items[focusIndex].offsetHeight

        else if evt.which is keys.up
          focused?.removeAttribute 'focused'
          focusIndex = items.length if focusIndex <= 0
          items[focusIndex-1]?.setAttribute 'focused', ''

###remove
Fired by some elements, see if we can remove the detail data.

      remove: (evt, detail) ->
        if @multiselect?
          idx = @value.indexOf detail
          if idx > -1
            @value.splice idx, 1
          @fire 'itemremoved', detail

##Polymer Lifecycle

### attached
Wiring up the various event handlers, including a document level click handler
that sets focused to false when clicking outside the control (actual blur
wasn't working and would trigger even when clicking results withint the
ui-typeahead)

      attached: ->
        window.addEventListener 'click', (evt) => @documentClick(evt)

### detached

Unwiring the document level click handler.

      detached: ->
        window.removeEventListener 'click', @documentClick

      publish:
        value:
          reflect: true
