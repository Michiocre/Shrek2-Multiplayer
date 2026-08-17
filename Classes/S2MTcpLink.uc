class S2MTcpLink extends TcpLink;

var string ServerHost;
var int ServerPort;
var string TestMessage;
var bool bWaitingForConnection;

function Connect(string Host, int Port, string Message)
{
    ServerHost = Host;
    ServerPort = Port;
    TestMessage = Message;

    LinkMode = MODE_Text;
    ReceiveMode = RMODE_Event;

    Resolve(ServerHost);
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

    SendText(TestMessage $ Chr(13) $ Chr(10));
    class'S2MVersion'.static.DebugLog("TCP test message queued for" @ ServerHost $ ":" $ string(ServerPort) $ ".");
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
    class'S2MVersion'.static.DebugLog("TCP received:" @ Text);
}

event Closed()
{
    bWaitingForConnection = false;
    class'S2MVersion'.static.DebugLog("TCP connection closed before or after opening to" @ ServerHost $ ":" $ string(ServerPort) $ ".");
    Destroy();
}