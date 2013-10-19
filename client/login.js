var submit = function() {
    $.ajax('/server/login', { 
        type: 'POST', 
        processData: false,
        contentType: 'application/json',
        data: JSON.stringify({username: $('#username').val(), password: $('#password').val()}) })
    .done(function () {
        window.location = 'main.html';
    })
    .fail(function () {
        window.alert('Invalid username or password.');
    });        
}

$('#password').keypress(function(event) {
    if (event.keyCode === 13) {
        submit();
    }});

$('#playButton').click(submit);
