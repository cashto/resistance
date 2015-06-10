class Player
    constructor: (@name, @id, @sessionKey, @room) ->
        @connection = null
        @lastConnectTime = Date.now()
        @pendingMessages = []
        @room.onPlayerJoin(this)
    
    setRoom: (newRoom) ->
        @room.onPlayerLeave(this)
        @room = newRoom
        @room.onPlayerJoin(this)
        
    onRequest: (request) ->
        console.log "#{this}: #{JSON.stringify(request)}" if request.cmd is 'clientCrash'
        @room.onRequest(this, request)
            
    send: (cmd, params = {}) ->
        params.cmd = cmd
        @pendingMessages.push(params)
        
    sendMsg: (msg) ->
        @send 'msg', {msg: msg}
    
    toString: ->
        @name
        
    flush: ->
        return if @pendingMessages.length is 0
        @forceFlush()
        
    forceFlush: ->
        return if not @connection?
        @connection.header('Cache-Control', 'no-cache')
        @connection.json(@pendingMessages)
        @pendingMessages = []
        @connection = null

