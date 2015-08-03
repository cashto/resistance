class Game extends Room
    constructor: (@id, @gameType, @lobby, @db) ->
        super
            'leave': @onLeave
            'chat': @onChat
            'allChat': @onAllChat
            'choose': @onChoose
            'choosePlayers': @onChoosePlayers
            'chooseTakeCard': @onChooseTakeCard
            'refresh': @onRefresh
        @nextId = 1
        @leader = 0
        @activePlayers = []
        @spies = []
        @questions = []
        @status = ''
        @gameStarted = false
        @gameFinished = false
        @log = []
        @cards = []
        @mission = 1
        @round = 1
        @score = []
        @guns = []
        @investigator = null
        @cardName =
            KeepingCloseEye: 'KEEPING A CLOSE EYE ON YOU'
            EstablishConfidence: 'ESTABLISH CONFIDENCE'
            StrongLeader: 'STRONG LEADER'
            Overheard: 'OVERHEARD CONVERSATION'
            NoConfidence: 'NO CONFIDENCE'
            InTheSpotlight: 'IN THE SPOTLIGHT'
            OpenUp: 'OPEN UP'
            TakeResponsibility: 'TAKE RESPONSIBILITY'
            OpinionMaker: 'OPINION MAKER'
            LadyOfTheLake: 'LADY OF THE LAKE'
            Inquisitor: 'INQUISITOR'
        @removedPlayerIds = []
        @votelog =
            rounds: [0, 0, 0, 0, 0]
            leader: []
            approve: []
            reject: []
            onteam: []
            investigator: []
        @avalonOptions =
            usePercival: false
            useMorgana: false
            useMordred: false
            useOberon: false
            combineMordredAndAssassin: false
            useLadyOfTheLake: false
        @ineligibleLadyOfTheLakeRecipients = []
        @hunterOptions = 
            useDummyAgent: false
            useCoordinator: false
            useDeepAgent: false
            usePretender: false
            useBlame: false
            useInquisitor: false
        @ineligibleResHunterAccusees = []
        @ineligibleSpyHunterAccusees = []
        @spyHunterRevealed = false
        @resHunterRevealed = false
        @startQuestionId = 1
        
    onRequest: (player, request) ->
        if @dbId? and request.cmd not in ['chat', 'allChat']
            @db.updateGame @dbId, ++@nextId, player.id, JSON.stringify(request), (err) ->
                console.log err if err?
        super
        
    onPlayerJoin: (player) ->
        super
        for p in @activePlayers when p.id is player.id
            p.__proto__ = player
        @onRefresh(player)
        @onChat null, { msg: "#{player} has entered the game." }
        if @players.length is 1 then @addActivePlayer(player) else @askToJoinGame(player)
        
    onRefresh: (player) ->
        player.send 'join'            
        @sendPlayers player
        player.send 'status', { msg:@status }
        player.send('gamelog', log) for log in @log
        player.send('+card', { player:card.player.id, card:card.card }) for card in @cards
        player.send 'scoreboard', @getScoreboard() if @gameStarted
        player.send 'leader', { player:@activePlayers[@leader].id } if @activePlayers.length > 0
        player.send(q.question.cmd, q.question) for q in @questions when q.player.id is player.id
        player.send 'gameover' if @gameFinished
        player.send 'guns', { players:@guns }
        player.send 'investigator', { player:@investigator }
        player.send 'votelog', @votelog
    
    onPlayerLeave: (player) ->
        super

        @cancelQuestions([player]) if not @gameStarted
        @onChat null, { msg: "#{player} has left the game." }
                         
        if player.id in @activePlayers.map((p)->p.id)
            if not @gameStarted
                @activePlayers.removeIf (p)->p.id is player.id
                @onPlayersChanged()
                
            currentPlayers = (p for p in @activePlayers when @players.some (i)->i.id is p.id)
            if currentPlayers.length is 0
                p.setRoom(@lobby) for p in @players[..]
                
        if @players.length is 0
            @lobby.onGameEnd(this)
            @endRoom()
                
        player.send 'leave'

    getLobbyStatus: ->
        status = 'Waiting'
        status = 'Running' if @gameStarted
        status = 'Finished' if @gameFinished
        "#{status} (#{@activePlayers.length} / 10)"
        
#-----------------------------------------------------------------------------    
# Handlers for user input
#-----------------------------------------------------------------------------
        
    onChat: (player, request) ->
        for p in @players
            cmd =
                player: (if player? then player.name else 'server')
                msg: request.msg
            cmd.serverMsg = true if not player?
            cmd.isSpectator = player? and @gameStarted and not @gameFinished and not @activePlayers.some (i) -> i.id is player.id
            p.send 'chat', cmd
            
    onAllChat: (player, request) ->
        @lobby.onAllChat(player, request)
            
    onLeave: (player, request) ->
        player.setRoom(@lobby)
        
    onChoose: (player, request) ->
        question = @findQuestion player, request
        return if not question?
        
        choiceMatches = (choice, requestChoice) ->
            if typeof(choice) is 'string'
                return requestChoice is choice
            else
                return requestChoice in choice[1..]
                
        for choice in question.question.choices
            if choiceMatches(choice, request.choice)
                return @answerQuestion question, request.choice
                
        throw "Invalid response"
        
    onChoosePlayers: (player, request) ->
        question = @findQuestion player, request
        return if not question?
        if not question.question.canCancel or request.choice.length > 0
            throw "Incorrect number of players" if request.choice.length isnt question.question.n
        if question.question.players?
            for playerId in request.choice
                throw "Invalid player" if playerId not in question.question.players 
        @answerQuestion question, (@findPlayer(playerId) for playerId in request.choice)
        
    onChooseTakeCard: (player, request) ->
        question = @findQuestion player, request
        return if not question?
        @answerQuestion question, { card:request.choice.card, player:@findPlayer(request.choice.player) }

#-----------------------------------------------------------------------------    
# Primary game logic
#-----------------------------------------------------------------------------    
    
    addActivePlayer: (player) ->
        playerShim = 
            thisGame: this
            send: -> @__proto__.send.apply(this, arguments) if @room is @thisGame
            sendMsg: -> @__proto__.sendMsg.apply(this, arguments) if @room is @thisGame
        playerShim.__proto__ = player
        @activePlayers.push playerShim
        @onPlayersChanged()
        
    askToJoinGame: (player) ->
        return if @gameStarted or player.id in @removedPlayerIds
        @askOne player,
            cmd: 'choose'
            msg: 'Click "join" to join the game.'
            choices: ['Join']
            (response) =>
                if @gameStarted
                    player.sendMsg 'This game has already started.'
                else if @activePlayers.length >= 10
                    player.sendMsg 'This game is currently full.'
                    @askToJoinGame player
                else
                    @addActivePlayer player
    
    askToStartGame: ->
        return if @gameStarted or @activePlayers.length is 0
        gameController = @activePlayers[0]
        
        if @activePlayers.length < 5
            @setStatus 'Waiting for more players ...'
        else
            @setStatus "Waiting for #{gameController} to start the game ..."
        
        choices = ['OK', 'Remove player']
        choices.push(@getAvalonOptions()) if @gameType is AVALON_GAMETYPE
        choices.push(@getHunterOptions()) if @gameType is HUNTER_GAMETYPE
        message = "Press OK to start game"
        message += " with " + @getAvalonRolesString() if @gameType is AVALON_GAMETYPE
        message += " with " + @getHunterRolesString() if @gameType is HUNTER_GAMETYPE
        
        if @questions.every((i)->i.player isnt gameController)
            @startQuestionId = @askOne gameController,
                cmd: 'choose'
                msg: message
                choices: choices
                (response) =>
                    switch response.choice
                        when 'OK'
                            if @activePlayers.length < @getRequiredPlayers()
                                gameController.sendMsg "This game needs at least #{@getRequiredPlayers()} players to start."
                                @askToStartGame()
                            else 
                                @startGame()
                        when 'Remove player'
                            @askToRemovePlayer(gameController)
                        else
                            @setAvalonOption(response.choice) if @gameType is AVALON_GAMETYPE
                            @setHunterOption(response.choice) if @gameType is HUNTER_GAMETYPE
                            @askToStartGame()
        else if @gameType is HUNTER_GAMETYPE
          @updateAskOne @startQuestionId, gameController,
              cmd: 'choose'
              msg: message
              choices: choices
                            
    askToRemovePlayer: (gameController) ->
        @askOne gameController,
            cmd: 'choosePlayers'
            n: 1
            msg: 'Choose which player to remove from game.'
            canCancel: true
            (response) =>
                if response.choice.length > 0 and response.choice[0] isnt gameController
                    @removedPlayerIds.push(response.choice[0].id)
                    @activePlayers = (p for p in @activePlayers when p isnt response.choice[0])
                    response.choice[0].sendMsg 'You have been removed from the game.'
                    @onPlayersChanged()
                @askToStartGame()

    startGame: ->
        @cancelQuestions @everyoneExcept(@activePlayers, @players)
        
        @lobby.onGameUpdate(this)
        @activePlayers.shuffle()
        state = @getInitialState()

        for own key, value of state
            this[key] = value
        
        @gameStarted = true
        @onPlayersChanged()
        @missionTeamSizes = [
            [2, 3, 2, 3, 3]
            [2, 3, 4, 3, 4]
            [2, 3, 3, 4, 4]
            [3, 4, 4, 5, 5]
            [3, 4, 4, 5, 5]
            [3, 4, 4, 5, 5]][@activePlayers.length - 5]
        @failuresRequired = [
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1],
            [1, 1, 1, 2, 1],
            [1, 1, 1, 2, 1],
            [1, 1, 1, 2, 1],
            [1, 1, 1, 2, 1]][@activePlayers.length - 5]
            
        if @gameType is AVALON_GAMETYPE
            whoIsInTheGame = "#{@getAvalonRolesString()} are in this game."
            @gameLog whoIsInTheGame
        if @gameType is HUNTER_GAMETYPE
            whoIsInTheGame = "#{@getHunterRolesString()} are in this game."
            @gameLog whoIsInTheGame
          
        for p in @activePlayers
            roleMsg = ""
            if @gameType is AVALON_GAMETYPE
              roleMsg = 
                if p.id in [@merlin, @percival, @morgana, @oberon, @mordred]
                    "You are #{p.role}. "
                else if p.id is @assassin
                    "You are the assassin. "
                else
                    ""
            if @gameType is HUNTER_GAMETYPE
                for chiefs in [@resistanceChiefs, @spyChiefs]
                    if p.id in chiefs
                      if chiefs.length is 1
                        roleMsg = "You are the #{p.role}. "
                      else
                        roleMsg = "You are a #{p.role}. "
                if p.id in [@resistanceHunter, @spyHunter, @dummyAgent, @coordinator, @deepAgent, @pretender]
                    roleMsg = "You are the #{p.role}. "

            p.sendMsg "#{roleMsg}You are #{if p in @spies then 'a SPY' else 'RESISTANCE!'}! There are #{@spies.length} spies in this game."
            p.sendMsg whoIsInTheGame if @gameType is AVALON_GAMETYPE or @gameType is HUNTER_GAMETYPE
                
        delete state.spies
        gameType = @gameType
        gameType = AVALON_PLUS_GAMETYPE if @percival or @morgana or @oberon or @mordred or @ladyOfTheLake
        gameType = HUNTER_PLUS_GAMETYPE if @dummyAgent or @coordinator or @deepAgent or @pretender or @inquisitor
        
        if @inquisitor? then @ladyOfTheLake = @inquisitor
        if @ladyOfTheLake
            if @inquisitor?
                @ladyInquisitorCard = 'Inquisitor'
                @ladyInquisitorText = 'INQUISITOR'
            else
                @ladyInquisitorCard = 'LadyOfTheLake'
                @ladyInquisitorText = 'LADY OF THE LAKE'

            ladyOfTheLake = @findPlayer(@ladyOfTheLake)
            @addCard ladyOfTheLake, @ladyInquisitorCard
            @ineligibleLadyOfTheLakeRecipients.push(ladyOfTheLake)
            
        if @gameType is HUNTER_GAMETYPE
            @ineligibleResHunterAccusees.push(@findPlayer(@resistanceHunter))
            @ineligibleSpyHunterAccusees.push(@findPlayer(@spyHunter))
            
        @db.createGame JSON.stringify(state), gameType, @activePlayers, @spies,
            (err, result) => 
                @dbId = result
                @nextRound()
                p.flush() for p in @players
          
    nextRound: ->
        return @spiesWin() if @round > 5
        @leader = (@leader + 1) % @activePlayers.length
        @sendAll 'scoreboard', @getScoreboard()
        @sendAll 'leader', { player:@activePlayers[@leader].id }
        @setGuns []
        @setInvestigator null
        @gameLog "#{@activePlayers[@leader]} is the mission leader."
        
        return @askToPlayStrongLeader() if @round isnt 1 or @mission < 3
        
        @ask "deciding who to give #{@ladyInquisitorText} to.",
            @makeQuestions @whoeverHas(@ladyInquisitorCard),
                cmd: 'choosePlayers'
                msg: "Choose a player to give #{@ladyInquisitorText} to."
                n: 1,
                players: @getIds @everyoneExcept @ineligibleLadyOfTheLakeRecipients
                (response, doneCb) =>
                    target = response.choice[0]
                    response.player.sendMsg "#{target} is #{if target in @spies then 'a SPY' else 'RESISTANCE'}!"
                    @sendAllMsgAndGameLog "#{response.player} gave #{@ladyInquisitorText} to #{target}.", [response.player]
                    @subCard response.player, @ladyInquisitorCard
                    @addCard target, @ladyInquisitorCard
                    @ineligibleLadyOfTheLakeRecipients.push(target)
                    doneCb()
            => @askToPlayStrongLeader()
            
    askToPlayStrongLeader: ->
        @ask 'deciding whether they want to use STRONG LEADER ...',
            @makeQuestions @everyoneExcept([@activePlayers[@leader]], @whoeverHas('StrongLeader')),
                cmd: 'choose'
                msg: 'Do you want to use STRONG LEADER?'
                choices: ['Yes', 'No']
                (response, doneCb) =>
                    return doneCb() if response.choice is 'No'
                    strongLeader = response.player
                    @leader = @activePlayers.indexOf(strongLeader)
                    @sendAllMsgAndGameLog "#{strongLeader} used STRONG LEADER."
                    @subCard strongLeader, 'StrongLeader'
                    @sendAll 'leader', { player:strongLeader.id }
                    @cancelQuestions()
                    @distributeCards()
            => @distributeCards()
                    
    distributeCards: ->
        @votelog.rounds[@mission - 1] = @round
        @votelog.leader.push @activePlayers[@leader].id
        @votelog.approve.push []
        @votelog.reject.push []
        @votelog.onteam.push []
        @votelog.investigator.push null
        
        return @askLeaderForTeam() if @round isnt 1 or @gameType isnt ORIGINAL_GAMETYPE
        cardsRequired = Math.floor((@activePlayers.length - 3) / 2)
        cards = (@deck.shift() for i in [0 ... cardsRequired])
        leader = @activePlayers[@leader]
        
        questionText = (card) =>
            if card is 'EstablishConfidence'
                "You have ESTABLISH CONFIDENCE. Choose who to reveal your identity to."
            else
                "Choose a player to give #{@cardName[card]} to."
        
        @ask "deciding who to give #{@nameList (@cardName[card] for card in cards)} to ...",
            for card in cards
                do (card) =>
                    player: leader,
                    question:
                        cmd: 'choosePlayers'
                        msg: questionText(card)
                        n: 1,
                        players: @getIds @everyoneExcept [leader]
                    cb: (response, doneCb) => @distributeCard(leader, card, response.choice[0], doneCb)
            => @askLeaderForTeam()
        
    distributeCard: (player, card, recipient, doneCb) ->
        if card isnt 'EstablishConfidence'
            @sendAllMsgAndGameLog "#{player} gave #{@cardName[card]} to #{recipient}.", [player]
    
        showIdentityTo = (src, dest) =>
            dest.sendMsg "#{src} is #{if src in @spies then 'a SPY' else 'RESISTANCE'}!"
            doneCb()
            
        askChooseTakeCard = =>
            if @cards.filter((c) -> c.player.id isnt recipient.id).length is 0
                @sendAllMsgAndGameLog "TAKE RESPONSIBILITY was not used, since no other player has any cards."
                return doneCb()
                
            playerIds = @getIds @everyoneExcept [recipient]
            @askOne recipient,
                cmd: 'chooseTakeCard'
                msg: 'Take a card from another player.'
                players: playerIds
                (response) =>
                    invalidPlayer = response.choice.player.id not in playerIds
                    invalidCard = not @cards.some (c) -> c.card is response.choice.card and c.player is response.choice.player
                    if invalidPlayer or invalidCard
                        recipient.sendMsg 'That is not a valid card. Try again.'
                        askChooseTakeCard()
                    else
                        @sendAllMsgAndGameLog "#{recipient} used TAKE RESPONSIBILITY to take #{@cardName[response.choice.card]} from #{response.choice.player}.", [recipient]
                        @subCard response.choice.player, response.choice.card 
                        @addCard recipient, response.choice.card
                        doneCb()

        switch card
            when 'Overheard'
                @askOne recipient,
                    cmd: 'choosePlayers'
                    msg: 'Choose who you want to use OVERHEARD CONVERSATION on.'
                    n: 1
                    players: @getIds @neighboringPlayers recipient
                    (response) =>
                        @sendAllMsgAndGameLog "#{recipient} used OVERHEARD CONVERSATION to learn the identity of #{response.choice[0]}.", [recipient]
                        showIdentityTo response.choice[0], recipient
            when 'OpenUp'
                @askOne recipient,
                    cmd: 'choosePlayers'
                    msg: 'Choose who you want to reveal your identity to.'
                    n: 1, 
                    players: @getIds @everyoneExcept [recipient]
                    (response) => 
                        @sendAllMsgAndGameLog "#{recipient} used OPEN UP to show their identity to #{response.choice[0]}."
                        showIdentityTo recipient, response.choice[0]
            when 'EstablishConfidence'
                @sendAllMsgAndGameLog "#{player} used ESTABLISH CONFIDENCE to show their identity to #{recipient}."
                showIdentityTo player, recipient
            when 'TakeResponsibility'
                askChooseTakeCard()
            else 
                @addCard recipient, card
                doneCb()

    askLeaderForTeam: ->
        @activePlayers[@leader].send '-vote'
        @ask 'choosing the mission team ...',
            @makeQuestions [@activePlayers[@leader]],
                cmd: 'choosePlayers'
                msg: "Choose #{@missionTeamSizes[@mission - 1]} players for your mission team.", 
                n: @missionTeamSizes[@mission - 1]
                (response, doneCb) =>
                    context = 
                        msg: "#{response.player} chose mission team: #{@playerNameList(response.choice)}."
                        team: response.choice
                        investigator: null
                        votes: []
                    @votelog.onteam.pop()
                    @votelog.onteam.push (p.id for p in response.choice)
                    @setGuns response.choice.map (i) -> i.id
                    @askLeaderForInvestigator context, (context) =>
                        @gameLog context.msg
                        @sendAll '-vote'
                        opinionMakers = @whoeverHas('OpinionMaker')
                        @askForTeamApproval opinionMakers, context, (context) =>
                            @askForTeamApproval @everyoneExcept(opinionMakers), context, (context) =>
                                @checkTeamApproval(context)
                    doneCb()

    askLeaderForInvestigator: (context, cb) ->
        return cb(context) if @gameType isnt HUNTER_GAMETYPE or @mission is 5
        @activePlayers[@leader].send '-vote'
        @ask 'choosing the mission INVESTIGATOR ...',
            @makeQuestions [@activePlayers[@leader]],
                cmd: 'choosePlayers'
                msg: "Choose an INVESTIGATOR for your mission team.", 
                n: 1
                players: @getIds @everyoneExcept [context.team..., @activePlayers[@leader]]
                (response) =>
                    context.msg += " Investigator: #{response.choice[0].name}."
                    context.investigator = response.choice[0]
                    @votelog.investigator.pop()
                    @votelog.investigator.push(response.choice[0].id)
                    @setInvestigator response.choice[0].id
                    cb(context)
                    
                    
    askForTeamApproval: (players, context, cb) ->
        responses = []
        @ask 'voting on the mission team ...',
            @makeQuestions players,
                cmd: 'choose'
                msg: context.msg
                choices: ['Approve', 'Reject']
                (response, doneCb) => responses.push(response); doneCb()
            =>
                for response in responses
                    @votelog.approve[@votelog.approve.length - 1].push(response.player.id) if response.choice is 'Approve'
                    @votelog.reject[@votelog.reject.length - 1].push(response.player.id) if response.choice is 'Reject'
                    @sendAll '+vote', { player:response.player.id, vote:response.choice }
                context.votes = context.votes.concat(responses)
                cb(context)

    checkTeamApproval: (context) ->
        playerIdsApproving = (vote.player.id for vote in context.votes when vote.choice is 'Approve')
        playerIdsOnTeam = (player.id for player in context.team)
        
        approvalList = (onTeam, approving) =>
            @playerNameList (player for player in @activePlayers when (player.id in playerIdsApproving) is approving and (player.id in playerIdsOnTeam) is onTeam)
            
        @gameLog ''
        @gameLog "Team members approving: #{approvalList(true, true)}"
        @gameLog "Team members rejecting: #{approvalList(true, false)}"
        @gameLog "Non-team members approving: #{approvalList(false, true)}"
        @gameLog "Non-team members rejecting: #{approvalList(false, false)}"
        @gameLog ''
        
        if playerIdsApproving.length > @activePlayers.length / 2
            @sendAllMsgAndGameLog "The mission team is APPROVED."
            @askNoConfidencesToVetoTeam(context)
        else
            #@sendAllMsgAndGameLog "The mission team is REJECTED."
            @round++
            @nextRound()

    askNoConfidencesToVetoTeam: (context) ->
        @ask 'deciding whether to use NO CONFIDENCE ...',
            @makeQuestions @whoeverHas('NoConfidence'),
                cmd: 'choose'
                msg: 'Do you want to use NO CONFIDENCE?'
                choices: ['Yes', 'No']
                (response, doneCb) =>                    
                    return doneCb() if response.choice is 'No'
                    @sendAllMsgAndGameLog "#{response.player} used NO CONFIDENCE."
                    @subCard response.player, 'NoConfidence'
                    @cancelQuestions()
                    @round++
                    @nextRound() 
            => @askInTheSpotlight(context)

    askInTheSpotlight: (context) ->
        @ask 'deciding whether to use IN THE SPOTLIGHT ...',
            @makeQuestions @whoeverHas('InTheSpotlight'),
                cmd: 'choose'
                msg: 'Do you want to use IN THE SPOTLIGHT?'
                choices: ['Yes', 'No']
                (response, doneCb) =>
                    return doneCb() if response.choice is 'No'
                    @askOne response.player,
                        cmd: 'choosePlayers'
                        msg: 'Choose who you want to use IN THE SPOTLIGHT on.'
                        n: 1
                        players: @getIds context.team
                        (response) =>
                            @sendAllMsgAndGameLog "#{response.player} used IN THE SPOTLIGHT on #{response.choice[0]}"
                            @subCard response.player, 'InTheSpotlight'
                            context.spotlight = response.choice[0]
                            doneCb()
            => @askMissionMembersForVote(context)
                
    askMissionMembersForVote: (context) ->
        context.votes = []
        context.spyChiefFail = false
        team = context.team
        spyChiefsOnTeam = []
        if @spyChiefs?
            team = []
            for p in context.team
                if p.id in @spyChiefs
                    spyChiefsOnTeam.push(p)
                else
                    team.push(p)
        questions = @makeQuestions team,
            cmd: 'choose'
            msg: 'Do you want the mission to succeed or fail?'
            choices: ['Succeed', 'Fail'],
            (response, doneCb) => 
                if response.player not in @spies and response.choice is 'Fail'
                    response.player.sendMsg "You are not a spy! Your vote has been changed to 'Succeed', since surely that's what you meant to do."
                    response.choice = 'Succeed'
                context.votes.push(response)
                doneCb()
        if spyChiefsOnTeam.length > 0
            questionsSpyChiefs = @makeQuestions spyChiefsOnTeam,
                cmd: 'choose'
                msg: 'Do you want the mission to succeed or fail?'
                choices: ['Succeed', "#{if @activePlayers.length > 6 then 'Chief Fail' else 'Fail'}"]
                (response, doneCb) => 
                    context.spyChiefFail = true if response.choice isnt 'Succeed'
                    context.votes.push(response)
                    doneCb()
            questions.push(questionsSpyChiefs...) if questionsSpyChiefs.length > 0
        @ask 'voting on the success of the mission ...',
            questions,
            =>
                for response in context.votes when context.spotlight is response.player
                    @sendAllMsgAndGameLog "#{context.spotlight} voted for #{if response.choice is 'Succeed' then 'SUCCESS' else 'FAILURE'}."
                @askKeepingCloseEyes(context)
                
    askKeepingCloseEyes: (context) ->
        validPlayers = context.team[..]
        pickPlayer = null
                            
        pickPlayer = (player, doneCb) =>
            @askOne player,
                cmd: 'choosePlayers'
                msg: 'Choose who you want to use KEEPING A CLOSE EYE ON YOU on.'
                n: 1
                players: @getIds validPlayers
                canCancel: true
                (response) =>
                    return doneCb() if response.choice.length is 0
                    if response.choice[0] not in validPlayers
                        player.sendMsg "Someone has already played KEEPING A CLOSE EYE ON YOU on #{response.choice[0]}."
                        return pickPlayer(player, doneCb)
                    choice = response.choice[0]
                    validPlayers.remove choice
                    @sendAllMsgAndGameLog "#{response.player} played KEEPING A CLOSE EYE ON YOU on #{choice}."
                    @subCard response.player, 'KeepingCloseEye'
                    for vote in context.votes when vote.player is choice
                        @askOne player,
                            cmd: 'choose'
                            msg: "#{choice} voted for #{if vote.choice is 'Succeed' then 'SUCCESS' else 'FAILURE'}."
                            choices: ['OK']
                            (response) => doneCb()
                                
        @ask 'deciding whether to use KEEPING A CLOSE EYE ON YOU ...',
            @makeQuestions @whoeverHas('KeepingCloseEye'),
                cmd: 'choose'
                msg: 'Do you want to use KEEPING A CLOSE EYE ON YOU?'
                choices: ['Yes', 'No']
                (response, doneCb) =>
                    return doneCb() if response.choice is 'No'
                    pickPlayer(response.player, doneCb)
            => @checkMissionSuccess(context)  
                      
    checkMissionSuccess: (context) ->
        nPlayers = [
            "No one",
            "One player",
            "Two players",
            "Three players",
            "Four players"
        ]
        
        chiefFailMsg = [
            " No failure votes were CHIEF fails.",
            " One failure vote was a CHIEF fail.",
            " Two failure votes were CHIEF fails."
        ]
    
        requiredFailures = @failuresRequired[@mission - 1]
        actualFailures = (vote for vote in context.votes when vote.choice isnt 'Succeed').length
        success = actualFailures < requiredFailures
        msg = "The mission #{if success then 'SUCCEEDED' else 'FAILED'}. #{nPlayers[actualFailures]} voted for failure."
        chiefFailures = 0
        if @gameType is HUNTER_GAMETYPE and @activePlayers.length > 6 and actualFailures > 0
            chiefFailures = (vote for vote in context.votes when vote.choice is 'Chief Fail').length
            msg += chiefFailMsg[chiefFailures]
        @sendAllMsgAndGameLog msg
        
        @score.push success
        context.success = success
        @sendAll 'scoreboard', @getScoreboard()
        if @gameType is HUNTER_GAMETYPE and !success and
          (@activePlayers.length < 7 or chiefFailures > 0) and
          (score for score in @score when not score).length < 3
              return @askEarlySpyHunterAccuse(context)
        @checkScoreForWinners(context)
    
    checkScoreForWinners: (context) ->
        if (score for score in @score when not score).length is 3
            return @spiesWin() if @gameType isnt HUNTER_GAMETYPE
            return @askSpyHunterToAcuse(context)
        if (score for score in @score when score).length is 3
            return @askToAssassinateMerlin() if @gameType isnt HUNTER_GAMETYPE
            return @askResHunterToAcuse(context)
        return @askInvestigator(context) if context.investigator?
        @nextMission()

    askToAssassinateMerlin: ->
        return @resistanceWins() if @gameType isnt AVALON_GAMETYPE
        assassin = @findPlayer(@assassin)
        @ask 'choosing a player to assassinate ...',
            @makeQuestions [assassin],
                cmd: 'choosePlayers'
                msg: 'Choose a player to assassinate.'
                n: 1
                players: @getIds @activePlayers.filter((player) => player.id is @oberon or player not in @spies)
                (response, doneCb) =>
                    @sendAllMsgAndGameLog "#{assassin} chose to assassinate #{response.choice[0]}."
                    if response.choice[0].id is @merlin
                        @sendAllMsgAndGameLog "#{assassin} guessed RIGHT. #{response.choice[0]} was Merlin!"
                        @spiesWin()
                    else
                        @sendAllMsgAndGameLog "#{assassin} guessed WRONG. #{@findPlayer(@merlin)} was Merlin, not #{response.choice[0]}!"
                        @resistanceWins()
                    doneCb()
    
    askEarlySpyHunterAccuse: (context) ->
        return @checkScoreForWinners(context) if @earlyAccusationUsed
        spyHunter = @findPlayer(@spyHunter)
        
        target = 'Resistance Chief'
        if @coordinator? then target += ' or Coordinator'
        options = ["Do Not Accuse"]
        options.push("Accuse Now") if context.spyChiefFail
        
        @setStatus "Spy Hunter is choosing whether or not to accuse the #{target} early ..."
        @askOne spyHunter,
            cmd: 'choose'
            msg: "Choose whether or not to accuse the #{target} early."
            choices: options
            (response) =>
                if response.choice is "Accuse Now"
                    @earlyAccusationUsed = true
                    @sendAllMsgAndGameLog 'Spy Hunter chooses to accuse NOW!'
                    @askSpyHunterToAcuse(context)
                else
                    @sendAllMsgAndGameLog 'Spy Hunter chooses not to accuse early.'
                    @checkScoreForWinners(context)
        
    askSpyHunterToAcuse: (context) ->
        spyHunter = @findPlayer(@spyHunter)
        if @spyHunterRevealed is false
            @spyHunterRevealed = true
            @sendAll '-vote'
            @sendPlayers(p) for p in @players
            @sendAll "#{spyHunter} is the Spy Hunter"
            @ineligibleResHunterAccusees.push(spyHunter)
            
        target = 'Resistance Chief'
        if @coordinator? then target += ' or Coordinator'
          
        @ask "choosing a player to accuse as the #{target} ...",
            @makeQuestions [spyHunter],
                cmd: 'choosePlayers'
                msg: "Choose a player to accuse as #{target}."
                n: 1
                players: @getIds @everyoneExcept @ineligibleSpyHunterAccusees
                (response) =>   
                    @sendAllMsgAndGameLog "#{spyHunter} chose to accuse #{response.choice[0]}."
                    if response.choice[0].id in @resistanceChiefs
                        @sendAllMsgAndGameLog "#{spyHunter} guessed RIGHT. #{response.choice[0]} was #{if @resistanceChiefs.length < 2 then 'the' else 'a'} Resistance Chief!"
                        @spiesWin()
                    else if response.choice[0].id is @coordinator
                        @sendAllMsgAndGameLog "#{spyHunter} guessed RIGHT. #{response.choice[0]} was the Coordinator!"
                        @spiesWin()
                    else
                        @sendAllMsgAndGameLog "#{spyHunter} guessed WRONG. #{response.choice[0]} is not a #{target}!"
                        @score.pop()
                        @score.push(true)
                        @sendAll 'scoreboard', @getScoreboard()
                        @sendAllMsgAndGameLog "mission failure has been reversed!"
                        @ineligibleSpyHunterAccusees.push(response.choice[0])
                        @checkScoreForWinners(context)
                            
    askResHunterToAcuse: (context) ->
        resHunter = @findPlayer(@resistanceHunter)
        if @resHunterRevealed is false
            @resHunterRevealed = true
            @sendAll '-vote'
            @sendPlayers(p) for p in @players
            @sendAll "#{resHunter} is the Resistance Hunter"
            @ineligibleSpyHunterAccusees.push(resHunter)
            
        @ask 'choosing a player to accuse as the Spy Chief ...',
            @makeQuestions [resHunter],
                cmd: 'choosePlayers'
                msg: 'Choose a player to accuse as Spy Chief.'
                n: 1
                players: @getIds @everyoneExcept @ineligibleResHunterAccusees
                (response) =>   
                    @sendAllMsgAndGameLog "#{resHunter} chose to accuse #{response.choice[0]}."
                    if response.choice[0].id in @spyChiefs
                        @sendAllMsgAndGameLog "#{resHunter} guessed RIGHT. #{response.choice[0]} was #{if @resistanceChiefs.length < 2 then 'the' else 'a'} Spy Chief!"
                        @resistanceWins()
                    else
                        @sendAllMsgAndGameLog "#{resHunter} guessed WRONG. #{response.choice[0]} is not a Spy Chief!"
                        @score.pop()
                        @score.push(false)
                        @sendAll 'scoreboard', @getScoreboard()
                        @sendAllMsgAndGameLog "mission success has been reversed!"
                        @ineligibleResHunterAccusees.push(response.choice[0])
                        @checkScoreForWinners(context)

    askInvestigator: (context) ->
        if context.success
            investigator = @activePlayers[@leader]
        else
            investigator = context.investigator

        @ask 'choosing a player to investigate ...',
          @makeQuestions [investigator],
              cmd: 'choosePlayers'
              msg: 'Choose a player to investigate.'
              n: 1
              players: @getIds @everyoneExcept([investigator], context.team)
              (response) =>
                  @sendAllMsgAndGameLog "#{investigator} chooses to investigate #{response.choice}."
                  @askToInvestigate(investigator, response.choice[0])
            
    askToInvestigate: (investigator, target) ->
        options =
          if target.id in @spyChiefs
              ['Chief', 'Spy Chief']
          else if target.id in @resistanceChiefs
              if @activePlayers.length > 6
                  ['Resistance Chief']
              else
                  ['Chief']
          else if target.id is @dummyAgent
              ['Chief', 'Not a Chief']
          else
              ['Not a Chief']
        @ask 'choosing a reponse to investigation ...',
            @makeQuestions [target],
                cmd: 'choose'
                msg: 'Choose a response to investigation.'
                choices: options
                (response) =>
                    investigator.sendMsg "#{target} responds '#{response.choice}'"
                    @nextMission()

    nextMission: ->
        @round = 1
        @mission++
        @nextRound()

    spiesWin: ->
        @gameOver(true)

    resistanceWins: ->
        @gameOver(false)
        
    gameOver: (spiesWin) ->
        @gameFinished = true
        @sendAll 'gameover'
        @sendAll '-vote'
        @sendPlayers(p) for p in @players
        @setStatus (if spiesWin then 'The spies win!' else 'The resistance wins!')
        @lobby.onGameUpdate(this)
        @lobby.sendAllChat null, "Game ##{@id} finished: the #{if spiesWin then 'spies' else 'resistance'} won!"
        @db.finishGame @dbId, spiesWin, ->

#-----------------------------------------------------------------------------    
# Helper functions
#-----------------------------------------------------------------------------    
   
    addCard: (player, card) ->
        @sendAll '+card', {player:player.id, card:card}
        @cards.push {player:player, card:card}
        
    subCard: (player, card) ->
        @sendAll '-card', {player:player.id, card:card}
        for c,idx in @cards when c.player is player and c.card is card
            return @cards.splice(idx, 1)
            
    playerNameList: (players) ->
        @nameList (player.name for player in players)
    
    nameList: (names) ->
        ans = ''
        for i in [0 ... names.length]
            ans += ',' if i > 0 and names.length > 2
            ans += ' and' if i > 0 and i is names.length - 1
            ans += ' ' if i > 0
            ans += names[i]
        return ans
    
    sendAll: (msg, action, exempt = []) ->
        exemptIds = exempt.map (p) -> p.id
        player.send(msg, action) for player in @players when player.id not in exemptIds
        
    sendAllMsg: (msg, exempt = []) ->
        @sendAll 'msg', {msg:msg}, exempt
    
    sendAllMsgAndGameLog: (msg, exempt = []) ->
        @sendAllMsg msg, exempt
        @gameLog msg
            
    gameLog: (msg) ->
        log = { mission:@mission, round:@round, msg:msg }
        @sendAll 'gamelog', log 
        @log.push log
    
    neighboringPlayers: (player) ->
        ans = []
        prevPlayer = @activePlayers[@activePlayers.length - 1]
        for curPlayer in @activePlayers
            ans.push(prevPlayer) if curPlayer is player
            ans.push(curPlayer) if prevPlayer is player
            prevPlayer = curPlayer
        return ans
        
    everyoneExcept: (exempt, group = @activePlayers) ->
        return group if exempt.length is 0
        exemptPlayerIds = @getIds exempt
        player for player in group when player.id not in exemptPlayerIds
        
    getIds: (players) ->
        player.id for player in players
    
    whoeverHas: (cardName) ->
        players = (card.player for card in @cards when card.card is cardName)
        player for player in @activePlayers when player in players

    onPlayersChanged: ->
        @lobby.onGameUpdate(this)
        @sendPlayers(p) for p in @players
        @askToStartGame()
            
    sendPlayers: (me) ->
        isSpy = (player) => 
            @spies.some((i) -> i.id is player.id)

        response =
            for them in @activePlayers
                if @gameType is HUNTER_GAMETYPE
                  iKnowTheyAreASpy =
                    me.id is them.id or
                    (isSpy(me) and me.id isnt @deepAgent and
                     not (@pretender? and them.id is @deepAgent)) or
                    (@spyHunterRevealed and them.id is @spyHunter)
                else
                  iKnowTheyAreASpy =
                    me.id is them.id or
                    (isSpy(me) and me.id isnt @oberon and them.id isnt @oberon) or
                    (me.id is @merlin and them.id isnt @mordred)
                   
                {
                    isSpy: isSpy(them) and (@gameFinished or iKnowTheyAreASpy)
                    id: them.id
                    name: them.name
                    role:
                        if @gameFinished or (me.id is them.id) or
                          (@resHunterRevealed and them.id is @resistanceHunter) or
                          (@spyHunterRevealed and them.id is @spyHunter)
                            them.role
                        else if me.id is @percival and (them.id is @merlin or them.id is @morgana)
                            if @morgana? then "Merlin?" else "Merlin"
                        else if @resistanceChiefs? and me.id in @resistanceChiefs and
                          (them.id in @resistanceChiefs or them.id is @coordinator)
                            them.role
                        else if isSpy(me) and me.id isnt @deepAgent
                            if @spyChiefs? and them.id in @spyChiefs
                                them.role
                            else if them.id is @deepAgent or them.id is @pretender
                                if @pretender? then "Deep Agent?" else "Deep Agent"
                            else
                                undefined
                        else
                            undefined
                }
      
        me.send 'players', { players:response, amSpy:isSpy(me) }
                
    askOne: (player, cmd, cb) ->
        question = JSON.parse(JSON.stringify(cmd))
        question.choiceId = @nextId++
        @questions.push { player:player, question:question, cb:cb }
        player.send question.cmd, question
        return question.choiceId

    updateAskOne: (questionId, player, cmd, cb) ->
        question = JSON.parse(JSON.stringify(cmd))
        question.choiceId = questionId
        player.send question.cmd, question

    ask: (status, questions, cb = ->) ->
        return cb() if questions.length is 0
        players = questions.map (q) -> q.player

        showStatus = =>
            uniquePlayers = (p for p in @activePlayers when p in players)
            isAre = (if uniquePlayers.length is 1 then 'is' else 'are')
            @setStatus "#{@nameList(uniquePlayers)} #{isAre} #{status}"

        showStatus()
        for q in questions
            do (q) =>
                @askOne q.player, q.question, (response) => q.cb(response, =>
                    players.remove q.player
                    return cb() if players.length is 0
                    showStatus())
        
    makeQuestions: (players, question, cb) ->
        for p in players
            player: p
            question: question
            cb: cb
    
    findQuestion: (player, request) ->
        for q in @questions when q.question.choiceId is request.choiceId
            throw "Incorrect cmd" if q.question.cmd isnt request.cmd
            throw "Incorrect responding player" if player.id isnt q.player.id
            return q
        return null

    findPlayer: (playerId) ->
        for p in @activePlayers when p.id is playerId
            return p
        throw "Invalid player"
        
    answerQuestion: (question, choice) ->
        question.choice = choice
        @questions.remove question
        question.cb(question)
        
    cancelQuestions: (who = @activePlayers) ->
        playerIds = @getIds(who)
        for q in @questions when q.player.id in playerIds
            q.player.send 'cancelChoose', { choiceId:q.question.choiceId }
        @questions = (q for q in @questions when q.player.id not in playerIds)
            
    setStatus: (msg) ->
        @status = msg
        p.send('status', {msg:msg}) for p in @players  

    getInitialState: ->
        state = 
            spies: []
            leader: Math.floor(Math.random() * @activePlayers.length)
            
        resistanceRoles = ['Resistance', 'Merlin', 'Percival']
        resistanceRoles = ['Resistance', 'Resistance Chief', 'Resistance Hunter',
          'Dummy Agent','Coordinator','Pretender'] if @gameType is HUNTER_GAMETYPE
        spiesRequired = Math.floor((@activePlayers.length - 1) / 3) + 1

        roles = []
        if @gameType is AVALON_GAMETYPE then roles = @getAvalonRoles()
        if @gameType is HUNTER_GAMETYPE then roles = @getHunterRolesForGame()
        for i in [roles.filter((i) -> i not in resistanceRoles).length ... spiesRequired]
            roles.push('Spy')
        for i in [roles.length ... @activePlayers.length]
            roles.push('Resistance')
        roles.shuffle()
        
        if @gameType is HUNTER_GAMETYPE
          state.resistanceChiefs = []
          state.spyChiefs = []
          state.earlyAccusationUsed = false
          
        for role, i in roles
            @activePlayers[i].role = role
            state.spies.push(@activePlayers[i]) if role not in resistanceRoles
            if @gameType is AVALON_GAMETYPE
              state.merlin = @activePlayers[i].id if role is 'Merlin'
              state.assassin = @activePlayers[i].id if role in ['Assassin', 'Mordred/Assassin']
              state.percival = @activePlayers[i].id if role is 'Percival'
              state.morgana = @activePlayers[i].id if role is 'Morgana'
              state.oberon = @activePlayers[i].id if role is 'Oberon'
              state.mordred = @activePlayers[i].id if role in ['Mordred', 'Mordred/Assassin']
            if @gameType is HUNTER_GAMETYPE
              state.resistanceChiefs.push(@activePlayers[i].id) if role is 'Resistance Chief'
              state.resistanceHunter = @activePlayers[i].id if role is 'Resistance Hunter'
              state.spyChiefs.push(@activePlayers[i].id) if role is 'Spy Chief'
              state.spyHunter = @activePlayers[i].id if role is 'Spy Hunter'
              state.dummyAgent = @activePlayers[i].id if role is 'Dummy Agent'
              state.coordinator = @activePlayers[i].id if role is 'Coordinator'
              state.deepAgent = @activePlayers[i].id if role is 'Deep Agent'
              state.pretender = @activePlayers[i].id if role is 'Pretender'

        if @avalonOptions.useLadyOfTheLake
            state.ladyOfTheLake = @activePlayers[state.leader].id

        if @hunterOptions.useInquisitor
            state.inquisitor = @activePlayers[state.leader].id

        if @gameType is ORIGINAL_GAMETYPE
            deck = [
                "KeepingCloseEye"
                "KeepingCloseEye"
                "NoConfidence" 
                "OpinionMaker"
                "TakeResponsibility"
                "StrongLeader"
                "StrongLeader"
            ]
            
            if @activePlayers.length > 6
                deck = deck.concat [
                    "NoConfidence"
                    "NoConfidence"
                    "OpenUp"
                    "OpinionMaker"
                    "Overheard"
                    "Overheard"
                    "InTheSpotlight"
                    "EstablishConfidence"
                ]
                
            deck.shuffle()
            state.deck = deck
        
        return state
        
    getScoreboard: ->
        return {
            mission: @mission
            round: @round
            score: @score[..]
            missionTeamSizes: @missionTeamSizes
            failuresRequired: @failuresRequired
        }

    setGuns: (guns) ->
        @guns = guns
        @sendAll 'guns', { players: guns }
    
    setInvestigator: (investigator) ->
        @investigator = investigator
        @sendAll 'investigator', { player: investigator }
    
    getAvalonOptions: ->
        ans = ['Options']
        
        addRemove = (flag, role) ->
            ans.push((if flag then 'Remove ' else 'Add ') + role)
        
        if @avalonOptions.usePercival
            ans.push(if @avalonOptions.useMorgana then 'Remove Percival and Morgana' else 'Remove Percival')
        else
            ans.push('Add Percival')

        if @avalonOptions.useMorgana
            ans.push('Remove Morgana')
        else
            ans.push(if @avalonOptions.usePercival then 'Add Morgana' else 'Add Percival and Morgana')
            
        addRemove @avalonOptions.useOberon, 'Oberon'
        addRemove @avalonOptions.useMordred, 'Mordred'

        if @avalonOptions.useMordred
            ans.push(if @avalonOptions.combineMordredAndAssassin then 'Separate Mordred and Assassin' else 'Combine Mordred and Assassin')
        
        addRemove @avalonOptions.useLadyOfTheLake, 'Lady of the Lake'
        return ans

    setAvalonOption: (choice) ->
        switch choice
            when 'Add Percival'
                @avalonOptions.usePercival = true
            when 'Add Morgana', 'Add Percival and Morgana'
                @avalonOptions.usePercival = true
                @avalonOptions.useMorgana = true
            when 'Add Oberon'
                @avalonOptions.useOberon = true
            when 'Add Mordred'
                @avalonOptions.useMordred = true
            when 'Add Lady of the Lake'
                @avalonOptions.useLadyOfTheLake = true
            when 'Remove Percival', 'Remove Percival and Morgana'
                @avalonOptions.usePercival = false
                @avalonOptions.useMorgana = false
            when 'Remove Morgana'
                @avalonOptions.useMorgana = false
            when 'Remove Oberon'
                @avalonOptions.useOberon = false
            when 'Remove Mordred'
                @avalonOptions.useMordred = false
            when 'Remove Lady of the Lake'
                @avalonOptions.useLadyOfTheLake = false
            when 'Combine Mordred and Assassin'
                @avalonOptions.combineMordredAndAssassin = true
            when 'Separate Mordred and Assassin'
                @avalonOptions.combineMordredAndAssassin = false

    getAvalonRoles: ->
        roles = ['Merlin']
        roles.push('Percival') if @avalonOptions.usePercival
        roles.push('Morgana') if @avalonOptions.useMorgana
        roles.push('Oberon') if @avalonOptions.useOberon
        if not @avalonOptions.useMordred
            roles.push('Assassin')
        else if @avalonOptions.combineMordredAndAssassin
            roles.push('Mordred/Assassin')
        else
            roles.push('Mordred')
            roles.push('Assassin')
        return roles

    getAvalonRolesString: ->
        return '' if @gameType isnt AVALON_GAMETYPE
        roles = @getAvalonRoles()
        roles.push('Lady of the Lake') if @avalonOptions.useLadyOfTheLake
        return @nameList(roles)
        
    getRequiredPlayers: ->
        if @gameType is AVALON_GAMETYPE
          badGuys = @getAvalonRoles().length - (if @avalonOptions.usePercival then 2 else 1)
          return [5, 5, 5, 7, 10][badGuys]
        if @gameType is HUNTER_GAMETYPE
          resRoles = 0
          ++resRoles if @hunterOptions.useDummyAgent
          ++resRoles if @hunterOptions.useCoordinator
          ++resRoles if @hunterOptions.usePretender
          if resRoles is 3 then return 9
          if @hunterOptions.useDeepAgent then return 7
          if resRoles is 2 then return 6
        return 5
        
    getHunterOptions: ->
        ans = ['Options']
        
        addRemove = (flag, role) ->
            ans.push((if flag then 'Remove ' else 'Add ') + role)
            
        addRemove @hunterOptions.useDummyAgent, 'Dummy Agent'
        addRemove @hunterOptions.useCoordinator, 'Coordinator'
        
        if @hunterOptions.useDeepAgent
            ans.push(if @hunterOptions.usePretender then 'Remove Deep Agent and Pretender' else 'Remove Deep Agent')
        else
            ans.push('Add Deep Agent')

        if @hunterOptions.usePretender
            ans.push('Remove Pretender')
        else
            ans.push(if @hunterOptions.useDeepAgent then 'Add Pretender' else 'Add Deep Agent and Pretender')

        addRemove @hunterOptions.useInquisitor, 'Inquisitor'
        return ans

    setHunterOption: (choice) ->
        switch choice
            when 'Add Dummy Agent'
                @hunterOptions.useDummyAgent = true
            when 'Add Coordinator'
                @hunterOptions.useCoordinator = true
            when 'Add Deep Agent'
                @hunterOptions.useDeepAgent = true
            when 'Add Pretender', 'Add Deep Agent and Pretender'
                @hunterOptions.useDeepAgent = true
                @hunterOptions.usePretender = true
            when 'Add Inquisitor'
                @hunterOptions.useInquisitor = true
            when 'Remove Dummy Agent'
                @hunterOptions.useDummyAgent = false
            when 'Remove Coordinator'
                @hunterOptions.useCoordinator = false
            when 'Remove Deep Agent', 'Remove Deep Agent and Pretender'
                @hunterOptions.useDeepAgent = false
                @hunterOptions.usePretender = false
            when 'Remove Pretender'
                @hunterOptions.usePretender = false
            when 'Remove Inquisitor'
                @hunterOptions.useInquisitor = false
                
    getHunterRoles: ->
        roles = []
        if @activePlayers.length < 8
          roles.push('Resistance Chief')
        else
          roles.push('2x Resistance Chief')
        roles.push('Resistance Hunter')
        if @activePlayers.length < 10
          roles.push('Spy Chief')
        else
          roles.push('2x Spy Chief')
        roles.push('Spy Hunter')
        roles.push('Dummy Agent') if @hunterOptions.useDummyAgent
        roles.push('Coordinator') if @hunterOptions.useCoordinator
        roles.push('Deep Agent') if @hunterOptions.useDeepAgent
        roles.push('Pretender') if @hunterOptions.usePretender
        return roles
    
    getHunterRolesForGame: ->
        roles = @getHunterRoles()
        if roles.remove('2x Resistance Chief') isnt undefined
          roles.push('Resistance Chief')
          roles.push('Resistance Chief')
        if roles.remove('2x Spy Chief') isnt undefined
          roles.push('Spy Chief')
          roles.push('Spy Chief')
        return roles

    getHunterRolesString: ->
        return '' if @gameType isnt HUNTER_GAMETYPE
        roles = @getHunterRoles()
        roles.push('Inquisitor') if @hunterOptions.useInquisitor
        return @nameList(roles)
