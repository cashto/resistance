DROP TABLE logins;
DROP TABLE gamelog;
DROP TABLE gameplayers;
DROP TABLE games;
DROP TABLE users;

/* Original schema: */

CREATE TABLE users
(
    id SERIAL PRIMARY KEY, 
    name VARCHAR(32) NOT NULL UNIQUE, 
    passwd TEXT NOT NULL, 
    is_valid BOOLEAN NOT NULL,
    email TEXT NOT NULL,
    create_time TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    validation_code CHAR(16)
);

CREATE TABLE games
( 
    id SERIAL PRIMARY KEY, 
    start_data TEXT NOT NULL, 
    start_time TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP(6),
    spies_win BOOLEAN
);

CREATE TABLE gameplayers
(
    game_id INT NOT NULL REFERENCES games(id) ON DELETE CASCADE, 
    seat SMALLINT NOT NULL, 
    player_id INT NOT NULL REFERENCES users(id),
    is_spy BOOLEAN NOT NULL, 
    CONSTRAINT pk_gameplayers PRIMARY KEY (game_id, seat),
    CONSTRAINT unique_player UNIQUE (player_id, game_id)
);

CREATE TABLE gamelog
(
    game_id INT NOT NULL REFERENCES games(id) ON DELETE CASCADE, 
    id INT NOT NULL,
    player_id INT NOT NULL REFERENCES users(id), 
    action TEXT NOT NULL,
    time TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_gamelog PRIMARY KEY (game_id, id)
);

CREATE TABLE logins
(
	player_id INT NOT NULL REFERENCES users(id),
	time TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
	ip VARCHAR(30) NOT NULL
);

CREATE INDEX idx_logins on logins(player_id, time);

/* CREATE EXTENSION pgcrypto; */

INSERT INTO users(name, passwd, is_valid, email) VALUES ('test', '', true, 'test@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Alpha>', '', true, 'alpha@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Bravo>', '', true, 'bravo@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Charlie>', '', true, 'charlie@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Delta>', '', true, 'delta@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Echo>', '', true, 'echo@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Foxtrot>', '', true, 'foxtrot@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Golf>', '', true, 'golf@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Hotel>', '', true, 'hotel@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<India>', '', true, 'india@example.com');
INSERT INTO users(name, passwd, is_valid, email) VALUES ('<Juliet>', '', true, 'juliet@example.com');

/* Schema change: Games.gameType added */
ALTER TABLE Games ADD game_type SMALLINT NOT NULL DEFAULT 1;
