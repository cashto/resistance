sql = require 'msnodesql'

class AutoRetryConnection
    constructor: ->
    query: (queryStmt, params, cb, retry = 3) ->
        if not @conn?
            @initialize (err, conn) =>
                if retry > 0
                    @query(queryStmt, params, cb, retry - 1)
                else 
                    cb(err, conn)
        else
            @conn.query(queryStmt, params, (err, conn) =>
                if err? and err.sqlstate is '08S01'
                    @conn = null
                    @query(queryStmt, params, cb, retry)
                else
                    cb(err,conn))
    initialize: (cb) ->
        sql.open process.env.RESISTANCE_DB_CONNECTION_STRING, (err, conn) => 
            @conn = if err then null else conn
            cb(err, conn)    
            
class Database
    constructor: ->
        @connection = new AutoRetryConnection()
    
    initialize: (cb) ->
        @connection.initialize(cb)
        return
        
    addUser: (name, password, email, cb) ->
        @connection.query( 
            "INSERT Users(name, passwd, isValid, email) VALUES (?, HASHBYTES('sha2_256', ?), 1, ?)"
            [name, password, email]
            cb)
            
    login: (playerId, ip, cb) ->
        hexByte = (i) -> ('0' + parseInt(i).toString(16))[-2..]
        @connection.query(
            "INSERT Logins(playerId, ip) VALUES (?, CONVERT(BINARY(4), ?, 2))"
            [playerId, ip.split('.').map(hexByte).join('')]
            cb)
            
    getUserId: (name, password, cb) ->
        @connection.query(
            "SELECT id FROM Users WHERE name=? AND passwd=HASHBYTES('sha2_256', ?) AND isValid=1"
            [name, password]
            (err, result) ->
                console.log err if err
                return cb(err) if err
                return cb('not found') if result.length isnt 1
                cb(null, result[0].id))
                
    createGame: (startData, gameType, players, spies, cb) ->
        @connection.query(
            "BEGIN TRANSACTION CreateGame\n" +
            "SET XACT_ABORT ON\n" +
            "DECLARE @gameId INT\n" +
            "INSERT Games(startData, gameType) VALUES (?, ?);\n" +
            "SET @gameId=@@IDENTITY\n" +
            (players.map (player, idx) -> 
                "INSERT GamePlayers(gameId, seat, playerId, isSpy) VALUES (@gameId, #{idx}, #{player.id}, #{if player in spies then 1 else 0})\n").join('') +
            "COMMIT TRANSACTION CreateGame\n" +
            "SELECT @gameId AS id"    
            [startData, gameType]
            (err, result) ->
                console.log err if err?
                return cb(err) if err
                cb(null, result[0].id) if result.length > 0)
                
    getUnfinishedGames: (cb) ->
        # note: not atomic, but is OK since no mutates are ongoing when this is called.
        parseResults = (players, gameLogs) ->
            games = {}
            for player in players
                gameId = players.gameId
                games[gameId] = games[gameId] or { gameId: gameId, players: [], gameLogs: [] }
                games[gameId].players[player.seat] = { id: player.playerId, isSpy: player.isSpy }
            for logs in gameLogs
                gameId = logs.gameId
                games[gameId] = games[gameId] or { gameId: gameId, players: [], gameLogs: [] }
                games[gameId].gameLogs.push { playerId: logs.playerId, action: logs.action }
            return Object.keys(games).map((key) -> games[key])
        @connection.query(
            "SELECT GamePlayers.* FROM Games, GamePlayers WHERE Games.id=GamePlayers.gameId AND Games.endTime IS NULL"
            (err, players) ->
                return cb(err) if err
                @connection.query(
                    "SELECT GameLog.* FROM Games, GameLogs WHERE Games.id=GameLog.gameId AND Games.endTime IS NULL ORDER BY id",
                    (err, gamelogs) ->
                        return cb(err) if err
                        cb(null, parseResults(players, gamelogs))))
                        
    updateGame: (gameId, id, playerId, action, cb) ->
        @connection.query(
            "INSERT GameLog(gameId, id, playerId, action) VALUES (?, ?, ?, ?)"
            [gameId, id, playerId, action]
            cb)
            
    finishGame: (gameId, spiesWin, cb) ->
        @connection.query(
            "UPDATE Games SET endTime=SYSUTCDATETIME(), spiesWin=? WHERE id=?"
            [spiesWin, gameId]
            cb)
            
    getTables: (cb) ->
        async.map [
            "SELECT id, startTime, endTime, spiesWin, gameType FROM Games WHERE endTime IS NOT NULL ORDER BY startTime"
            "SELECT id, name FROM Users"
            "SELECT gameId, playerId, isSpy FROM GamePlayers as gp, Games as g WHERE gp.gameId = g.id AND g.endTime IS NOT NULL"],
            (item, cb) => @connection.query item, [], cb
            (err, res) =>
                return cb(err) if err?
                cb null,
                    games: res[0]
                    players: res[1]
                    gamePlayers: res[2]

