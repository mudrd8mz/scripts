/**
 * NodeJS LogBot
 * @author Matthew Spurrier
 *
 * Install Requirements:
 * sudo add-apt-repository ppa:chris-lea/node.js
 * sudo apt-get update
 * sudo apt-get install nodejs
 * npm install simple-xmpp
 * npm install node-xmpp
 * npm install util
 * npm install qbox
 * npm install mysql
 * npm install fancy-timestamp
**/

/**
 * Jabber Configuration
**/
var user				= ''; // user@example.com
var pass				= '';
var server				= '';
var conference_server	= '';
var alias				= '';
var forums				= [ ];

/**
 * MySQL Configuration
**/
var mysqluser			= '';
var mysqlpass			= '';
var mysqlhost			= '';
var mysqlname			= '';

// Begin Application
var xmpp = require('simple-xmpp');
var mysql = require('mysql');
var timestamp = require('fancy-timestamp');

function joinForum(forum) {
	var forum = forum+'@'+conference_server;
	var to = forum+'/'+alias;
	var stanza = new xmpp.Element('presence', {"to": to}).
	        c('x', { xmlns: 'http://jabber.org/protocol/muc' }).
	        c('history', { maxstanzas: 0, seconds: 1});
    xmpp.conn.send(stanza);
    xmpp.join(to);
    mucusermap[forum]=[];
    console.log('Joined channel "%s"', forum);
}

xmpp.on('online', function() {
	console.log('Connected!');
	forums.forEach(function(forum) {
		joinForum(forum);
	})
});

xmpp.on('chat', function(from, message) {
	// Private message, we don't really care about this
});

xmpp.on('groupchat', function(forum, from, message) {
	// Group chat message, log it!
	forump = forum.split('/')[0];
	fromjid = mucusermap[forum][from];
	forump = forump.split('@')[0];
	table = forump + '_room_msgs';
	query = "INSERT INTO " + mysql.escapeId(table) + " (sender, nickname, logTime, subject, body) VALUES (" + sqlconn.escape(fromjid) + "," + sqlconn.escape(from) + ",UNIX_TIMESTAMP(),''," + sqlconn.escape(message) + ")";
	sqlconn.query(query, function(err, results) {});
	isseenreq = RegExp('^!seen ');
	if (isseenreq.test(message)) {
		seenname = message.split('!seen ')[1];
		seenname = seenname.split(' ')[0];
		query = "SELECT logTime from " + mysql.escapeId(table) + " WHERE nickname = " + sqlconn.escape(seenname) + " ORDER BY logTime DESC LIMIT 1";
		sqlconn.query(query, function(err, results) {
			if (results.length > 0) {
				xmpp.send(forum, from + ": " + seenname + " was last seen " + timestamp(results[0].logTime), true);
			} else {
				xmpp.send(forum, from + ": Sorry, I've not seen " + seenname, true);
			}
		});
	}
});

xmpp.on('error', function(err) {
	console.error(err);
});

xmpp.on('close', function() {
	console.log('Connection was closed.');
});

xmpp.on('stanza', function(stanza) {
	if (stanza.is('presence')) {
		if(stanza.getChild('x') !== undefined) {
			stanza.getChildren('x').forEach(function(child) {
				if (child.attrs.xmlns == 'http://jabber.org/protocol/muc#user') {
					role = child.getChild('item').attrs.role;
					jid =  child.getChild('item').attrs.jid;
					forum = stanza.attrs.from.split('/')[0];
					nick = stanza.attrs.from.split('/')[1];
					isme = new RegExp('^'+user);
					if (!isme.test(jid)) {
						if (role !== 'none') {
							mucusermap[forum][nick]=jid;
						} else {
							delete mucusermap[forum][nick];
						}
					}
				}
			});
		}
	}
});

var mucusermap = [];
var sqlconn;

function persistDB() {
	sqlconn = mysql.createConnection({
		host		: mysqlhost,
		user		: mysqluser,
		password	: mysqlpass,
		database	: mysqlname
	});
	sqlconn.connect(function(err) {
		if (err) {
			console.log('error connecting to database:', err);
			setTimeout(persistDB, 2000);
		}
	});
	sqlconn.on('error', function(err) {
		console.log('db error:', err);
		if (err.code == 'PROTOCOL_CONNECTION_LOST') {
			persistDB();
		} else {
			throw err;
		}
	});
} 

persistDB();

xmpp.connect({
	jid			: user,
	password	: pass,
	host		: server,
	port		: 5222
});

xmpp.getRoster();
xmpp.setPresence('online', "I'm in channels logging your chats");
