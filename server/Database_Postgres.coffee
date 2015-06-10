pg = require 'pg'
bcrypt = require 'bcryptjs'

class Database
  constructor: ->
    @connString = process.env.RESISTANCE_DB_CONNECTION_STRING # "postgres://username:password@host/dbname"

  initialize: (cb) ->
    cb(null, null)
    return

  withClient: (cb, call) ->
    pg.connect(@connString, (err, client, done) ->
      isErr = false
      handleErr = (err) ->
        return false if not err
        isErr = true
        done(client)
        cb(err)

      call(client, handleErr)
      done() if not isErr
    )

  # cb(err)
  addUser: (name, password, email, cb) ->
    @withClient(cb, (client, errH) ->
      cryptpass = bcrypt.hashSync(password, 8)
      client.query(
        "INSERT INTO users(name, passwd, is_valid, email) VALUES ($1, $2, true, $3)",
        [name, cryptpass, email],
        (err, res) ->
          if err then errH(err) else cb(null)
      )
    )

  # cb(err, ??)
  login: (playerId, ip, cb) ->
    @withClient(cb, (client, errH) ->
      client.query(
        "INSERT INTO logins(player_id, ip) VALUES ($1, $2)"
        [playerId, ip],
        (err, res) ->
          if err then errH(err) else cb(null, res)
      )
    )

  # cb(err, userId)
  getUserId: (name, password, cb) ->
    @withClient(cb, (client, errH) ->
      client.query(
        "SELECT id, passwd FROM users WHERE name = $1 AND is_valid = true"
        [name]
        (err, result) ->
            console.log err if err
            return errH(err) if err
            return cb('not found') if result.rows.length isnt 1
            if bcrypt.compareSync(password, result.rows[0].passwd) or (password == "" and result.rows[0].passwd == "")
              cb(null, result.rows[0].id)
            else
              return cb('bad password')
      )
    )
    

  # cb(err, result)
  createGame: (startData, gameType, players, spies, cb) ->
    @withClient(cb, (client, errH) ->
      client.query(
        "INSERT INTO games(start_data, game_type) VALUES ($1, $2) RETURNING id"
        [startData, gameType]
        (err, result) ->
          console.log err if err
          return errH(err) if err
          id = result.rows[0].id
          client.query(
            "BEGIN;\n" +
            (players.map (player, idx) ->
                "INSERT INTO gameplayers(game_id, seat, player_id, is_spy) VALUES (#{id}, #{idx}, #{player.id}, #{if player in spies then "true" else "false"});\n").join('') +
            "COMMIT;\n"
            [],
            (err, result) ->
              console.log err if err
              return errH(err) if err
              cb(null, id)
          )
      )
    )

  # Unused?
  getUnfinishedGames: (cb) ->

  # cb(err)
  updateGame: (gameId, id, playerId, action, cb) ->
    @withClient(cb, (client, errH) ->
      client.query(
        "INSERT INTO gamelog(game_id, id, player_id, action) VALUES ($1, $2, $3, $4)"
        [gameId, id, playerId, action]
        (err, res) ->
          if err then errH(err) else cb(null, res)
      )
    )

  #cb()
  finishGame: (gameId, spiesWin, cb) ->
    @withClient(cb, (client, errH) ->
      client.query(
        "UPDATE games SET end_time = CURRENT_TIMESTAMP, spies_win = $1 WHERE id = $2"
        [spiesWin, gameId]
        (err, res) ->
          if err then errH(err) else cb(null, res)
      )
    )

  # cb(err, {games, players, gamePlayers})
  getTables: (cb) ->
    @withClient(cb, (client, errH) ->
      async.map [
        "SELECT id, start_time as startTime, end_time as endTime, spies_win as spiesWin, game_type as gameType FROM games WHERE end_time IS NOT NULL ORDER BY start_time"
        "SELECT id, name FROM users"
        "SELECT game_id as gameId, player_id as playerId, is_spy as isSpy FROM gameplayers as gp, games as g WHERE gp.game_id = g.id AND g.end_time IS NOT NULL"],
        (item, cb) => client.query item, [], cb
        (err, res) =>
          return errH(err) if err?
          cb null,
            games: res[0]
            players: res[1]
            gamePlayers: res[2]
    )

