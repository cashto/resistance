DROP TABLE Logins
DROP TABLE GameLog
DROP TABLE GamePlayers
DROP TABLE Games
DROP TABLE Users

/* Original schema: */

CREATE TABLE Users(
    id INT IDENTITY PRIMARY KEY, 
    name NVARCHAR(32) NOT NULL UNIQUE, 
    passwd BINARY(32) NOT NULL, 
    isValid BIT NOT NULL,
	email NVARCHAR(MAX) NOT NULL,
    createTime DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
	validationCode UNIQUEIDENTIFIER)
    
CREATE TABLE Games( 
    id INT IDENTITY PRIMARY KEY, 
    startData NVARCHAR(MAX) NOT NULL, 
    startTime DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
	endTime DATETIME2(7),
	spiesWin BIT)
        
CREATE TABLE GamePlayers(
    gameId INT NOT NULL REFERENCES Games(id) ON DELETE CASCADE, 
    seat TINYINT NOT NULL, 
	playerId INT NOT NULL REFERENCES Users(id),
    isSpy BIT NOT NULL, 
    CONSTRAINT pk_gameplayers PRIMARY KEY (gameId, seat),
	CONSTRAINT uniquePlayer UNIQUE (playerId, gameId))
    
CREATE TABLE GameLog(
    gameId INT NOT NULL REFERENCES Games(id) ON DELETE CASCADE, 
    id INT NOT NULL,
	playerId INT NOT NULL REFERENCES Users(id), 
    action NVARCHAR(MAX) NOT NULL,
    time DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT pk_gamelog PRIMARY KEY (gameId, id))

CREATE TABLE Logins(
	playerId INT NOT NULL REFERENCES Users(id),
	time DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
	ip BINARY(4) NOT NULL)

CREATE CLUSTERED INDEX idx_logins ON Logins(playerId, time)

DECLARE @botpass BINARY(32)
SET @botpass = HASHBYTES('sha2_256', 'password')

INSERT Users(name, passwd, isValid, email) VALUES ('test', @botpass, 1, 'test@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Alpha>', @botpass, 1, 'alpha@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Bravo>', @botpass, 1, 'bravo@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Charlie>', @botpass, 1, 'charlie@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Delta>', @botpass, 1, 'delta@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Echo>', @botpass, 1, 'echo@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Foxtrot>', @botpass, 1, 'foxtrot@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Golf>', @botpass, 1, 'golf@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Hotel>', @botpass, 1, 'hotel@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<India>', @botpass, 1, 'india@example.com')
INSERT Users(name, passwd, isValid, email) VALUES ('<Juliet>', @botpass, 1, 'juliet@example.com')

/* Schema change: Games.gameType added */
ALTER TABLE Games ADD gameType TINYINT NOT NULL DEFAULT 1
