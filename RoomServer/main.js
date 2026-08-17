import net from 'net';
import crypto from 'crypto';

// List of rooms
let rooms = {};

const ConState = {
    NOTHING: 'nothing',
    HOST: 'host',
    CLIENT: 'client',
};

function getUsernames(room) {
    const names = room.clients.map(x => x.s2m.username) ?? [];
    names.push(room.host.s2m.username);

    return names;
}

const server = net.createServer((socket) => {
    socket.s2m = {
        state: ConState.NOTHING,
        roomName: '',
        username: '',
    } 

    socket.on('data', (data) => {
        const message = data.toString().trim();
        const messageParts = message.split(':');

        const command = messageParts[0];
        const username = messageParts[1];

        switch (command) {
            case 'create':
                if (socket.s2m.state === ConState.NOTHING) {
                    const roomName = "AAAA" || crypto.randomBytes(4).toString('hex').toUpperCase();;
                    socket.s2m.state = ConState.HOST;
                    socket.s2m.roomName = roomName;
                    socket.s2m.username = username;
                    rooms[roomName] = {
                        host: socket,
                        clients: [],
                    };
                    console.log(`${socket.s2m.roomName}: created`);
                    socket.write(`created:${socket.s2m.roomName}`);
                }
                else {
                    socket.write(`error:room exists:${socket.s2m.roomName}`);
                }
                break;
            case 'connect':
                if (socket.s2m.state === ConState.NOTHING) {
                    let roomName = messageParts[2]?.toUpperCase();
                    let room = rooms[roomName];
                    if (!room) {
                        socket.write(`error:room does not exist:${socket.s2m.roomName}`);
                        return;
                    }

                    console.log(getUsernames(room));

                    if (getUsernames(room).includes(username)) {
                        socket.write(`error:username taken:${username}`);
                        return;
                    }
                    
                    socket.s2m.state = ConState.CLIENT;
                    socket.s2m.roomName = roomName;
                    socket.s2m.username = username;
                    room.clients.push(socket);

                    console.log(`${socket.s2m.roomName}: user ${username} connected`);
                    room.host.write(`connect:${username}`);
                }
                break;
            case 'route':
                let room = rooms[socket.s2m.roomName];
                if (!getUsernames(room).includes(username)) {
                    socket.write(`error:username not found:${username}`);
                    return;
                }
                client.write(messageParts.slice(2));
                break;
            default:
                if (socket.s2m.state === ConState.NOTHING) {
                    socket.write(`error:not connected`);
                }
                if (socket.s2m.state === ConState.HOST) {
                    for (let client of rooms[socket.s2m.roomName].clients) {
                        client.write(message);
                    }
                }
                if (socket.s2m.state === ConState.CLIENT) {
                    rooms[socket.s2m.roomName].host.write(message);
                }
        }
    });

    socket.on('end', () => {
        console.log(`${socket.s2m.roomName}: user ${socket.s2m.username} disconnected`);
        if (socket.s2m.state === ConState.HOST) {
        }
    });
});

server.listen(6400, () => {
    console.log('Server listening on port 6400');
});
