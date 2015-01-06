#ui-typeahead

Typeahead control that handles the common typeahead functionality by the following:

- Captures and debouncing user input per the `debounce` attribute
- Allows keypress and click navigation and selection of provided child `ui-typeahead-item` elements
- Publishes two events, `inputchange` that the containing page can use to retrieve the relevant data and template
  in the `ui-typeahead-items`, and `change` which fires when the selected item changes


    lastEmittedValue = null
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
          else
            selectedTemplate.setAttribute 'if', '{{value}}'
            selectedTemplate.setAttribute 'bind', '{{value}}'
            if @value
              @$.input.setAttribute 'placeholder', ''
            else
              @$.input.setAttribute 'placeholder', '{{placeholder}}'
          selectedTemplate.model = value: @value
        @close()
        @fire 'change', @value

###valueFilter
This function, if present, maps data bound items from the
selection list so that the `value` isn't just limited to exactly the values
in the dropdown list.

##Events

### change
Change fires when the selected `ui-typeahead-item` changes.

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
        @$.results.classList.add 'open'

      close: ->
        @$.results.classList.remove 'open'
        @$.input.value = null

### selectItem and clear
Selecting an item means we pull in the data from the rendered `ui-typeahead-item`
and either settting the value or buffering it in an array

      selectItem: (item) ->
        selectedValue = (@valueFilter or (x) -> x)(item?.templateInstance?.model)
        if @multiselect?
          if not Array.isArray(@value)
            @value = []
          @value.push selectedValue
          @fire 'itemadded', selectedValue
        else
          @value = selectedValue
        @$.input.value = null

      clear: () ->
        @$.input.value = null
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

##Event Handlers

      inputChanged: ->
        @async ->
          items = [].slice.call(@querySelectorAll('ui-typeahead-item'))

          focused = @querySelectorAll('ui-typeahead-item[focused]')
          focusIndex = items.indexOf focused[0]
          
          items[focusIndex]?.removeAttribute 'focused'
          items[0]?.setAttribute 'focused', ''
        @open()

### documentClick
Since we stop click propagation from within our element, anything
bubbling up to the document handler is outside us and should unfocus the element

      documentClick: (evt) ->
        @close()

### click
Clicks on a ui-typeahead-item mark it as selected, all clicks within ui-typeahead
are swallowed at this point

      clickResults: (evt) ->
        evt.stopPropagation()
        if evt.target.tagName is "UI-TYPEAHEAD-ITEM"
          @selectItem evt.target

### keyup
On keyup, the typeahead checks for control keypresses and otherwise fires the `debouncedKeyPress`
function, which debounces and then emits `change` (assuming that after the debounce the value
is in fact different)

      keyup: (evt) ->
        items = [].slice.call(@querySelectorAll('ui-typeahead-item'))

        focused = @querySelectorAll('ui-typeahead-item[focused]')
        focusIndex = items.indexOf focused[0]

        if evt.which is keys.down
          items[focusIndex]?.removeAttribute 'focused'
          items[ (focusIndex+1)%items.length ]?.setAttribute 'focused', ''

        else if evt.which is keys.up
          items[focusIndex]?.removeAttribute 'focused'
          focusIndex = items.length if focusIndex <= 0
          items[focusIndex-1]?.setAttribute 'focused', ''

        else if evt.which in [ keys.enter, keys.tab ]
          @selectItem items[focusIndex]

        else if evt.which is keys.escape
          @close()
          @fire 'inputchange', { value: null }
        else if evt.which is keys.backspace
          if not @$.input.value
            @clear()
        else
          @debouncedKeyPress(evt)

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

###remove
Fired by some elements, see if we can remove the detail data.

      remove: (evt, detail) ->
        if @multiselect?
          index = @value.indexOf(detail)
          if index > -1
            @value.splice(index, 1)
            @fire 'itemremoved', detail

##Polymer Lifecycle

### attached
Wiring up the various event handlers, including a document level click handler
that sets focused to false when clicking outside the control (actual blur
wasn't working and would trigger even when clicking results withint the
ui-typeahead)

      attached: ->
        @debounce ||= 300
        @debouncedKeyPress = () ->
          @job 'attachedTimer', =>
            if @$.input.value isnt lastEmittedValue
              lastEmittedValue = @$.input.value
              @fire 'inputchange', { value: @$.input.value }
              @inputChanged()
          , @debounce

        window.addEventListener 'click', (evt) => @documentClick(evt)

### detached

Unwiring the document level click handler.

      detached: ->
        window.removeEventListener 'click', @documentClick

      publish:
        value:
          reflect: true
