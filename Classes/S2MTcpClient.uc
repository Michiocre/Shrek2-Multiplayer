class S2MTcpClient extends TcpLink;

var string ServerHost;
var int ServerPort;
var bool bWaitingForConnection;
var bool IsHost;
var string Username;
var S2MDataAgg S2MDA;
var string RoomCode;

function Init(S2MDataAgg InS2MDA) {
    S2MDA = InS2MDA;
}

function CreateServer(string Host, int Port, string Name)
{
    Connect(Host, Port, Name, true, "");
}

function ConnectToServer(string Host, int Port, string Name, string Code)
{
    Connect(Host, Port, Name, false, Code);
}

function Connect(string Host, int Port, string Name, bool startServer, string Code)
{
    ServerHost = Host;
    ServerPort = Port;
    IsHost = startServer;
    Username = Name;
    RoomCode = Code;

    LinkMode = MODE_Text;
    ReceiveMode = RMODE_Event;

    Resolve(ServerHost);
}

function Disconnect() {
    Close();
    Destroy();
}

event Resolved(IpAddr Addr)
{
    Addr.Port = ServerPort;

    class'S2MVersion'.static.DebugLog("TCP host resolved as" @ IpAddrToString(Addr) $ "; opening connection.");

    if (BindPort() == 0)
    {
        class'S2MVersion'.static.DebugLog("TCP client socket could not be created.");
        Destroy();
        return;
    }

    if (!Open(Addr))
    {
        class'S2MVersion'.static.DebugLog("TCP connection could not be opened.");
        Destroy();
    }
    else
    {
        bWaitingForConnection = true;
        SetTimer(10.0, false);
        class'S2MVersion'.static.DebugLog("TCP open request accepted; waiting for handshake.");
    }
}

event ResolveFailed()
{
    class'S2MVersion'.static.DebugLog("TCP host resolution failed for" @ ServerHost $ ".");
    Destroy();
}

event Opened()
{
    bWaitingForConnection = false;
    SetTimer(0.0, false);
    class'S2MVersion'.static.DebugLog("TCP connection opened.");

    if (IsHost) {
        SendText("create:" $ Username);
        class'S2MVersion'.static.DebugLog("TCP test message sent to start server" @ ServerHost $ ":" $ string(ServerPort) $ ".");
    } else {
        SendText("connect:" $ Username $ ":" $ RoomCode );
        class'S2MVersion'.static.DebugLog("TCP test message sent to connect to server" @ ServerHost $ ":" $ string(ServerPort) $ ".");
    }

}

event Timer()
{
    if (bWaitingForConnection)
    {
        class'S2MVersion'.static.DebugLog("TCP connection timed out; no server completed the handshake.");
        Close();
        Destroy();
    }
}

event ReceivedText(string Text)
{
	local array<string> TokenArray;
    local string Name;
    local string CombinedMesage;
    local int i;

    class'S2MVersion'.static.DebugLog("TCP received:" @ Text);
    TokenArray = S2MDA.U.Split(Text, ":");
    Name = TokenArray[1];

    switch(TokenArray[0])
    {
        case "chat":
            CombinedMesage = TokenArray[2];
            if (TokenArray.length >= 4) {
                for (i = 3; i < TokenArray.length; i++)
                {
                    CombinedMesage = CombinedMesage @ ":" @ TokenArray[i];
                }
            }
            S2MDA.DisplayChatMessage(Name, CombinedMesage);
            break;
        case "error":
            S2MDA.DisplayChatMessage("Error Message", TokenArray[2] @ ":" @ TokenArray[3]);
            break;
        case "connect": // Fires when the server gets connect request
            SendText(S2MDA.ClientConnected(Name));
            break;
        case "connected": // Fires when the client gets connected message
            S2MDA.ConnectToServer(Name, TokenArray[2]);
            break;
        case "created": // Fires when the server gets create request
            S2MDA.DisplayChatMessage("Server", "created" @ TokenArray[1]);
            break;
        case "playerData": // Fires when anyone recieves player data
            if (Name == Username) {
                break;
            }

            S2MDA.HandlePlayerData(TokenArray);
            break;
        default:
            S2MDA.DisplayChatMessage("Unknown Message", Text);
            break;
    }
}

event Closed()
{
    bWaitingForConnection = false;
    class'S2MVersion'.static.DebugLog("TCP connection closed before or after opening to" @ ServerHost $ ":" $ string(ServerPort) $ ".");
    Destroy();
}

defaultproperties
{
    bTravel=true
}
