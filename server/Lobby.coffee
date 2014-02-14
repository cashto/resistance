class Lobby extends Room
    constructor: () ->
        super
            'allChat': @onAllChat
            'join': @onJoin
            'refresh': @onRefresh
        @nextId = 1
        @games = {}

    onPlayerJoin: (player) ->
        super
        @onRefresh(player)
        
    onPlayerLogin: (player) ->
        @sendAllChat null, "#{player} has joined."
        for p in @players
            p.send '+player', { id: player.id, name: player.name }
        
    onPlayerLogout: (player) ->
        @sendAllChat null, "#{player} has left."
        for p in @players
            p.send '-player', { id: player.id }
        
    onRefresh: (player) ->
        for gameId in Object.keys(@games)
            @sendGame @games[gameId], player
            
        for id, p of g.playersById
            player.send '+player', { id: p.id, name: p.name }

    onGameUpdate: (game) ->
        for player in @players
            @sendGame game, player
            player.flush()
            
    onGameEnd: (game) ->
        for p in @players
            p.send '-game', {id: game.id}
        delete @games[game.id]
            
    onAllChat: (player, request) ->
        @sendAllChat player.name, request.msg
        
    sendAllChat: (playerName, msg) ->
        for id, p of g.playersById
            cmd = 
                player: playerName or 'server'
                msg: msg
            cmd.serverMsg = true if not playerName?
            p.send 'allChat', cmd
            
    onJoin: (player, request) ->
        gameId = request.id
        if not gameId?
            throw 'Invalid gametype' if request.gameType not in allGameTypes
            gameId = @nextId++
            @games[gameId] = new Game(gameId, request.gameType, this, g.db)
            @sendAllChat null, "#{player} has created game ##{gameId}."
            @onGameUpdate(@games[gameId])
        
        room = @games[gameId]
        if not room?
            player.sendMsg 'Cannot join game'
        else
            player.setRoom(room)
            
    sendGame: (game, player) ->
        player.send '+game', { id:game.id, msg:game.getLobbyStatus(), gameType:game.gameType }
