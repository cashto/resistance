class Room
    constructor: (@dispatchTable) ->
        @players = []
        @timerId = setInterval (=> p.forceFlush() for p in @players), 90000
        
    onRequest: (player, request) ->
        handler = @dispatchTable[request.cmd]
        handler.apply(this, [player, request]) if handler?
        p.flush() for p in @players
        player.flush() # player might not be a member of this room anymore ...

    onPlayerJoin: (player) ->
        @players.push(player)
        
    onPlayerLeave: (player) ->
        @players.remove(player)
        
    endRoom: ->
        clearInterval @timerId
    
        
