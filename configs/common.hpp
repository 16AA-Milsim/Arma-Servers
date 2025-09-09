// GENERAL SETTINGS
maxPlayers     = 128;               // Maximum amount of players, including headless clients. Anybody who joins the server is considered a player, regardless of their role or team.
persistent     = 0;                 // If set to 1, missions will continue to run after all players have disconnected; required if you want to use the -autoInit startup parameter
requiredBuild  = 133741;			// From 1.60 Patchlog: requiredBuild=xxxxx; in server.cfg preventing obsolete clients to connect. Since 95691 the required version is limited to the server version.
forceRotorLibSimulation = 0;		// Enforces the Advanced Flight Model on the server. Default = 0 (up to the player). 1 - forced AFM, 2 - forced SFM.
forcedDifficulty = "Custom";        // Force difficulty
steamProtocolMaxDataSize = 10000;   // Max size of data sent to steam. Default 10000. Increase if you have a lot of mods and are getting steam errors.
// missionsToServerRestart = 1;        // Restart the server after every mission

// VOICE CHAT
disableVoN       = 1;   // If set to 1, voice chat will be disabled
vonCodecQuality  = 3;   // Supports range 1-30; 1-10 is 8kHz (narrowband), 11-20 is 16kHz (wideband), 21-30 is 32kHz (ultrawideband); higher = better sound quality, more bandwidth consumption

// WELCOME MESSAGE ("message of the day")
// It can be several lines, separated by comma
// Empty messages "" will not be displayed, but can be used to increase the delay before other messages
motdInterval = 3;    // Number of seconds between each message

// SECURITY
BattlEye          = 0;    // If set to 1, BattlEye Anti-Cheat will be enabled on the server (default: 1, recommended: 1)
verifySignatures  = 0;    // If set to 2, players with unknown or unsigned mods won't be allowed join (default: 0, recommended: 2)
kickDuplicate     = 1;    // If set to 1, players with an ID that is identical to another player will be kicked (recommended: 1)
upnp = 0;	              // Automatically creates port mapping on UPNP/IGD enabled router. This option allows you to create a server behind NAT (your router must have public IP and support UPNP/IGD protocol)
allowedFilePatching = 1;  //Prevent or allow file patching for the clients (including the HC) (since Arma 3 1.49+)  (0 is no clients (default),1 is Headless Clients only, 2 is all clients)

// EVENT SCRIPTS (see http://community.bistudio.com/wiki/ArmA:_Server_Side_Scripting)
onUserConnected     = "";    // command to run when a player connects
onUserDisconnected  = "";    // command to run when a player disconnects
doubleIdDetected    = "kick (_this select 0)";    // command to run if a player has the same ID as another player in the server
onUnsignedData      = "kick (_this select 0)";    // command to run if a player has unsigned files
onHackedData        = "kick (_this select 0)";    // command to run if a player has tampered files

// HEADLESS CLIENT
headlessClients[]  = {"127.0.0.1"};
localClient[] =  {"127.0.0.1"};
briefingTimeOut = -1;
roleTimeOut = -1;
votingTimeOut = -1;
debriefingTimeOut = -1;
lobbyIdleTimeout = -1;
kickTimeout[] = {{0, 1}, {1, 1}, {2, 1}, {3, 1}};

disconnectTimeout = 15;                         //Time to wait before disconnecting a user which temporarily lost connection. Range is 5 to 90 seconds.
maxDesync = 200;                                //Max desync value until server kick the user
maxPing= 500;                                   //Max ping value until server kick the user
maxPacketLoss= 50;                              //Max packetloss value until server kick the user
kickClientsOnSlowNetwork[] = {1,1,1,1};     //Defines if {<MaxPing>, <MaxPacketLoss>, <MaxDesync>, <DisconnectTimeout>} will be logged (0) or kicked (1)
logFile = "server_console.log";                 //Saves the output of the server console window itself, useful

class AdvancedOptions
{
    LogObjectNotFound = false; // (default true, logging enabled)
    SkipDescriptionParsing = false; // (default false, parse description.ext)
    ignoreMissionLoadErrors = false;
    queueSizeLogG = 1000000;
};