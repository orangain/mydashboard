class Dashing.Calendar extends Dashing.Widget

  onData: (data) ->
    $(@node).css('background-color', data.color)
