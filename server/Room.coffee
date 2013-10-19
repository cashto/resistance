# sqlserver doesn't check hasOwnProperty when enumerating over arrays, so it
# goes nuts if the below monkeypatched methods are enumerable.

defineMethod = (classname, name, value) ->
    Object.defineProperty classname.prototype, name, { enumerable: false, value: value }
    
defineMethod Array, 'remove', (item) ->
    idx = @indexOf(item)
    @splice(idx, 1) if idx >= 0
    
defineMethod Array, 'removeIf', (fn) -> @[..] = @filter((i) -> not fn(i))
defineMethod Array, 'shuffle', ->
    for i in [0 ... @.length]
        j = Math.floor(Math.random() * (@.length - i) + i)
        [@[i], @[j]] = [@[j], @[i]]

ORIGINAL_GAMETYPE = 1
AVALON_GAMETYPE = 2
BASIC_GAMETYPE = 3
allGameTypes = [ORIGINAL_GAMETYPE, AVALON_GAMETYPE, BASIC_GAMETYPE]

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
    
        
