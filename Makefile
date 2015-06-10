all: 
	mkdir -p release
	cp package_linux.json release/package.json
	cd release && npm install
	cat server/Common.coffee server/Room.coffee server/Lobby.coffee server/Game.coffee server/Player.coffee server/Database_Postgres.coffee server/Statistics.coffee server/Main.coffee | coffee --compile --stdio > release/Server.js
	cp -rf client release/client

clean:
	rm -rf release

test: all
	cat server/Room.coffee server/Game.coffee server/Player.coffee server/Database_Postgres.coffee server/Lobby.coffee server/Test.coffee | coffee --compile --stdio > release/Test.js
	node release/Test.js
