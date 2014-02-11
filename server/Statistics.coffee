class Statistics
    constructor: (@db) ->
        @refresh()
        @stats = {}
        setInterval (=> @refresh()), 15 * 60 * 1000
        
    get: (param) ->
        return @stats[param] or "not found: #{param}"
        
    refresh: ->
        @db.getTables (err, tables) =>
            return if err?
            @joinTables(tables)
            @stats = 
                activeplayers: @getActivePlayers(tables)
                leaderboard: @getLeaderboard(tables)
                recentgames: @getRecentGames(tables)
                winrates: @getWinRates(tables)
                activity: @getActivity(tables)
    
    joinTables: (tables) ->
        oneMonthAgo = Date.now() - 30 * 24 * 3600 * 1000

        gameIdx = {}
        for game in tables.games
            game.spies = []
            game.resistance = []
            gameIdx[game.id] = game
        
        playerIdx = {}
        for player in tables.players
            player.lastMonthGames = 0
            player.spyGames = 0
            player.spyWins = 0
            player.resistanceGames = 0
            player.resistanceWins = 0
            player.lastGame = new Date(0)
            player.name = xmlEscape(player.name)
            playerIdx[player.id] = player 
        
        for gameplayer in tables.gamePlayers
            game = gameIdx[gameplayer.gameId]
            which = if gameplayer.isSpy then game.spies else game.resistance
            which.push playerIdx[gameplayer.playerId]
        
        for game in tables.games
            for player in game.spies
                player.lastGame = game.startTime
                ++player.spyGames
                ++player.spyWins if game.spiesWin
                ++player.lastMonthGames if game.startTime.getTime() > oneMonthAgo
            for player in game.resistance
                player.lastGame = game.startTime
                ++player.resistanceGames
                ++player.resistanceWins if not game.spiesWin
                ++player.lastMonthGames if game.startTime.getTime() > oneMonthAgo
                
    getActivePlayers: (tables) ->
        html = "<table class='table table-striped table-condensed'><tr><th>Player</th> <th>Games</th></tr>"
        
        for player in tables.players.sort((a, b) -> b.lastMonthGames - a.lastMonthGames)[..25]
            html += "<tr><td>#{player.name}</td><td>#{player.lastMonthGames}</td></tr>"
        
        html += "</table>"
        return html
    
    getLeaderboard: (tables) ->
        oneMonthAgo = Date.now() - 30 * 24 * 3600 * 1000
        
        html = "<table class='table table-striped table-condensed'><tr><th>Player</th> <th>Resistance</th> <th>Spy</th> <th>Total</th></tr>"
        filteredPlayers = tables.players
            .filter((i) -> i.lastGame.getTime() > oneMonthAgo)
            .sort((a,b) -> a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
            
        for player in filteredPlayers
            html += "<tr>" +
                "<td>#{player.name}</td> " +
                "<td>#{@frac(player.resistanceWins, player.resistanceGames)}</td> " +
                "<td>#{@frac(player.spyWins, player.spyGames)}</td> " +
                "<td>#{@frac(player.spyWins + player.resistanceWins, player.spyGames + player.resistanceGames)}</td></tr>"
                
        html += "</table>"
        return html
        
    getRecentGames: (tables) ->
        html = "<table class='table table-striped table-condensed'><tr><th>Start Time</th> <th>Type</th> <th>Players</th> <th>Duration (minutes)</th> <th>Resistance</th> <th>Spies</th></tr>"
        
        gameTypeName =
            1: "Original"
            2: "Avalon"
            3: "Basic"
            
        for i in [0 ... 25]
            game = tables.games[tables.games.length - i - 1]
            html += "<tr>" +
                "<td>#{game.startTime.toUTCString()}</td> " +
                "<td>#{gameTypeName[game.gameType]}</td> " +
                "<td>#{game.spies.length + game.resistance.length}</td> " +
                "<td>#{((game.endTime.getTime() - game.startTime.getTime()) / 60000).toFixed(0)}</td> " +
                "<td class='#{if game.spiesWin then '' else 'info'}'>#{game.resistance.map((i) -> i.name).join(', ')}</td> " +
                "<td class='#{if game.spiesWin then 'info' else ''}'>#{game.spies.map((i) -> i.name).join(', ')}</td></tr>"
            
        html += "</table>"
        return html
        
    getWinRates: (tables) ->
        html = "<table class='table table-striped table-condensed'><tr><th>Players</th> <th>Original</th> <th>Avalon</th> <th>Basic</th></tr>"
        
        for n in [5 .. 10]
            html += "<tr><td>#{n}</td>"
            for type in [1 .. 3]
                games = tables.games.filter((i) -> i.spies.length + i.resistance.length is n and i.gameType is type)
                html += "<td>#{@frac(games.filter((i) -> i.spiesWin).length, games.length)}</td> "
            html += "</tr>"
            
        html += "</table>"
        return html
        
    getActivity: (tables) ->
        hist = {}
        millisInWeek = 1000 * 3600 * 24 * 7
        for game in tables.games
            week = Math.floor(game.startTime.getTime() / millisInWeek)
            if not hist[week]?
                hist[week] =
                    games: 0
                    players: {}
            ++hist[week].games
            for player in game.spies
                hist[week].players[player.id] = true
            for player in game.resistance
                hist[week].players[player.id] = true
                
        rows = for week in Object.keys(hist).sort((a,b) -> a - b)[...-1]
            "[new Date(#{week * millisInWeek}), #{hist[week].games}, #{Object.keys(hist[week].players).length}],\n"
        
        html = "<script>drawChart([['Date', 'Games', 'Players'], #{rows.join('')}]);</script>"
        return html
        
    frac: (n, d) ->
        pct = if d is 0 then 0 else 100 * n / d
        return "#{pct.toFixed(1)}% (#{n} / #{d})"
