express = require('express')
createSessionKey = require('crypto').randomBytes
toQueryString = require('querystring').stringify
http = require('http')

getPlayer = (req, res) ->
    sessionKey = req.cookies.sessionKey
    if not sessionKey or not g.playersBySessionKey[sessionKey]?
        res.send 401 # Unauthorized
        return null
    return g.playersBySessionKey[sessionKey]

gcPlayers = ->
    now = Date.now()
    playersToGc = (player for sessionKey, player of g.playersBySessionKey when now - player.lastConnectTime > 10 * 60 * 1000)
    
    for player in playersToGc
        player.setRoom(g.lobby) if player.room isnt g.lobby
        g.lobby.onPlayerLeave(player)
        g.lobby.onPlayerLogout(player)
        delete g.playersBySessionKey[player.sessionKey]
        delete g.playersById[player.id]
        
    if playersToGc.length > 0
        for id, player of g.playersById
            player.flush()
    
app = express()

#app.get '*', (req, res) -> res.send('Down for maintenence. ETA: 9pm Pacific (0400 GMT)');
#app.use express.logger()
app.use express.json()
app.use express.cookieParser()

app.get '/server/play', (req, res) ->
    player = getPlayer(req, res)
    return if not player?
    player.lastConnectTime = Date.now()
    player.connection = res
    player.flush()
    
app.post '/server/play', (req, res) ->
    player = getPlayer(req, res)
    return if not player?
    player.onRequest(req.body)
    res.send(200)

app.post '/server/login', (req, res) ->
    g.db.getUserId req.body.username, req.body.password, (err, playerId) ->
        if err
            res.clearCookie('sessionKey')
            res.send(401) # Unauthorized
        else
            sessionKey = createSessionKey(16).toString('hex')
            if g.playersById[playerId]?
                oldSessionKey = g.playersById[playerId].sessionKey
                delete g.playersBySessionKey[oldSessionKey]
                g.playersById[playerId].sessionKey = sessionKey
            else
                g.playersById[playerId] = new Player(req.body.username, playerId, sessionKey, g.lobby)
                g.lobby.onPlayerLogin(g.playersById[playerId])
            g.playersBySessionKey[sessionKey] = g.playersById[playerId]
            res.cookie 'sessionKey', sessionKey 
            res.send(200)
            g.db.login playerId, req.ip, (err, x) ->
                console.log err if err?

app.post '/server/register', (req, res) ->
    isEmpty = (x) -> not x? or x is ''
    
    return res.send(400, 'Invalid username') if isEmpty req.body.username
    return res.send(400, 'Invalid password') if isEmpty(req.body.password1) is '' or req.body.password1 isnt req.body.password2
    return res.send(400, 'Invalid email') if isEmpty(req.body.email) or req.body.email.length < 3 or req.body.email.indexOf('@') is -1
    return res.send(400, 'Invalid captcha') if isEmpty req.body.response
    
    captchaReq = http.request
        method: 'POST'
        hostname: 'www.google.com'
        path: '/recaptcha/api/verify'
        headers:
            'Content-Type': 'application/x-www-form-urlencoded'
        (captchaRes) ->
            data = ''
            captchaRes.on 'data', (chunk) -> data += chunk
            captchaRes.on 'end', ->
                return res.send(400, 'Invalid captcha') if data[...4] isnt 'true'
                g.db.addUser req.body.username, req.body.password1, req.body.email, (err) -> 
                    return res.send(400, 'Invalid username or username already taken') if err?
                    res.send(200)
                
    captchaReq.write toQueryString
        privatekey: process.env.RESISTANCE_RECAPTCHA_PRIVATE_KEY
        remoteip: req.ip
        challenge: req.body.challenge
        response: req.body.response
    captchaReq.end()  
    
app.use express.static(__dirname + "/client")

startServer = ->
    setInterval gcPlayers, 60000
    app.listen(80)
    console.log 'Server started.'

#return startServer()

g.db.initialize (err) -> 
    if err
        console.log err
    else
        startServer()
