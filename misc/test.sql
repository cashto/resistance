-- Show all users.
SELECT * FROM Users
SELECT * FROM Users ORDER BY passwd

-- Show all games.
SELECT 
	startTime, 
	DATEDIFF(n, startTime, endTime) AS durationMinutes,
	(SELECT COUNT(*) from GamePlayers AS gp where gp.gameId = g.id) AS numPlayers,
	gameType,
	spiesWin
FROM Games AS g WHERE endtime is not null

SELECT gp.gameId, u.name from GamePlayers AS gp, Users as u where u.id = gp.playerId order by gp.gameId

-- Show last 50 logins.
SELECT TOP 50 u.name, l.time, l.ip FROM Logins AS l, Users AS u WHERE u.name = 'jbode' ORDER BY TIME DESC

-- Get information for a specific game.
DECLARE @gameId INT
SET @gameId = 1149
SELECT * FROM Games WHERE id = @gameId
SELECT u.id, u.name, g.isSpy FROM GamePlayers as g, Users as u WHERE gameId = @gameId AND g.playerId = u.id
SELECT u.name, l.action, l.time FROM GameLog AS l, Users as U WHERE gameId = @gameId AND u.id = l.playerId ORDER BY l.id

-- Get information for a specific player.
DECLARE @playerId INT
SET @playerId = 17
SELECT TOP 50 u.name, l.time, l.ip FROM Logins AS l, Users AS u WHERE u.id = l.playerId AND u.id = @playerId ORDER BY TIME DESC
SELECT g.id, g.startTime, g.endTime, gp.isSpy, g.spiesWin FROM Games AS g, Users AS u, GamePlayers as gp WHERE u.id = @playerId AND u.id = gp.playerId AND g.id = gp.gameId AND NOT g.endTime IS NULL

select * from gamelog where action like '%clientCrash%'