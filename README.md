# Shrek 2 Multiplayer
In this new implementation the UE2 mod itself will handle the main networking work.
The RoomServer will only be used to allow people to connect with each other without forwarding ports and has to only be hosted in one central location.

### Normal Mode:
Every client connects with the host directly, the host gets packages from every player and works through them every tick. And then sends the responses.

### Room Server Mode:
The host connects to the RoomServer using a create command and gets back a room code.
The clients conenct to the RoomServer using the room code.

The RoomServer forwards all packages from the client to the server and the other way.

## Protocol:
### Room Server
`create:{name}` | Host -> RoomServer | Creates a new room and sets this connection as the host.  
`connect:{name}:{room}:{default_connect_values}}` | Client -> RoomServer | Connects to a room and sets this user as a client then forwards the normal `connect` command with all the other values to host.
`error:{message}:{data}` | RoomServer -> Host or RoomServer -> Client | Hostserver sends a errormessage to a user with a message and some additional data.

### Normal Mode
`connect:{name}` | Client -> Host or RoomServer -> Host | Client asks for a connection from the host.