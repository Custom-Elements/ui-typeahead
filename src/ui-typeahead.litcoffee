#ui-typeahead

Typeahead control that handles the common typeahead functionality by the following:

- Captures and debouncing user input per the `debounce` attribute
- Allows keypress and click navigation and selection of provided child `ui-typeahead-item` elements
- Publishes two events, `inputChange` that the containing page can use to retrieve the relevant data and template
  in the `ui-typeahead-items`, and `change` which fires when the selected item changes

    _ = require('../node_modules/lodash/dist/lodash.js')
    lastEmittedValue = null
    
    Polymer 'ui-typeahead',

##Events

### change

Change fires when the selected `ui-typeahead-item` changes.  It returns a detail object with 3 properties

- `index` is index of the selected `ui-typeahead-item` or -1 if item was deselected.  If you have both static and data 
  bound items be aware that this index includes both and may not correspond directly to the index of the data you bound
- `item` is the selected `ui-typeahead-item` DOM object or null if the selection was removed

### inputChange

inputChange fires when user changes the text input of the typehead.  This event is debounced per the debounce property (in milliseconds) and only fires
When the value is different that the previously emitted value.  The event detail contains a single `value` property with the input text, or null if it's been cleared.

##Methods
      
### selectItem and clear

Selects the provided `ui-typeahead-item`, while clear is simply an alias for `selectItem(null)`.

      selectItem: (item) ->
        items = @querySelectorAll('ui-typeahead-item')
        _.each items, (i) ->
          if i is item
            i.setAttribute 'selected', ''
            i.setAttribute 'focused', ''
          else
            i.removeAttribute 'selected'
            i.removeAttribute 'focused'
          true

        index = _.indexOf items, item
        @fire 'change', { item, index }

      clear: -> selectItem null

##Event Handlers
      
      focus: (evt) ->
        @focused = true

### documentClick 

Since we stop click propagation from within our element, anything
bubbling up to the document handler is outside us and should unfocus the element

      documentClick: (evt) ->
        @focused = false 

### click

Clicks on a ui-typeahead-item mark it as selected, all clicks within ui-typeahead 
are swallowed at this point

      click: (evt) ->
        evt.stopPropagation()
        if evt.target in @querySelectorAll('ui-typeahead-item')
          @selectItem evt.target

### keyup

On keyup, the typeahead checks for control keypresses and otherwise fires the `debouncedKeyPress` 
function, which debounces and then emits `change` (assuming that after the debounce the value 
is in fact different) 

      keyup: (evt) ->
        items = @querySelectorAll('ui-typeahead-item')
        focusIndex = _.findIndex items, (i) -> i.hasAttribute 'focused'

        if evt.which is 40 
          items[focusIndex]?.removeAttribute 'focused'
          items[ (focusIndex+1)%items.length ]?.setAttribute 'focused', ''
        else if evt.which is 38
          items[focusIndex]?.removeAttribute 'focused'
          focusIndex = items.length if focusIndex <= 0
          items[focusIndex-1]?.setAttribute 'focused', ''
        else if evt.which in [13, 9]
          @selectItem items[focusIndex]
        else if evt.which is 27
          items[focusIndex]?.focused = false
          @selectItem null
          @fire 'inputChange', { value: null }
        else
          @debouncedKeyPress(evt)


##Polymer Lifecycle


### attached

Wiring up the various event handlers, including a document level click 
handler that sets focused to false when clicking outside the control (actual blur wasn't working
and would trigger even when clicking results withint the ui-typeahead)

      attached: ->
        @debounce ||= 300
        @debouncedKeyPress = _.debounce ->
          if @$.input.value isnt lastEmittedValue
            lastEmittedValue = @$.input.value
            @fire 'inputChange', { value: @$.input.value }
        , @debounce

        @addEventListener 'click', @click
        @addEventListener 'focus', @focus
        @addEventListener 'keyup', @keyup
        window.addEventListener 'click', (evt) => @documentClick(evt)

### detached

Unwiring the document level click handler. 

      detached: ->
        window.removeEventListener 'click', @documentClick
