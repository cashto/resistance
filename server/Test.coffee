class TestPlayer extends Player
    constructor: ->
        super
        @choiceMap = []
    send: (cmd, params = {}) ->
        @choiceMap.push(params.choiceId) if params.choiceId?
        super

class TestGame extends Game
    constructor: ->
        super
    getInitialState: ->
        return {
            spies: [@activePlayers[1], @activePlayers[2], @activePlayers[5]]
            deck: [
                "StrongLeader",
                "Overheard", 
                "TakeResponsibility", 
                "InTheSpotlight",
                "NoConfidence",
                "OpinionMaker", 
                "KeepingCloseEye",
                "EstablishConfidence", 
                "Overheard",
                "OpenUp",
                "NoConfidence",
                "StrongLeader",
                "NoConfidence",
                "KeepingCloseEye",
                "OpinionMaker"]
            leader: 6
        }
    
testGame = ->
    fakeDb = 
        createGame: (startData, players, cb) -> cb(null, 6324)
        updateGame: ->
        finishGame: ->

    fakeLobby =
        onGameEnd: ->
        onPlayerJoin: ->
        onPlayerLeave: ->

    player1 = new TestPlayer 'Alpha', 101, '', fakeLobby
    player2 = new TestPlayer 'Bravo', 102, '', fakeLobby
    player3 = new TestPlayer 'Charlie', 103, '', fakeLobby
    player4 = new TestPlayer 'Delta', 104, '', fakeLobby
    player5 = new TestPlayer 'Echo', 105, '', fakeLobby
    player6 = new TestPlayer 'Foxtrot', 106, '', fakeLobby
    player7 = new TestPlayer 'Golf', 107, '', fakeLobby

    playerObs = new TestPlayer 'Zulu', 200, '', fakeLobby

    game = new TestGame 42, fakeLobby, fakeDb
    sendGame = (player, request) ->
        request.choiceId = player.choiceMap[player.choiceMap.length + request.choiceId - 1] if request.choiceId?
        game.onRequest player, request
        
    player1.setRoom game
    player2.setRoom game
    player3.setRoom game
    player4.setRoom game
    player5.setRoom game
    player6.setRoom game
    player7.setRoom game
    playerObs.setRoom game
    
    sendGame player2, { cmd:'choose', choiceId:0, choice:'Join' }
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Join' }
    sendGame player4, { cmd:'choose', choiceId:0, choice:'Join' }
    sendGame player5, { cmd:'choose', choiceId:0, choice:'Join' }
    sendGame player6, { cmd:'choose', choiceId:0, choice:'Join' }
    sendGame player7, { cmd:'choose', choiceId:0, choice:'Join' }
    
    sendGame player1, { cmd:'choose', choiceId:0, choice:'OK' }
    
    # ROUND 1
    # Distribute cards
    sendGame player1, { cmd:'chooseGiveCard', choiceId:0, choice:103 } # OVERHEARD
    sendGame player1, { cmd:'chooseGiveCard', choiceId:-1, choice:105 } # STRONG LEADER
    
    # Use OVERHEARD CONVERSATION
    sendGame player3, { cmd:'choosePlayers', choiceId:0, choice:[102] }
    
    # Pick mission team
    sendGame player1, { cmd:'choosePlayers', choiceId:0, choice:[101, 104] }
    
    # Vote for the mission team
    sendGame player3, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Reject' }
    
    # Vote on the mission
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Succeed' }
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Succeed' }
    
    # ROUND 2
    # Use strong leader
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Yes' }
    
    # Distribute cards
    sendGame player5, { cmd:'chooseGiveCard', choiceId:0, choice:102 }  # IN THE SPOTLIGHT
    sendGame player5, { cmd:'chooseGiveCard', choiceId:-1, choice:107 } # TAKE RESPONSIBILITY

    # Use TAKE RESPONSIBILITY
    sendGame player7, { cmd:'chooseTakeCard', choiceId:0, choice:{player:102, card:'InTheSpotlight'} }
    
    # Choose a team
    sendGame player5, { cmd: 'choosePlayers', choiceId:0, choice:[101, 105, 106] }

    # Vote for the mission team
    sendGame player3, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Reject' }
    
    # Choose a team
    sendGame player6, { cmd:'choosePlayers', choiceId:0, choice: [101, 102, 106] }
    
    # Vote for the mission team
    sendGame player3, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Approve' }
    
    # Use IN THE SPOTLIGHT
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Yes' }
    sendGame player7, { cmd:'choosePlayers', choiceId:0, choice:[106] }
    
    # Vote on the mission
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Succeed' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Succeed' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Fail' }
    
    # ROUND 3
    # Distribute cards
    sendGame player7, { cmd:'chooseGiveCard', choiceId:0, choice:103 } # OPINION MAKER
    sendGame player7, { cmd:'chooseGiveCard', choiceId:-1, choice:103 } # NO CONFIDENCE    

    # Choose a team
    sendGame player7, { cmd:'choosePlayers', choiceId:0, choice:[103, 104, 107] } 
    
    # Opinion maker vote for mission team.
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Reject' }

    # Vote for mission team.
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Approve' }
    
    # Use NO CONFIDENCE
    sendGame player3, { cmd:'choose', choiceId:0, choice: 'Yes' }
    
    # Choose a team
    sendGame player1, { cmd:'choosePlayers', choiceId:0, choice: [101, 104, 105] }

    # Opinion maker vote for mission team.
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Approve' }

    # Vote for mission team.
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Approve' }

    # Vote on the mission
    sendGame player4, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player5, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player1, { cmd:'choose', choiceId:0, choice:'Succeed' }
    
    # ROUND 4
    sendGame player2, { cmd:'chooseGiveCard', choiceId:-1, choice:103 } # KEEPING A CLOSE EYE ON YOU
    sendGame player2, { cmd:'choosePlayers', choiceId:0, choice:[106] } # ESTABLISH CONFIDENCE
    
    # Choose a team
    sendGame player2, { cmd:'choosePlayers', choiceId:0, choice:[101, 102, 105, 106] }
    
    # Opinion maker vote for mission team. 
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Approve' }

    # Vote for mission team.
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Approve' }
    
    # Vote on the mission
    sendGame player5, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player2, { cmd:'choose', choiceId:0, choice:'Fail' }
    sendGame player1, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player6, { cmd:'choose', choiceId:0, choice:'Fail' }
    
    # Use KEEPING A CLOSE EYE ON YOU
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Yes' }
    sendGame player3, { cmd:'choosePlayers', choiceId:0, choice:[101] }
    
    # ROUND 5
    # Distribute cards (and use OVERHEARD)
    sendGame player3, { cmd:'chooseGiveCard', choiceId:-1, choice:107 } # OVERHEARD
    sendGame player7, { cmd:'choosePlayers', choiceId:0, choice:[101] } 
    sendGame player3, { cmd:'chooseGiveCard', choiceId:0, choice:104 } # OPEN UP
    
    # Use OPEN UP
    sendGame player4, { cmd:'choosePlayers', choiceId:0, choice:[106] }
    
    # Player 1 goes to lobby!
    sendGame player1, { cmd:'leave' }
    
    # Choose a team
    sendGame player3, { cmd:'choosePlayers', choiceId:0, choice:[101, 103, 104, 107] }
    
    # Opinion maker vote for mission team. 
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Approve' }

    # Vote for mission team. (player1 comes back)
    sendGame player4, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player6, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player2, { cmd:'choose', choiceId:0, choice: 'Approve' }
    player1.setRoom game
    sendGame player1, { cmd:'choose', choiceId:0, choice: 'Approve' }
    sendGame player7, { cmd:'choose', choiceId:0, choice: 'Reject' }
    sendGame player5, { cmd:'choose', choiceId:0, choice: 'Approve' }

    # Vote on the mission
    sendGame player3, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player7, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player4, { cmd:'choose', choiceId:0, choice:'Succeed' }
    sendGame player1, { cmd:'choose', choiceId:0, choice:'Succeed' }

    for msg in player2.pendingMessages
        console.log JSON.stringify msg

testGame()
console.log 'Great success!'