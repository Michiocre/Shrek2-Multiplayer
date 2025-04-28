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
const MissingLevelPacketIDRadiusCheckSize = 125.0f;	// Unsure if this is necessary any longer.

struct LevelPacketStruct
{
	var Actor ID;			// The actor pointer.
	var vector Location;	// The location of the actor.
	var rotator Rotation;	// The rotation of the actor.
	var float Health;		// The health of the actor.
	var name Anim, State;	// The current animation and state of the actor.
};

struct PlayersPacketStruct
{
	var Actor ID;			// The actor pointer.
	var string Username;	// The name of the client.
	var bool bHost;			// If true, this player packet is the host.
};

struct TranslateStruct
{
	var string HostPtr, ClientPtr;	// The string-casted actor pointers across games.
};

var protected array<LevelPacketStruct> InitServerLevelPacket, ClientLevelPacket, ServerLevelPacket;
var protected array<PlayersPacketStruct> InitServerPlayersPacket, ServerPlayersPacket, ClientPlayersPacket;
var protected array<string> Events;
var protected array<string> NewEvents;
var protected array<TranslateStruct> Translators;
var protected array<Actor> IgnoreIDBuffer;
var protected vector vWorldSpawn;
var protected rotator rWorldSpawn;
var protected S2MGameRules GR;	// Handle this later, not relevant yet.
var protected travel bool bServerStarted;
var protected bool bLevelLoaded;
var class<Actor> tClass;

// Files for Tick Updates
const OUTPUT_PATH = "..\\System\\S2Multi\\Output.S2M";
const INPUT_PATH = "..\\System\\S2Multi\\Input.S2M";
// Files for Confirmed Updates
const EVENT_OUT_PATH = "..\\System\\S2Multi\\EventOutput.S2M";
const EVENT_IN_PATH = "..\\System\\S2Multi\\EventInput.S2M";
var int TickCounter;
var bool IsHost;
var string Username;


event PostBeginPlay()
{
	super.PostBeginPlay();
}

event PostLoadGame(bool bLoadFromSaveGame)
{
	local S2MGameRules tGR;
	
	// Loading a save breaks a lot of stuff, abort everything.
	if(bLoadFromSaveGame)
	{
		Destroy();
		
		return;
	}
	
	// Initialize game rules.
	// We're not using game rules yet, but might as well leave this in for now.
	
	foreach AllActors(class'S2MGameRules', tGR)
	{
		break;
	}
	
	if(tGR == none)
	{
		GR = Spawn(class'S2MGameRules');
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
	local array<LevelPacketStruct> levelData;

	Username = class'S2MConfig'.default.sUsername;
	IsHost = true;

	//Run initial update
	levelData = GetLevelPacket();
	WriteToFileLevel(levelData, OUTPUT_PATH);
	
	FireClientEvent("Start" @ string(Port) @ Username @ U.GetHP()); // External
	
	class'S2MVersion'.static.DebugLog("Initialization packet created by" @ Username $ ".");
	class'S2MVersion'.static.DebugLog("Server starting up...");

	// This is the point where we'd initialize the gamerule logic. I'm not going to do that yet, since it's currently irrelevant.
	// class'S2MVersion'.static.DebugLog("Initializing gamerules...");
	
	bServerStarted = true;
}

// Stops the server if it's the host.
function StopServer()
{
	if(!IsHost)
	{
		class'S2MVersion'.static.DebugLog("Can't terminate a server you aren't hosting.");
		
		return;
	}
	
	FireClientEvent("Disconnect"); // External
	FireClientEvent("Stop"); // External
	
	class'S2MVersion'.static.DebugLog("Terminating server...");
}

// Prepares connecting to a server.
function PreConnectToServer(string IP, int Port)
{
	Username = class'S2MConfig'.default.sUsername;
	IsHost = false;

	FireClientEvent("Connect" @ IP @ string(Port) @ Username @ U.GetHP()); // External
	
	class'S2MVersion'.static.DebugLog("Initiating server connection, awaiting response...");
}

// Connects to a server.
function ConnectToServer()
{
	local array<string> Ds;
	
	class'S2MVersion'.static.DebugLog("Response received, connection being established...");
	
	// Initialize provided server player packet.
	U.LoadStringArray(Ds, "..\\System\\S2Multi\\ServerPlayers.S2M");
	
	if(Ds.Length > 0)
	{
		ServerPlayersPacket = FormatStringPlayersPacket(Ds);
		
		// Handle server player packet.
	}
	else
	{
		class'S2MVersion'.static.DebugLog("Initialization client packet is empty, this is about to get bad!");
	}
	
	// Prepare a new client player packet.
	ClientPlayersPacket.Insert(ClientPlayersPacket.Length, 1);
	ClientPlayersPacket[ClientPlayersPacket.Length - 1].Username = class'S2MConfig'.default.sUsername;
	ClientPlayersPacket[ClientPlayersPacket.Length - 1].ID = U.GetHP();
	
	// Initialize provided server level packet.
	U.LoadStringArray(Ds, "..\\System\\S2Multi\\ServerLevel.S2M");
	
	if(Ds.Length > 0)
	{
		ServerLevelPacket = FormatStringLevelPacket(Ds);
		
		// Handle server level packet.
	}
	else
	{
		class'S2MVersion'.static.DebugLog("Initialization server packet is empty, this could be bad.");
	}
	
	class'S2MVersion'.static.DebugLog("Client connected to host:" $ class'S2MConfig'.default.sUsername);
	
	// This is the point where we'd initialize the gamerule logic. I'm not going to do that yet, since it's currently irrelevant.
	// class'S2MVersion'.static.DebugLog("Initializing gamerules...");
	
	bServerStarted = true;
}

// Prepares disconnecting from the server.
function PreDisconnectFromServer()
{
	FireClientEvent("Disconnect"); // External
	
	class'S2MVersion'.static.DebugLog("Disconnecting client...");
}

// Disconnects from the server.
function DisconnectFromServer()
{
	bServerStarted = false;
	
	class'S2MVersion'.static.DebugLog("Disconnected client.");
	
	U.ChangeLevel(class'SHFEGUIPage'.default.FEMenuLevel);
}

function WriteToFilePlayers(array<PlayersPacketStruct> data, string path) {
	U.SaveStringArray(FormatPlayersPacket(data), path);
}

function WriteToFileLevel(array<LevelPacketStruct> data, string path) {
	U.SaveStringArray(FormatLevelPacket(data), path);
}

function WriteToFile(array<string> data, string path) {
	U.SaveStringArray(data, path);
}

function array<PlayersPacketStruct> ReadFromFilePlayers(string path)
{
	local array<string> lines;
	local array<PlayersPacketStruct> data;
	U.LoadStringArray(lines, path);
	
	if(lines.Length > 0)
	{
		if(lines[0] != "")
		{
			class'S2MVersion'.static.DebugLog("Reading PlayerData of size" @ string(lines.Length) @ "from server.");
			
			data = FormatStringPlayersPacket(lines);
		}
	}

	return data;
}

function array<LevelPacketStruct> ReadFromFileLevel(string path)
{
	local array<string> lines;
	local array<LevelPacketStruct> data;
	U.LoadStringArray(lines, path);
	
	if(lines.Length > 0)
	{
		if(lines[0] != "")
		{
			class'S2MVersion'.static.DebugLog("Reading LevelData of size" @ string(lines.Length) @ "from server.");
			
			data = FormatStringLevelPacket(lines);
		}
	}
	return data;
}

function array<string> ReadFromFile(string path)
{
	local array<string> data;
	U.LoadStringArray(data, path);
	return data;
}

event Destroyed()
{
	class'S2MVersion'.static.DebugLog("Data aggregator destroyed, disconnecting client!");
	
	PreDisconnectFromServer();
	
	super.Destroyed();
}

event Tick(float DeltaTime)
{	
	if(!bLevelLoaded)
	{
		return;
	}
	
	HP = U.GetHP();

	if(!bServerStarted)
	{
		return;
	}

	WriteToFileLevel(GetLevelPacket(), OUTPUT_PATH);
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

// Disables movement logic for other players in the server, except for the client. For replication.
function DisableMovementForOtherPlayers()
{
	local int i;
	
	HP = U.GetHP();
	
	for(i = 0; i < InitServerPlayersPacket.Length; i++)
	{
		if(InitServerPlayersPacket[i].ID != HP)
		{
			Pawn(InitServerPlayersPacket[i].ID).UnPossessed();
		}
	}
}

// Processes all input events, which are denoted via "!".
function ProcessEvents()
{
	local int i, j;
	local array<string> TokenArray;
	local LevelPacketStruct Ps;
	local bool B;
	
	if(Events.Length > 0)
	{
		// Handle server events.
		for(i = 0; i < Events.Length; i++)
		{
			// Make sure we only process an event if it is specified as an input event (with "!").
			if(Left(Events[i], 1) != "!" || Events[i] == "")
			{
				continue;
			}
			
			// Logging hack.
			if(!B)
			{
				class'S2MVersion'.static.DebugLog("Received" @ string(Events.Length) @ "events from server, processing events now...");
				
				//B = true;
			}
			
			// Remove the "!" from the beginning of the event input string.
			Events[i] = Mid(Events[i], 1);
			
			class'S2MVersion'.static.DebugLog("Firing event:" @ Events[i]);
			
			TokenArray = U.Split(Events[i], "#");
			
			// List of all possible events, plus functionality
			switch(Caps(TokenArray[0]))
			{
				case "CONNECTED": // External
					// Runs code related to connecting.
					ConnectToServer();
				case "CLIENTCONNECTED": // External
					// Acts as if a client has connected.
					DisableMovementForOtherPlayers();
					
					break;
				case "DISCONNECTED": // External
					// Disconnects from the server.
					DisconnectFromServer();
					
					break;
				case "UPDATEINIT": // External
					// Updates both external init files at once. Expensive.
					
					break;
				case "CLIENT_CREATE": // External
					// IMPORTANT THIS EVENT GETS FIRED WHEN A CLIENT HAS CREATED SOMETHING
					// the host will then send out a HOST_CREATE event to let the other clients catch up
					if(!IsHost) 
					{
						class'S2MVersion'.static.DebugLog("Client recieved HOST_CREATE ... ignore");
						break;
					}

					// Avert your eyes everyone :D
					// Creates an actor on the host.
					TokenArray.Remove(0, 1);

					Ps = FormatSingleTokenArrayLevelPacket(TokenArray);
					
					if (Ps.ID == none) 
					{
						Ps.ID = SmartSpawn(StringActorPointerToClass(TokenArray[0]));

						U.MFancySetLocation(Ps.ID, Ps.Location);
						U.FancySetRotation(Ps.ID, Ps.Rotation);
						U.SetHealth(Pawn(Ps.ID), Ps.Health, true);
						Ps.ID.LoopAnim(Ps.Anim);
						Ps.ID.GotoState(Ps.State);

						InitServerLevelPacket.Insert(InitServerLevelPacket.Length, 1);
						InitServerLevelPacket[InitServerLevelPacket.Length - 1] = Ps;
						class'S2MVersion'.static.DebugLog("CREATED ACTOR ON HOST");
						AppendClientEvent("HOST_CREATE" @ FormatSingleLevelPacket(Ps) @ TokenArray[0]);
					}

					break;
				case "HOST_CREATE": // External
					// IMPORTANT THIS EVENT GETS FIRED WHEN A HOST HAS CREATED SOMETHING
					// the client can then spawn something (if the actor was created by the client the packet contains a special)
					if(IsHost) 
					{
						class'S2MVersion'.static.DebugLog("Host recieved a event from a HOST ... strange");
						break;
					}

					// Avert your eyes everyone :D
					// Creates an actor on the client, assumes the given actor pointer exists on the host, remembers to translate the data when needed, then spawns in the actor.
					TokenArray.Remove(0, 1);

					Ps = FormatSingleTokenArrayLevelPacket(TokenArray);
					
					if (Ps.ID == none)
					{
						Ps.ID = SmartSpawn(StringActorPointerToClass(TokenArray[0]));

						U.MFancySetLocation(Ps.ID, Ps.Location);
						U.FancySetRotation(Ps.ID, Ps.Rotation);
						U.SetHealth(Pawn(Ps.ID), Ps.Health, true);
						Ps.ID.LoopAnim(Ps.Anim);
						Ps.ID.GotoState(Ps.State);

						InitServerLevelPacket.Insert(InitServerLevelPacket.Length, 1);
						InitServerLevelPacket[InitServerLevelPacket.Length - 1] = Ps;
					}
					

					// !? Make sure this does something
					Translators.Insert(Translators.Length, 1);
					Translators[Translators.Length - 1].HostPtr = TokenArray[0];
					Translators[Translators.Length - 1].ClientPtr = string(Ps.ID);

					break;
				case "CLIENT_DESTROY": // External
					// IMPORTANT THIS EVENT GETS FIRED WHEN A CLIENT HAS DESTROYED SOMETHING
					// Destroys an actor on the host. Expensive.

					if (IsHost)
					{
						U.FancyDestroy(Actor(FindObject(TokenArray[1], class'Actor')));
					}
					else
					{
						// ?! ADD TRANSLATION FOR CLIENT
						U.FancyDestroy(Actor(FindObject(TokenArray[1], class'Actor')));
					}

					break;
				case "HOST_DESTROY": // External
					// IMPORTANT THIS EVENT GETS FIRED WHEN A CLIENT HAS DESTROYED SOMETHING
					// Destroys an actor on the client, after translating what the pointer would normally be for the client. Expensive.
					if (IsHost)
					{
						class'S2MVersion'.static.DebugLog("Host recieved event from HOST ... strange");
						break;
					}

					for(j = 0; j < Translators.Length; j++)
					{
						if(InStr(TokenArray[1], Translators[j].ClientPtr) != -1)
						{
							ReplaceText(TokenArray[1], Translators[j].ClientPtr, Translators[j].HostPtr);

							break;
						}
					}

					U.FancyDestroy(Actor(FindObject(TokenArray[1], class'Actor')));

					break;
				case "CHANGELEVEL":
					// Changes the level.
					U.ChangeLevel(TokenArray[1]);
					
					Events.Remove(i, 1);
					
					return;
				case "CHAT":
					// Types in the chat.
					HudItems = U.GetHudItems();
					
					// Client-sided chat censor logic.
					if(!class'S2MConfig'.default.bAllowProfaneLanguage)
					{
						if(class'S2MProfaneWords'.static.IsProfane(TokenArray[2]))
						{
							TokenArray[2] = "^1[Censored]";
						}
					}
					
					// Looks complicated, but we're calling the dynamic HUD item that is our chat, then displaying the chat message provided.
					S2MHUDItem_Chat(HudItems[U.IsHUDItemLoaded(class'S2MHUDItem_Chat')]).CreateChatMessage(TokenArray[1], TokenArray[2]);
					
					break;
				case "GCC":
					// Runs a console command.
					U.CC(TokenArray[1]);
					
					break;
				default:
					break;
			}
			
			// If the client event was processed by the server, erase the client event.
			Events.Remove(i, 1);
			
			i--;
		}
	}
}

// Adds an event to the Events array (the tick function handles reading/writing)
function AppendClientEvent(string event)
{
	NewEvents[NewEvents.Length] = "#" $ event;
}

// // Fires an event out from the client.
function FireClientEvent(string sEvent)
{
	local array<string> Lines;
	local int i;
	
	Lines = ReadFromFile(EVENT_OUT_PATH);
	
	// Remove empty spaces in event data file. This is necessary for CR LF formatting!
	for(i = 0; i < Lines.Length; i++)
	{
		if(Lines[i] == "")
		{
			Lines.Remove(Max(i - 1, 0), 1);
			
			i--;
		}
	}
	
	Lines.Insert(Lines.Length, 1);
	Lines[Lines.Length - 1] = "#" $ sEvent;

	WriteToFile(Lines, EVENT_OUT_PATH);
}

// Initialize the host's level packet.
function array<LevelPacketStruct> GetLevelPacket()
{
	local array<Actor> Actors;
	local Mover M;
	local Trigger T;
	local Pawn P;
	local Pickup PU;
	local TimedCue TC;
	
	// Get all relevant actor pointers.
	foreach DynamicActors(class'Mover', M)
	{
		Actors.Insert(Actors.Length, 1);
		Actors[Actors.Length - 1] = M;
	}
	
	foreach DynamicActors(class'Trigger', T)
	{
		Actors.Insert(Actors.Length, 1);
		Actors[Actors.Length - 1] = T;
	}
	
	foreach DynamicActors(class'Pawn', P)
	{
		// Prevents camera locking.
		if(P.IsA('BaseCam') || P.IsA('BaseCamTarget'))
		{
			continue;
		}
		
		Actors.Insert(Actors.Length, 1);
		Actors[Actors.Length - 1] = P;
	}
	
	foreach DynamicActors(class'Pickup', PU)
	{
		Actors.Insert(Actors.Length, 1);
		Actors[Actors.Length - 1] = PU;
	}
	
	foreach DynamicActors(class'TimedCue', TC)
	{
		Actors.Insert(Actors.Length, 1);
		Actors[Actors.Length - 1] = TC;
	}
	
	// Format the packet with the data acquired.
	return GetRelevantData(Actors);
}

// Returns an array of level packets from an array of actors. It's basically extracting necessary data from the actors to then get ported to a level packet format.
function array<LevelPacketStruct> GetRelevantData(array<Actor> As)
{
	local array<LevelPacketStruct> Ps;
	local int i, i1;
	local name Anim;
	local float F, Health;
	local Actor A;
	
	for(i = 0; i < As.Length; i++)
	{
		// In theory this should improve performance since it reduces index calls?
		A = As[i];
		
		if(A.Mesh != none)
		{
			// Figure out what animation is (likely) visually showing and use that.
			// ~+1 MS since it does a lot of looping.
			// !? Maybe there's a way to optimize this.
			Anim = 'None';
			
			for(i1 = 14; i1 > -1; i1--)
			{
				A.GetAnimParams(i1, Anim, F, F);
				
				if(Anim != 'None')
				{
					break;
				}
			}
		}
		
		if(A.IsA('Pawn'))
		{
			// This function call is expensive if the pawn is not a KWPawn.
			Health = U.GetHealth(Pawn(A));
		}
		else
		{
			Health = 0.0;
		}
		
		Ps.Insert(Ps.Length, 1);
		Ps[i].ID = A;
		Ps[i].Location = A.Location;
		Ps[i].Rotation = A.Rotation;
		Ps[i].Health = Health;
		Ps[i].Anim = Anim;
		Ps[i].State = A.GetStateName();
	}
	
	return Ps;
}

// Converts an array of level packets to string form, for the external file.
function array<string> FormatLevelPacket(array<LevelPacketStruct> Ps)
{
	local array<string> Lines;
	local int i;
	
	Lines.Insert(Lines.Length, 1);
	Lines[Lines.Length -1] = "Tick#" $ string(TickCounter);
	TickCounter++;

	for(i = 0; i < Ps.Length; i++)
	{		
		Lines.Insert(Lines.Length, 1);
		Lines[Lines.Length - 1] = string(Ps[i].ID) $ "#" $ string(Ps[i].Location) $ "#" $ string(Ps[i].Rotation) $ "#" $ string(Ps[i].Health) $ "#" $ string(Ps[i].Anim) $ "#" $ string(Ps[i].State);
	}
	
	return Lines;
}

// Converts a single level packet to string form, for the external file.
function string FormatSingleLevelPacket(LevelPacketStruct Ps)
{
	// Make sure that any packet being formatted into a level packet originally had a valid ID. If it does not, then we need to not make a level packet with that data, since it would otherwise cause an infinite loop
	return string(Ps.ID) $ "#" $ string(Ps.Location) $ "#" $ string(Ps.Rotation) $ "#" $ string(Ps.Health) $ "#" $ string(Ps.Anim) $ "#" $ string(Ps.State);
}

// Converts an array of player packets to string form, for the external file.
function array<string> FormatPlayersPacket(array<PlayersPacketStruct> Ps)
{
	local array<string> Ds;
	local int i;
	
	for(i = 0; i < Ps.Length; i++)
	{
		Ds.Insert(Ds.Length, 1);
		Ds[Ds.Length - 1] = string(Ps[i].ID) $ "#" $ Ps[i].Username $ "#" $ U.BoolToString(Ps[i].bHost);
	}
	
	return Ds;
}

// Converts an array of level packets in string form back into their original form.
function array<LevelPacketStruct> FormatStringLevelPacket(array<string> Ds)
{
	local array<LevelPacketStruct> Ps;
	local array<string> TokenArray;
	local int i, j;
	local bool bTranslated;
	
	for(i = 0; i < Ds.Length; i++)
	{
		Ps.Insert(Ps.Length, 1);
		
		bTranslated = false;

		TokenArray = U.Split(Ds[i], "#");
		
		if(TokenArray.Length != 6)
		{
			class'S2MVersion'.static.DebugLog("Level data packet is not formatted correctly, prepare for issues...");
		}
		
		// Confirm actor ID is present for client.
		Ps[i].ID = Actor(FindObject(TokenArray[0], class'Actor'));

		// This block of code is responsible for dynamically spawning actors if needed.
		if(Ps[i].ID == none)
		{
			if(!IsHost)
			{
				// Check to see if we've seen a pointer come from the host that needed translation.
				for(j = 0; j < Translators.Length; j++)
				{
					if(Translators[j].HostPtr == TokenArray[0])
					{
						// If we're here, we've previously dealt with this pointer, so let's translate it! :D
						Ps[i].ID = Actor(FindObject(Translators[j].ClientPtr, class'Actor'));

						bTranslated = true;

						if(Ps[i].ID == none)
						{
							class'S2MVersion'.static.DebugLog("A translation error in interpreting a level data packet failed, minor issues will occur!");
						}

						break;
					}
				}
			}
			else
			{
				class'S2MVersion'.static.DebugLog("Received a packet as the host that somehow has an invalid ID, this could be fatal!");
			}

			if(!bTranslated)
			{
				class'S2MVersion'.static.DebugLog("Received an unknown level data packet, ignoring...");

				continue;
			}
		}
		
		Ps[i].Location = vector(TokenArray[1]);
		Ps[i].Rotation = rotator(TokenArray[2]);
		Ps[i].Health = float(TokenArray[3]);
		Ps[i].Anim = U.SName(TokenArray[4]);
		Ps[i].State = U.SName(TokenArray[5]);
	}
	
	return Ps;
}

// Converts an array of level packets in string form back into their original form.
function LevelPacketStruct FormatSingleTokenArrayLevelPacket(array<string> TokenArray)
{
	local LevelPacketStruct Ps;
	local int j;
	local bool bTranslated;
	
	bTranslated = false;
		
	if(TokenArray.Length != 6)
	{
		class'S2MVersion'.static.DebugLog("Level data packet is not formatted correctly, prepare for issues...");
	}

	// Confirm actor ID is present for client.
	Ps.ID = Actor(FindObject(TokenArray[0], class'Actor'));

	// This block of code is responsible for dynamically spawning actors if needed.
	if(Ps.ID == none)
	{
		if(!IsHost)
		{
			// Check to see if we've seen a pointer come from the host that needed translation.
			for(j = 0; j < Translators.Length; j++)
			{
				if(Translators[j].HostPtr == TokenArray[0])
				{
					// If we're here, we've previously dealt with this pointer, so let's translate it! :D
					Ps.ID = Actor(FindObject(Translators[j].ClientPtr, class'Actor'));

					bTranslated = true;

					if(Ps.ID == none)
					{
						class'S2MVersion'.static.DebugLog("A translation error in interpreting a level data packet failed, minor issues will occur!");
					}

					break;
				}
			}
		}
		else
		{
			class'S2MVersion'.static.DebugLog("Received a packet as the host that somehow has an invalid ID, this could be fatal!");
		}

		if(!bTranslated)
		{
			class'S2MVersion'.static.DebugLog("Received an unknown level data packet, ignoring...");
		}
	}
	
	Ps.Location = vector(TokenArray[1]);
	Ps.Rotation = rotator(TokenArray[2]);
	Ps.Health = float(TokenArray[3]);
	Ps.Anim = U.SName(TokenArray[4]);
	Ps.State = U.SName(TokenArray[5]);
	
	return Ps;
}

// Takes an actor pointer in string form and a level packet, then returns an actor if any actor near where the actor string pointer was supposed to be is there.
function Actor MissingLevelPacketID(string ID, LevelPacketStruct Ps)
{
	local Actor A;
	local name nClass;
	local array<string> TokenArray;

	// !? This logic might be unnecessary, unsure.
	
	TokenArray = U.Split(ID, ".");
	
	if(TokenArray.Length == 2)
	{
		nClass = U.SName(string(StringActorPointerToClass(TokenArray[1])));
	}
	else
	{
		nClass = U.SName(string(StringActorPointerToClass(TokenArray[0])));
	}
	
	foreach RadiusActors(class'Actor', A, MissingLevelPacketIDRadiusCheckSize, Ps.Location)
	{
		if(A.IsA(nClass))
		{
			return A;
		}
	}
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

// Converts an array of player packets in string form back into their original form.
function array<PlayersPacketStruct> FormatStringPlayersPacket(array<string> Ds)
{
	local array<PlayersPacketStruct> Ps;
	local array<string> TokenArray;
	local int i, j;
	local bool bTranslated;
	
	for(i = 0; i < Ds.Length; i++)
	{
		Ps.Insert(Ps.Length, 1);
		
		TokenArray = U.Split(Ds[i], "#");
		
		if(TokenArray.Length != 3)
		{
			class'S2MVersion'.static.DebugLog("Player data packet is not formatted correctly, issues may arise...");
		}

		// Confirm actor ID is present for client.
		Ps[i].ID = Actor(FindObject(TokenArray[0], class'Actor'));

		// This block of code is responsible for dynamically spawning actors if needed.
		if(Ps[i].ID == none)
		{
			if(!IsHost)
			{
				// Check to see if we've seen a pointer come from the host that needed translation.
				for(j = 0; j < Translators.Length; j++)
				{
					if(Translators[j].HostPtr == TokenArray[0])
					{
						// If we're here, we've previously dealt with this pointer, so let's translate it! :D
						Ps[i].ID = Actor(FindObject(Translators[j].ClientPtr, class'Actor'));

						bTranslated = true;

						if(Ps[i].ID == none)
						{
							class'S2MVersion'.static.DebugLog("A translation error in interpreting a player data packet failed, minor issues will occur!");
						}

						break;
					}
				}
			}
			else
			{
				class'S2MVersion'.static.DebugLog("Received a packet as the host that somehow has an invalid ID, this could be fatal!");
			}

			if(!bTranslated)
			{
				class'S2MVersion'.static.DebugLog("Received an unknown player data packet, ignoring...");

				continue;
			}
		}
		
		Ps[i].ID = Actor(FindObject(TokenArray[0], class'Actor'));
		Ps[i].Username = TokenArray[1];
		Ps[i].bHost = bool(TokenArray[2]);
	}
	
	return Ps;
}

// A simple translation debug function that may be helpful to some.
function TranslatorDebug()
{
	local int i;

	for(i = 0; i < Translators.Length; i++)
	{
		class'S2MVersion'.static.DebugLog("Translator" @ string(i) $ ": Host is" @ Translators[i].HostPtr $ ", client is" @ Translators[i].ClientPtr);
	}
}


defaultproperties
{
	bStatic=false
}