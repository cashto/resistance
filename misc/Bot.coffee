http = require 'http'
    
readFully = (res, cb) ->
    ans = ''
    res.on 'data', (chunk) -> ans += chunk
    res.on 'end', -> cb(ans)

rand = (array) -> array[Math.floor(Math.random() * array.length)]
    
class Bot
    constructor: (@name) ->
        @games = []
        @questions = []
        @cards = []
        @inGame = false
        @gameover = false

    sendAjax: (options = {}) ->
        console.log options.body
        req = http.request
            hostname: '127.0.0.1'
            port: 8080
            method: options.verb or 'POST',
            path: options.url or '/server/play'
            agent: false
            headers:
                'Content-Type': 'application/json' 
                'Cookie': @sessionKey || ""
            (res) =>
                readFully res, (data) =>
                    return if not options.cb?
                    options.cb.apply(this, [res, data])
        req.on 'error', => @sendAjax options
        req.write(JSON.stringify options.body) if options.body?
        req.end()

    pollLoop: (res, data) ->
        for line in JSON.parse(data)
            switch line.cmd
                when 'gameover' then @gameover = true
                when 'leave' then @games = []; @inGame = false
                when 'join' then @cards = []; @questions = []; @inGame = true
                when 'players' then @players = line
                when '+game' then @games.push(line.id)
                when '-game' then @games = @games.filter (i)->i isnt line.id
                when '+card' then @cards.push line
                when '-card' then 0
                when 'choose', 'choosePlayers', 'chooseTakeCard' then @questions.push line
        @sendAjax verb:'GET', cb: @pollLoop
        
    start: ->
        @sendAjax body: { username:@name, password:process.env.RESISTANCE_BOT_PASSWORD || "" }, url: '/server/login', cb: @afterLogin

    afterLogin: (res, data) ->
        @sessionKey  = /(sessionKey=\w*)/.exec res.headers['set-cookie']
        @sendAjax verb:'GET', cb: @pollLoop
        @gameLoop()
    
    gameLoop: ->
        if @inGame then @afterJoinGame() else @considerJoinGame() 
        
    considerJoinGame: ->
        if Math.random() < 0.03 and true
            return @sendAjax body: { cmd: 'join', gameType: rand [1,2,5] }, cb: @gameLoop
        if @games.length is 0 or Math.random() < 0.5
            return setTimeout (=> @gameLoop()), 1000
        game = rand @games
        @gameover = false
        @sendAjax body: { cmd: 'join', id: game }, cb: @gameLoop
        
    afterJoinGame: ->
        if @gameover
            return @sendAjax body: { cmd:'leave' }, cb: @gameLoop
        if @questions.length is 0 or Math.random() < 0.5
            return setTimeout (=> @gameLoop()), 1000
        question = rand @questions
        switch question.cmd
            when 'choose' 
                validChoices = question.choices.filter((q) => 
                    (q isnt 'Fail' or @players.amSpy) and 
                    q isnt 'Remove player' and 
                    typeof(q) is 'string')
                choice = rand validChoices
            when 'choosePlayers'
                choice = []
                while choice.length < question.n
                    player = rand (question.players or (p.id for p in @players.players))
                    choice.push(player) if player not in choice
            when 'chooseTakeCard' then choice = rand @cards
        @questions = @questions.filter (i)->i.choiceId isnt question.choiceId
        @sendAjax body: { cmd: question.cmd, choiceId: question.choiceId, choice: choice }, cb: @gameLoop
        
new Bot('<Alpha>').start()
new Bot('<Bravo>').start()
new Bot('<Charlie>').start()
new Bot('<Delta>').start()
new Bot('<Echo>').start()
new Bot('<Foxtrot>').start()
new Bot('<Golf>').start()
new Bot('<Hotel>').start()
new Bot('<India>').start()
