var debugLog = [];

var cardNames = {
    NoConfidence: 'No Confidence',
    KeepingCloseEye: 'Keeping a Close Eye on You',
    StrongLeader: 'Strong Leader',
    InTheSpotlight: 'In the Spotlight',

    OpenUp: 'Open Up',
    EstablishConfidence: 'Establish Confidence',
    Overheard: 'Overheard',
    TakeResponsibility: 'Take Responsibility',
    OpinionMaker: 'Opinion Maker',
    LadyOfTheLake: 'Lady of the Lake'
};

var g;
var resetGlobals = function() {
     g = {
        lobbyPlayers: {},
        status: '',
        msgs: [],
        choices: [],
        choiceIdx: 0,
        players: [],
        cards: [],
        votes: {},
        gamelogs: [],
        gamelogIdx: 0,
        highlights: {},
        guns: [],
        games: [],
        votelog: { rounds:[0,0,0,0,0], approve:[], reject:[], onteam:[], leader:[] },
        scoreboard: {}
    };
}
resetGlobals();

var leaderOffsetX = 55;
var leaderOffsetY = 60;
var gunsOffsetX = 5;
var gunsOffsetY = 40;

// User input handlers
var onJoinGame = function(id) {
    sendAjax({ cmd:'join', id:id });
}

var onCreateGame = function(type) {
    return function() {
        sendAjax({ cmd:'join', gameType:type });
    }
}

var onLeaveGame = function() {
    sendAjax({ cmd:'leave' });
}

var onEnter = function(cmd) {
    return function(event) {
        if (event.keyCode === 13) {
            if (event.target.value != '') {
                sendAjax({ cmd:cmd, msg:event.target.value });
                event.target.value = '';
            }
            event.preventDefault();
        }
        
    };
}

var onDismissMsg = function() {
    if (g.ignoreClicks) {
        return;
    }
    g.msgs.shift();
    drawMsgArea();
}

var onDismissChoose = function(response) {
    var question = g.choices[g.choiceIdx];
    var isCancelled = question.canCancel && response.length === 0;
    if (!isCancelled &&
        question.cmd === 'choosePlayers' &&
        response.length !== question.n) {
        return;
    }
    sendAjax({ cmd:question.cmd, choiceId:question.choiceId, choice:response });
    g.choices.splice(g.choiceIdx, 1);
    g.choiceIdx = g.choiceIdx % g.choices.length;
    if (g.choices.length === 0) {
        g.choiceIdx = 0;
    }
    g.highlights = {};
    drawMsgArea();
    drawPlayers();
}

var onNextChoice = function() {
    g.choiceIdx = (g.choiceIdx + 1) % g.choices.length;
    g.highlights = {};
    drawMsgArea();
    drawPlayers();
}

var onClickUserTile = function(id) {
    return function(event) {
        if (g.choices.length > 0 &&
            g.choices[g.choiceIdx].cmd === 'choosePlayers')
        {
            if (g.choices[g.choiceIdx].players == null ||
                g.choices[g.choiceIdx].players.indexOf(id) >= 0) {
                g.highlights[id] = !g.highlights[id];
                drawPlayers();
                drawMsgArea();
            }
        }
    }
}

var onNextGameLog = function() {
    g.gamelogIdx = Math.min(Math.max(g.gamelogs.length - 1, 0), g.gamelogIdx + 1);
    drawGameLog();
}

var onPrevGameLog = function() {
    g.gamelogIdx = Math.max(0, g.gamelogIdx - 1);
    drawGameLog();
}

// Server message handlers
var onJoin = function() {
    $("#game-container").removeClass("hidden");
    $("#lobby-container").addClass("hidden");

    resetGlobals();
    drawPlayers();
    drawMsgArea();
    drawGameLog();
    drawGuns();
    $('#scoreboard').html('');
    $('#chat-text').html('<div class=current></div>');
}

var onLeave = function() {
    $("#game-container").addClass('hidden');
    $("#lobby-container").removeClass('hidden');
    drawGames();
}

var onChat = function(data) {
    updateChat($('#chat-text'), data);
    highlightTab('#chat-nav-tab');
}

var onAllChat = function(data) {
    updateChat($('#lobby-chat-text'), data);
    updateChat($('#all-chat-text'), data);
    if (!$('#game-container').hasClass('hidden')) {
        highlightTab('#all-chat-nav-tab');
    }
}

var onStatus = function(data) {
    g.status = data.msg;
    
    // Don't refresh the msg area if choices are up ... we may 
    // accidentally close a dropdown if we do.
    if (g.choices.length === 0) {
        drawMsgArea();
    }
}

var onMsg = function(data) {
    if (g.msgs.length === 0) {
        g.ignoreClicks = true;
        setTimeout(function() { g.ignoreClicks = false; }, 300);
    }
    g.msgs.push(data.msg);
    drawMsgArea();
}

var onChoose = function(data) {
    g.choices.push(data);
    drawMsgArea();
    if (data.cmd === 'chooseTakeCard') {
        drawPlayers();
    }
}

var onCancelChoose = function(data) {
    for (var idx = 0; idx < g.choices.length; ++idx) {
        if (g.choices[idx].choiceId === data.choiceId) {
            if (idx == g.choiceIdx) {
                g.highlights = {};
                if (g.choiceIdx > 0) {
                    --g.choiceIdx;
                }
            }
            g.choices.splice(idx, 1);
            drawMsgArea();
            return;
        }
    }
}

var onLeader = function(data) {
    g.leader = data.player;
    var p = $('#player' + g.leader).position();
    $('#leader-star').animate({
        left: p.left + leaderOffsetX,
        top: p.top + leaderOffsetY,
    }, null, null, drawPlayers);
    
    g.votelog.leader[g.votelog.leader.length - 1] = g.leader;
    drawVoteLog();
}

var onPlayers = function(data) {
    g.players = data.players;
    for (var i = 0; i < g.players.length; ++i) {
        g.players[i].name = xmlEscape(g.players[i].name);
    }

    if (!g.players.some(function(p) { return p.id === g.leader })) {
        delete g.leader;
    }
    
    if (g.players.length > 0) {
        g.leader = g.leader || g.players[0].id;
    }
        
    drawPlayers();
    drawVoteLog();
}

var onScoreboard = function(data) {
    g.scoreboard = data;
    
    var html = "";
    for (var i = 0; i < data.missionTeamSizes.length; ++i) {
        var color = 
            data.score[i] === true ? " btn-primary" :
            data.score[i] === false ? " btn-danger" : "";
        html +=
            "<button class='btn disabled" + color + "' style='width:40px'>" +
                data.missionTeamSizes[i] +
                (data.failuresRequired[i] > 1 ? "*" : "") +
            "</button> ";
    }
    html += "<p></p>Failed votes:" + (data.round - 1);
    $('#scoreboard').html(html);
    
    if (data.round <= 5 && g.votelog.rounds[data.mission - 1] !== data.round) {
        g.votelog.rounds[data.mission - 1] = data.round;
        g.votelog.leader.push(g.leader);
        g.votelog.approve.push([]);
        g.votelog.reject.push([]);
        g.votelog.onteam.push([]);
        drawVoteLog();
    }
}

var onAddCard = function(data) {
    g.cards.push(data);
    drawPlayers();
}

var onSubCard = function(data) {
    for (var i = 0; i < g.cards.length; ++i) {
        if (g.cards[i].player === data.player &&
            g.cards[i].card   === data.card) {
            g.cards.splice(i, 1);
            return drawPlayers();
        }
    }
}

var onAddVote = function(data) {
    g.votes[data.player] = data.vote;
    drawPlayers();
    
    if (data.vote === 'Approve') {
        g.votelog.approve[g.votelog.approve.length - 1].push(data.player);
    } else {
        g.votelog.reject[g.votelog.reject.length - 1].push(data.player);
    }
    drawVoteLog();
}

var onSubVote = function(data) {
    g.votes = {};
    drawPlayers();
}

var onGameLog = function(data) {
    var page = 'Mission ' + data.mission + ', round ' + data.round;
    if (g.gamelogs.length === 0 ||
        g.gamelogs[g.gamelogs.length - 1].page !== page) {
        g.gamelogs.push({ page:page, text:'' });
    }
    g.gamelogs[g.gamelogs.length - 1].text += '<br>' + xmlEscape(data.msg);
    drawGameLog();
}

var onGuns = function(data) {
    g.guns = data.players;
    drawGuns();
    for (var i = 0; i < g.guns.length; ++i) {
        var pos = $('#player' + g.guns[i]).position();
        $('#gun' + i).animate({ top: pos.top + gunsOffsetY, left: pos.left + gunsOffsetX });
    }
    
    if (g.guns.length > 0) {
        g.votelog.onteam[g.votelog.onteam.length - 1] = data.players;
        drawVoteLog();
    }
}

var onAddGame = function(data) {
    for (var i = 0; i < g.games.length; ++i) {
        if (g.games[i].id === data.id) {
            g.games[i].msg = data.msg;
            drawGames();
            return;
        }
    }
    
    g.games.push(data);
    drawGames();
}

var onSubGame = function(data) {
    g.games = g.games.filter(function(i) { return i.id !== data.id });
    drawGames();
}

var onVoteLog = function(data) {
    g.votelog = data;
    drawVoteLog();
}

var onAddPlayer = function(data) {
    g.lobbyPlayers[data.id] = data.name;
    drawLobbyPlayers();
}

var onSubPlayer = function(data) {
    delete g.lobbyPlayers[data.id];
    drawLobbyPlayers();
}

var handlers = {
    'join': onJoin,
    'leave': onLeave,
    'chat': onChat,
    'allChat': onAllChat,
    'status': onStatus,
    'msg': onMsg,
    'choose': onChoose,
    'choosePlayers': onChoose,
    'chooseTakeCard': onChoose,
    'cancelChoose': onCancelChoose,    
    'leader': onLeader,
    'players': onPlayers,
    'scoreboard': onScoreboard,
    '+card': onAddCard,
    '-card': onSubCard,
    '+vote': onAddVote,
    '-vote': onSubVote,
    'gamelog': onGameLog,
    'guns': onGuns,
    '+game': onAddGame,
    '-game': onSubGame,
    'votelog': onVoteLog,
    '+player': onAddPlayer,
    '-player': onSubPlayer,
};

var drawGames = function() {
    var html = '';
    var gameTypeNames = {
        1: 'Original',
        2: 'Avalon',
        3: 'Basic'
    };
    for (var i = 0; i < g.games.length; ++i) {
        html += 
            '<tr onclick="onJoinGame(' + g.games[i].id + ')">' +
                '<td>' + g.games[i].id + '</td>' +
                '<td>' + g.games[i].msg + '</td>' +
                '<td>' + gameTypeNames[g.games[i].gameType] + '</td>' +
            '</tr>';
    }
    $('#games-list').html(html);
}

var drawLobbyPlayers = function() {
    var html = '';
    var names = [];
    for (var id in g.lobbyPlayers) {
        names.push(g.lobbyPlayers[id]);
    }
    
    names = names.sort();
    for (var idx = 0; idx < names.length; ++idx) {
        html += '<tr><td>' + xmlEscape(names[idx]) + '</td></tr>';
    }
    
    $('#player-list').html(html);
}

var drawGuns = function() {
    var html = '';
    var width = $('#game-field').width();
    for (var i = 0; i < g.guns.length; ++i) {
        html += '<img id=gun' + i + ' src="gun.png" style="position:absolute; top:' + 200 + 'px; left:' + (width / 2 - 50) + 'px">';
    }
    
    $('#guns-field').html(html);
    
    for (var i = 0; i < g.guns.length; ++i) {
        $('#gun' + i).click(onClickUserTile(g.guns[i]));
    }
}

var drawGameLog = function() {
    if (g.gamelogIdx < g.gamelogs.length) {
        $('#gamelog-page').html(g.gamelogs[g.gamelogIdx].page);
        $('#gamelog-text').html(g.gamelogs[g.gamelogIdx].text);
    } else {
        $('#gamelog-page').html('');
        $('#gamelog-text').html('');
    }
}

var drawMsgArea = function() {
    if (g.msgs.length > 0) {
        $('#msg-text').html(xmlEscape(g.msgs[0]));
        $('#msg-buttons').html(
            "<button class='btn btn-primary' onclick='onDismissMsg()'>OK</button>");
    } else if (g.choices.length > 0) {
        var choice = g.choices[g.choiceIdx]; 
        var html = '';
        
        if (choice.cmd === 'choosePlayers') {
            var enabled = getHighlights().length === choice.n ? '' : ' disabled';
            html = "<button class='btn btn-success" + enabled + "' onclick='onDismissChoose(getHighlights())'>OK</button> ";
            if (choice.canCancel) {
                html += "<button class='btn btn-danger' onclick='onDismissChoose([])'>Cancel</a> ";
            }
        } else if (choice.cmd === 'choose') {
            html = generateButton('btn-success', choice.choices[0]);
            if (choice.choices.length > 1) {
                html += generateButton('btn-danger', choice.choices[1]);
            }
            if (choice.choices.length > 2) {
                html = generateButton('', choice.choices[2]) + html;
            }
        }
        
        if (g.choices.length > 1) {
            html += "<button class='btn' onclick='onNextChoice()'><i class='icon-chevron-right'></i></button>";
        }
        
        $('#msg-text').html(xmlEscape(choice.msg));
        $('#msg-buttons').html(html);
    }
    else
    {
        $('#msg-text').html(xmlEscape(g.status));
        $('#msg-buttons').html("<button class='btn invisible'>.</button>");
    }
}

var generateButton = function(btnClass, choice) {
    if (typeof(choice) === 'string') {
        return "<button class='btn " + btnClass + "' onclick='onDismissChoose(\"" + choice + "\")'>" + choice + "</button> ";
    } else {
        return "<div class='btn-group'>" +
            "<a class='btn dropdown-toggle' data-toggle='dropdown' href='#'>" + choice[0] + " <span class='caret'></span></a>" +
            "<ul class='dropdown-menu'>" +
            choice.slice(1).map(function (i) { 
                return  "<li><a onclick='onDismissChoose(\"" + i + "\")'>" + i + "</a></li>";
            }).join('') +
            "</ul></div> ";
    }
}

var drawVoteLog = function() {
    var html = '<table><tr><td>&nbsp;</td>';
    for (var i = 0; i < g.votelog.rounds.length; ++i) {
        if (g.votelog.rounds[i] !== 0) {
            html += '<td style="width: 11em" colspan=' + g.votelog.rounds[i] + '>Mission ' + (i + 1) + '</td>';
        }
    }
    html + '</tr>';
    
    for (var i = 0; i < g.players.length; ++i) {
        var id = g.players[i].id;
        html += '<tr><td>' + g.players[i].name + '</td>';
        for (var j = 0; j < g.votelog.leader.length; ++j) {
            var leader = (g.votelog.leader[j] === id) ? 'leader' : '';
            var approve = (g.votelog.approve[j].indexOf(id) >= 0) ? 'approve' : '';
            var reject = (g.votelog.reject[j].indexOf(id) >= 0) ? 'reject' : '';
            var onteam = (g.votelog.onteam[j].indexOf(id) >= 0) ? '<i class="icon-ok"></i>' : '';
            html += '<td class="' + approve + ' ' + reject + ' ' + leader + '">' + onteam + '</td>';
        }
        html += '</tr>';
    }
    html += '</table>';

    $('#votelog').html(html);
}

var drawPlayers = function(data) {
    var round = Math.min(g.scoreboard.round || 1, 5);
    for (var i = 0; i < g.players.length; ++i) {
        if (g.players[i].id === g.leader) {
            var hammer = g.players[(i + 5 - round) % g.players.length].id;
        }
    }

    var html = "";
    var takeMode = 
        g.choices.length > 0 &&
        g.choices[g.choiceIdx].cmd === 'chooseTakeCard';
        
    for (var i = 0; i < g.players.length; ++i) {
        var name = g.players[i].name;
        var id = g.players[i].id;
        var isOpinionMaker = g.cards.filter(function(c) { return c.player === id && c.card === 'OpinionMaker' }).length > 0;
        var cards = g.cards
            .filter(function (c) { return c.player === id; })
            .map(function (c) { 
                var showButton = takeMode && g.choices[g.choiceIdx].players.indexOf(id) !== -1;
                return "<div class=media>" +
                        (showButton ? "<button class='pull-left btn btn-success btn-mini' onclick='onDismissChoose({ player:" + id + ", card:\"" + c.card + "\" })'>Take</button>" : "") +
                        "<div class=media-body>" + cardNames[c.card] + "</div>" +
                    "</div>"; 
            });
        
        var cardsPopover = "<div class=normal-word-break style='width:200px'>" + cards.join('') + "</div>";
        var cardsTooltip = "<div class=normal-word-break>" + name + " has plot cards. Click for details.</div>";
        var cardsIcon = 
            "<span class=plot-cards data-html=true title=\"" + xmlEscape(cardsTooltip) + "\">" +
                "<span data-html=true title='<b>Plot cards</b>'  data-content=\"" + xmlEscape(cardsPopover) + "\">" +
                    "<i class=icon-book></i>" +
                "</span>" +
            "</span>";
        
        var opinionMakerTooltip = "<div class=normal-word-break>" + name + " is an Opinion Maker.</div>";
        var opinionMakerIcon = "<span class=opinion-maker><i class=icon-share data-html=true title=\"" + xmlEscape(opinionMakerTooltip) + "\"></i></span>";
        
        var hammerTooltip = "<div class=normal-word-break>" + name + " is the hammer.</div>";
        var hammerIcon = "<span class=hammer><i class=icon-star-empty data-html=true title=\"" + xmlEscape(hammerTooltip) + "\"></i></span>";
        
        var labelColor = "";
        var labelText = g.players[i].role || "";
        if (labelText === "Resistance" || labelText === "Spy") {
            labelText = "";
        }
        if (g.votes[id] != null) {
            labelText = g.votes[id];
            labelColor = (g.votes[id] === 'Approve' ? 'label-success' : 'label-important');
        }
        
        html += "<div id=player" + id + " class='usertile" + (g.highlights[id] ? ' highlight' : '') + "'>" +
                "<img src=" + (g.players[i].isSpy ? 'spy' : 'resistance') + ".png>" +                
                "<br>" + (cards.length !== 0 ? cardsIcon : '') + ' ' + name + ' ' + (isOpinionMaker ? opinionMakerIcon : '') + (hammer === id ? hammerIcon : '') +
                "<br><span class='label " + labelColor + "'>" + labelText + "</span>&nbsp;" +
                "</div>";
    }
    
    if (g.players.length > 0) {
        html += "<img id=leader-star src=leader.png style='position:absolute'>";
    }
    
    $('#game-field').html(html);
    for (var i = 0; i < g.players.length; ++i) {
        $('#player' + g.players[i].id + ' img').click(onClickUserTile(g.players[i].id));
        $('#player' + g.players[i].id + ' .plot-cards').tooltip({placement: 'bottom'});
        $('#player' + g.players[i].id + ' .opinion-maker i').tooltip({placement: 'bottom'});
        $('#player' + g.players[i].id + ' .plot-cards span').popover({placement: 'top'});
    }
    
    $('span.hammer i').tooltip({placement: 'bottom'});
    
    arrangePlayers();
}

var arrangePlayers = function(data) {
    if (g.players.length === 0) {
        return;
    }
    
    var itemWidth = $('#player' + g.players[0].id).width();
    var fieldWidth = $('#game-field').parent().width();
    var fieldHeight = 500;
    var points = pointsOnAnEllipse(fieldWidth * 0.8, fieldHeight * 0.6, g.players.length);
    for (var i = 0; i < g.players.length; ++i) {
        g.players[i].x = points[i].x + fieldWidth / 2 - itemWidth / 2;
        g.players[i].y =  points[i].y + 160;
        $('#player' + g.players[i].id)
            .css('left', g.players[i].x)
            .css('top',  g.players[i].y);
            
        if (g.leader === g.players[i].id) {
            $('#leader-star')
                .css('left', g.players[i].x + leaderOffsetX)
                .css('top',  g.players[i].y + leaderOffsetY)
                .click(onClickUserTile(g.leader));
        }
    }
    
    for (var i = 0; i < g.guns.length; ++i) {
        var pos = $('#player' + g.guns[i]).position();
        $('#gun' + i).css('left', pos.left + gunsOffsetX).css('top', pos.top + gunsOffsetY);
    }
}

var pointsOnAnEllipse = function(width, height, n) {
    var m = 1000;
    var x = [];
    var y = [];
    for (var i = 0; i < m; ++i) {
        var angle = i / m * 2 * Math.PI;
        x.push(Math.sin(angle) * width / 2);
        y.push(-Math.cos(angle) * height / 2);
    }
    
    var total = 0;
    var x2 = x[x.length - 1];
    var y2 = y[y.length - 1];
    for (i = 0; i < m; ++i) {
        x1 = x2;
        y1 = y2;
        var x2 = x[i];
        var y2 = y[i];
        total += Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
    }
    
    var ans = [];
    var runningTotal = 0;
    var x2 = x[x.length - 1];
    var y2 = y[y.length - 1];
    for (i = 0; i < m; ++i) {
        x1 = x2;
        y1 = y2;
        x2 = x[i];
        y2 = y[i];
 
       runningTotal += Math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
        if (runningTotal >= 0) {
            ans.push({x: x2, y: y2});
            runningTotal -= total / n;
        }
    }
    
    return ans;
}

var xmlEscape = function(s) {
    return s
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/'/g, '&apos;')
        .replace(/"/g, '&quot;');
}

var updateChat = function(selector, data) {
    var currentDiv = selector.children(".current");
    var lines = (currentDiv.data("lines") || 0) + 1;
    currentDiv.append(
        "<code>[" + new Date().toTimeString().substring(0, 5) + "]</code> " +
        "<span style='" + (data.serverMsg ? "color: teal" : "") + "'>" +
        "<b>" + xmlEscape(data.player) + "</b>: " + 
        xmlEscape(data.msg) + "</span><br>");
    currentDiv.data("lines", lines);
    
    if (lines >= 10) {
        var innerHtml = currentDiv.html();
        currentDiv.remove();
        selector.append("<div>" + innerHtml + "</div><div class='current'></div>");
    }

    selector.prop({scrollTop: selector.prop('scrollHeight')});
}

var getHighlights = function() {
    return Object.keys(g.highlights)
        .filter(function(i) { return g.highlights[i]; })
        .map(function(i) { return parseInt(i, 10); });
}

var sendAjax = function(x, verb) {
    //debugLog.push({ dir:'OUT', verb:verb, body:x });
    return $.ajax(
        '/server/play', { 
        type: verb || 'POST', 
        processData: false,
        contentType: 'application/json',
        data: x == null ? '' : JSON.stringify(x) })
    .fail(function(xmlHttpRequest, code, error)
    {
        window.alert('There was a network error. Please log back in.\n\n' + code + '\n' + error + '\n' + xmlHttpRequest.responseText);
        window.location = '/';        
    });
}

var pollLoop = function() {
    sendAjax(null, "GET")
        .done(function(data) {
            //debugLog.push({ dir:'IN', verb:'GET' });
            for (var i = 0; i < data.length; ++i) {
                //debugLog.push({ dir:'IN', verb:'GET', body: data[i] });
                var handler = handlers[data[i].cmd];
                if (handler != null) {
                    try {
                        handler(data[i]);
                    } catch (e) {
                        sendAjax({ cmd: 'clientCrash', exception:e, msg:data[i] });
                    }
                }
            }
            pollLoop();
        });
}

var highlightTab = function(selector) {
    if (!$(selector).hasClass('active')) {
        $(selector + ' a').addClass('tab-highlight');
    }
}

var unhighlightTab = function(selector) {
    return function() {
        $(selector + ' a').removeClass('tab-highlight');
    }
}

var scrollToBottom = function(selector) {
    return function() {
        $(selector).prop({scrollTop: $(selector).prop('scrollHeight')});
    }
}

// On page load ...
$(function() {
    var game_field_width = $('#game-field').width();
    setInterval(function() {
        var w = $('#game-field').width();
        if (w !== game_field_width) {
            arrangePlayers();
        }
        game_field_width = w;
    }, 100);
    
    $('#all-chat-nav-tab')
        .click(unhighlightTab('#all-chat-nav-tab'))
        .on('shown', scrollToBottom('#all-chat-text'));
    $('#chat-nav-tab')
        .click(unhighlightTab('#chat-nav-tab'))
        .on('shown', scrollToBottom('#chat-text'));
    $('#new-game-original').click(onCreateGame(1));
    $('#new-game-avalon').click(onCreateGame(2));
    $('#new-game-basic').click(onCreateGame(3));
    $('#leave-game').click(onLeaveGame);
    $('#prev-gamelog').click(onPrevGameLog);
    $('#next-gamelog').click(onNextGameLog);
    $('#chat-input').keypress(onEnter('chat'));
    $('#lobby-chat-input').keypress(onEnter('allChat'));
    $('#all-chat-input').keypress(onEnter('allChat'));
    
    pollLoop();
    sendAjax({cmd:'refresh'});
});
