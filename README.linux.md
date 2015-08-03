# Getting Started on Linux/Postgres

## Optional: Set up [nodeenv](http://ekalinin.github.io/nodeenv/) and enter the environment

## Create a Postgres database

Any one will do. A simple pattern for doing it at home (Debian-ish) is:

```
$ sudo su postgres
$ psql
postgres=# CREATE USER mypguser WITH PASSWORD 'mypguserpass';
postgres=# CREATE DATABASE mypgdatabase OWNER mypguser;
postgres=# \q
$ exit
```

## Set the environment variables

```
{
    "port": 8080,
    "db_connection_string": "postgres://mypguser:mypguserpass@localhost/mypgdatabase"
}
```

Or equivalent for your choice of hostname, user, password and database name above.

## Set up DB tables

```
$ psql -h localhost -U mypguser -d mypgdatabase
Password for user mypguser:
psql (9.4.2, server 9.3.4)
SSL connection (protocol: TLSv1.2, cipher: DHE-RSA-AES256-GCM-SHA384, bits: 256, compression: off)
Type "help" for help.

mypgdatabase=> \i misc/recreatedb_pg.sql
mypgdatabase=> \q
```

## Build

```
make
```

## Run

```
node release/Server.js sample_options.json
```

And connect on [http://localhost:8080](http://localhost:8080)

