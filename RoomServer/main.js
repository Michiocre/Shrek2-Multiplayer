import net from 'net';
import crypto from 'crypto';

// List of rooms
let rooms = {};

const ConState = {
    NOTHING: 'nothing',
    HOST: 'host',
    CLIENT: 'client',
}

const server = net.createServer((socket) => {
    socket.s2m = {
        state: ConState.NOTHING,
        roomName: '',
    } 

    socket.on('data', (data) => {
        const message = data.toString().trim();
        const messageParts = message.split(':');

        const command = messageParts[0];

        switch (command) {
            case 'create':
                if (socket.s2m.state === ConState.NOTHING) {
                    const roomName = crypto.randomBytes(4).toString('hex').toUpperCase();
                    socket.s2m.state = ConState.HOST;
                    socket.s2m.roomName = roomName;
                    rooms[roomName] = {
                        host: socket,
                        clients: [],
                    };
                    socket.write(`created:${socket.s2m.roomName}`);
                }
                else {
                    socket.write(`error:room exists:${socket.s2m.roomName}`);
                }
                break;
            case 'connect':
                if (socket.s2m.state === ConState.NOTHING) {
                    let roomName = messageParts[2].toUpperCase();
                    let room = rooms[roomName];
                    if (room) {
                        socket.s2m.state = ConState.CLIENT
                        socket.s2m.roomName = roomName
                        room.clients.push(socket);

                        room.host.write(`connect:${messageParts.slice(2).join(':')}`);
                    } else {
                        socket.write(`error:room does not exist:${socket.s2m.roomName}`);
                    }
                }
                break;
            default:
                if (socket.s2m.state === ConState.NOTHING) {
                    socket.write(`error:not connected)`);
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
        if (socket.s2m.state === ConState.HOST) {
        }
    });
});

server.listen(3000, () => {
    console.log('Server listening on port 3000');
});