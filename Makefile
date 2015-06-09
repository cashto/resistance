all: 
	mkdir -p release
	cp -rf client release/client
	cat server/Common.coffee server/Room.coffee server/Lobby.coffee server/Game.coffee server/Player.coffee server/Database.coffee server/Statistics.coffee server/Main.coffee | coffee --compile --stdio > release/Server.js

clean:
	rm -rf release
