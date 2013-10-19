# Getting Started

* Install [Node.JS](http://nodejs.org/dist/v0.8.26/) v0.8.26.
* From the command line, run `npm install -g coffee-script` to install CoffeeScript. 
* Install [MS SQL Server Express](http://www.microsoft.com/en-us/download/details.aspx?id=29062).
* Install [Microsoft Driver for Node.JS](http://www.microsoft.com/en-us/download/details.aspx?id=29995). **This driver is only compatible with v0.8.x releases of Node.JS, so it is important to use this version.**
* Create a "resistancetest" database in MS SQL Server Express.
* Run recreatedb.sql on the database.
* Set environment variable `RELDIR` to point to an empty directory.
* Set environment variable `RESISTANCE_DB_CONNECTION_STRING`.

        set RELDIR=c:\temp\reldir
        set RESISTANCE_DB_CONNECTION_STRING=
            Driver={SQL Server Native Client 11.0};
            Server=localhost;
            Database=resistancetest;
            uid=<userid>;
            pwd=<password>;

* From the "server" directory, run `build %RELDIR%`
* Run `node.js %RELDIR%\Server.js`
* Navigate to [http://localhost/](http://localhost/)

