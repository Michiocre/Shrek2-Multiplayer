// *****************************************************
// *	   Shrek 2 Multiplayer (S2M) by Master_64	   *
// *		  Copyrighted (c) Master_64, 2020		   *
// *   May be modified but not without proper credit!  *
// *****************************************************
// 
// Gamerule support -- [Difficulty: 3/5] Add support for adding gamerules to a server, that of which can enforce certain character types, maximum player caps, etc..
// Inventory support -- [Difficulty: 3/5] When a client picks up an item, it should be given to everyone (configurable, on by default).
// Level transfer support -- [Difficulty: 5/5] Add support for transferring a server across levels.
// Save support -- [Difficulty: 3.5/5] Replace save fairy mechanics with a co-op friendly method that doesn't involve using the original save system.
// Enemy support -- [Difficulty: 6/5] Add support for enemies to target specific players. Unsure if the original enemy system is capable of this modification in real-time. Will need plenty of testing.
// Spectating support -- [Difficulty: 5/5] Add support for players to toggle between spectating and playing.


class S2MDataAgg extends MInfo	
	Config(S2Multi);


const ClientSpawnAttempts = 100;					// Default in MUtils is 25, increased to 100 due to the importance of this working.

var protected vector vWorldSpawn;
var protected rotator rWorldSpawn;
var protected travel bool bServerStarted;
var protected bool bLevelLoaded;
var class<Actor> tClass;
var protected S2MTcpClient TcpClient;

var int TickCounter;
var bool IsHost;
var string Username;



struct PlayerDataPacket 
{
	var string Username;
	var vector Location;
	var rotator Rotation;
	var vector Velocity;
	var vector Acceleration;
};

struct PlayerData
{
	var string Username;
	var Actor ActorPointer;
};

var array<PlayerData> PlayerList;

function int FindPlayerIndex(string Username) {
	local int i;
	for (i = 0; i < PlayerList.Length; i++)
	{
		if (PlayerList[i].Username == Username)
		{
			return i;
		}
	}
	return -1;
}

event PostBeginPlay()
{
	super.PostBeginPlay();
}

event PostLoadGame(bool bLoadFromSaveGame)
{
	// Loading a save breaks a lot of stuff, abort everything.
	if(bLoadFromSaveGame)
	{
		Destroy();
		
		return;
	}
	
	// Calculate world spawn.
	
	// This isn't a good way to determine the world spawn for stock levels, but should be perfect for modded levels.
	vWorldSpawn = U.GetHP().Location;
	rWorldSpawn = U.GetHP().Rotation;
	
	bLevelLoaded = true;
	IsHost = false;
}

// Starts a server.
function StartServer(int Port)
{
	Username = class'S2MConfig'.default.sUsername;
	IsHost = true;	

	if(TcpClient != none)
	{
		TcpClient.Close();
	}

	TcpClient = Spawn(class'S2MTcpClient');
	TcpClient.Init(self);
	
	if(TcpClient == none)
	{
		class'S2MVersion'.static.DebugLog("TCP host could not be created.");
	}
	else
	{
		class'S2MVersion'.static.DebugLog("Sending connection request...");
		TcpClient.CreateServer("localhost", Port, Username);
	}

	bServerStarted = true;
}

// Prepares connecting to a server.
function PreConnectToServer(string IP, int Port)
{
	Username = class'S2MConfig'.default.sUsername;
	IsHost = false;

	if(TcpClient != none)
	{
		TcpClient.Close();
	}

	TcpClient = Spawn(class'S2MTcpClient');
	TcpClient.init(self);
	
	if(TcpClient == none)
	{
		class'S2MVersion'.static.DebugLog("TCP client could not be created.");
	}
	else
	{
		class'S2MVersion'.static.DebugLog("Sending connection request...");
		TcpClient.ConnectToServer(IP, Port, Username, "AAAA");
	}
	
	class'S2MVersion'.static.DebugLog("Initiating server connection, awaiting response...");
}

// Server Function when the client sends "connect"
function string ClientConnected(string Name)
{
	local Actor NewShrek;
	local PlayerData Player;
	class'S2MVersion'.static.DebugLog("Client connected: " @ Name);
	NewShrek = CreateNewClient(class'Shrek');

	Player.ActorPointer = NewShrek;
	Player.Username = Name;
	PlayerList.Insert(PlayerList.Length, 1);
	PlayerList[PlayerList.Length - 1] = Player;

	return "connected:" @ Username @ ":" @ U.GetCurrentMap();
}

// Client function when server sends "connected"
function ConnectToServer(string Name, string Level)
{
	class'S2MVersion'.static.DebugLog("Response received, change level to " $ Level $ " and spawn in as " $ Name $ ".");
	U.ChangeLevel(Level);
	
	bServerStarted = true;
}

// Disconnects from the server.
function DisconnectFromServer()
{
	bServerStarted = false;
	
	class'S2MVersion'.static.DebugLog("Disconnected client.");
	
	U.ChangeLevel(class'SHFEGUIPage'.default.FEMenuLevel);
}

event Destroyed()
{
	class'S2MVersion'.static.DebugLog("Data aggregator destroyed, disconnecting client!");
	
	TcpClient.Disconnect();

	class'S2MVersion'.static.DebugLog("Disconnecting client...");
	
	super.Destroyed();
}

function HandlePlayerData(array<string> TokenArray) {
	local Actor PlayerActor;
	local PlayerData Player;
	local int index;
	local float drift;

	index = FindPlayerIndex(TokenArray[1]);

	if (index == -1) {
		class'S2MVersion'.static.DebugLog("Player not found in list, adding new player: " @ TokenArray[1]);
		PlayerActor = CreateNewClient(class'Shrek');
		Player.ActorPointer = PlayerActor;
		Player.Username = TokenArray[1];

		PlayerList.Insert(PlayerList.Length, 1);
		PlayerList[PlayerList.Length - 1] = Player;
	} else {
		PlayerActor = PlayerList[index].ActorPointer;
	}

	PlayerActor.SetRotation(rotator(TokenArray[3]));
	PlayerActor.Velocity = vector(TokenArray[4]);
	
	drift = VSize(PlayerActor.Location - vector(TokenArray[2]));
	if (drift > 1000.0) {
		class'S2MVersion'.static.DebugLog("Player " @ TokenArray[1] @ " is too far away, teleporting to correct location.");
		PlayerActor.SetLocation(vector(TokenArray[2]));
	}
}

event Tick(float DeltaTime)
{	
	if(!bLevelLoaded)
	{
		return;
	}

	if(!bServerStarted)
	{
		return;
	}
	
	HP = U.GetHP();

	if (HP == none || TcpClient == none)
	{
		return;
	}
	
	TcpClient.SendText("playerData:" $ Username $ ":" $ HP.Location $ ":" $ HP.Rotation $ ":" $ HP.Velocity $ ":" $ HP.Acceleration);
}

// Converts a string containing an actor pointer to a class.
function class<Actor> StringActorPointerToClass(string sPointer)
{
	local string S;
	local array<string> TokenArray;
	
	TokenArray = U.Split(sPointer, ".");
	
	S = TokenArray[1];
	
	// Get rid of any numbers in the actor pointer.
	while(U.IsNumeric(Right(S, 1)))
	{
		S = Left(S, Len(S) - 1);
	}
	
	SetPropertyText("tClass", S);
	
	return tClass;
}

// Creates a new player client at world spawn.
function Actor CreateNewClient(class<Actor> C)
{
	local Actor A;

	if(!U.MFancySpawn(C, vWorldSpawn, rWorldSpawn, A, ClientSpawnAttempts))
	{
		return none;
	}
	
	if(A.IsA('KWPawn'))
	{
		U.GivePawnController(KWPawn(A));
	}

	return A;
}

// Tries to spawn in an actor in any location possible.
function Actor SmartSpawn(class<Actor> C)
{
	local Actor A;
	local Light L;
	local bool bReturn;
	
	// Get a location that has a good chance of having a lot of open space. I know this is hacky, but how else can you actually do this?
	foreach AllActors(class'Light', L)
	{
		bReturn = U.MFancySpawn(C, L.Location,, A);

		break;
	}

	if(!bReturn)
	{
		bReturn = U.MFancySpawn(C, vWorldSpawn,, A);

		if(!bReturn)
		{
			return none;
		}
	}
	
	if(A.IsA('KWPawn'))
	{
		U.GivePawnController(KWPawn(A));
	}
	
	return A;
}

function DisplayChatMessage(string user, string message) {
	// Types in the chat.
	HudItems = U.GetHudItems();
	
	// Client-sided chat censor logic.
	if(!class'S2MConfig'.default.bAllowProfaneLanguage)
	{
		if(class'S2MProfaneWords'.static.IsProfane(message))
		{
			message = "^1[Censored]";
		}
	}
	
	// Looks complicated, but we're calling the dynamic HUD item that is our chat, then displaying the chat message provided.
	S2MHUDItem_Chat(HudItems[U.IsHUDItemLoaded(class'S2MHUDItem_Chat')]).CreateChatMessage(user, message);
}

function SendChatMessage(string message) {
	// Sends a chat message to the server.
	if(TcpClient != none)
	{
		TcpClient.SendText("chat:" $ Username $ ":" $ message);
	}
}


defaultproperties
{
	bStatic=false
	bTravel=true
}