const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const net = require('net');
const path = require('path');
const { Resolver } = require('dns').promises;

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Configuration
const ROKU_IP = process.env.ROKU_IP || '192.168.1.155';
const ROKU_PORT = parseInt(process.env.ROKU_PORT || '8085');
const DASHBOARD_PORT = parseInt(process.env.DASHBOARD_PORT || '3000');

// State management
let rokuSocket = null;
let reconnectTimeout = null;
let messageBuffer = [];
const MAX_BUFFER = 500;
let stats = {
    connected: false,
    uptime: 0,
    messagesReceived: 0,
    errorsCount: 0,
    warningsCount: 0,
    lastConnected: null,
    connectionAttempts: 0,
};

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

// REST endpoints
app.get('/api/stats', (req, res) => {
    res.json({
        ...stats,
        uptime: stats.connected ? Date.now() - stats.lastConnected : 0,
    });
});

app.get('/api/logs', (req, res) => {
    res.json(messageBuffer);
});

app.post('/api/clear-logs', (req, res) => {
    messageBuffer = [];
    res.json({ success: true });
});

app.post('/api/reconnect', (req, res) => {
    disconnectRoku();
    connectToRoku();
    res.json({ success: true });
});

// WebSocket connections
wss.on('connection', (ws) => {
    console.log('Dashboard client connected');

    // Send initial state
    ws.send(JSON.stringify({
        type: 'initial',
        stats,
        logs: messageBuffer,
    }));

    ws.on('close', () => {
        console.log('Dashboard client disconnected');
    });
});

// Roku connection management
function connectToRoku() {
    if (rokuSocket) {
        disconnectRoku();
    }

    stats.connectionAttempts++;
    console.log(`[${new Date().toISOString()}] Attempting to connect to Roku at ${ROKU_IP}:${ROKU_PORT} (attempt ${stats.connectionAttempts})`);

    rokuSocket = net.createConnection({
        host: ROKU_IP,
        port: ROKU_PORT,
        family: 4,
        lookup: (hostname, options, callback) => {
            // Bypass DNS - return IP directly as IPv4
            process.nextTick(() => callback(null, hostname, 4));
        }
    });

    rokuSocket.on('connect', () => {
        stats.connected = true;
        stats.lastConnected = Date.now();
        stats.connectionAttempts = 0;
        console.log(`[${new Date().toISOString()}] Connected to Roku`);
        broadcastStatus('connected', { message: 'Connected to Roku' });
    });

    rokuSocket.on('data', (data) => {
        const text = data.toString('utf-8');
        const lines = text.split('\n');

        lines.forEach((line) => {
            if (line.trim()) {
                stats.messagesReceived++;

                // Count errors and warnings
                if (line.includes('ERROR') || line.includes('error')) {
                    stats.errorsCount++;
                } else if (line.includes('WARNING') || line.includes('warning')) {
                    stats.warningsCount++;
                }

                // Add to buffer
                const logEntry = {
                    timestamp: new Date().toISOString(),
                    message: line.trim(),
                    level: determineLogLevel(line),
                };

                messageBuffer.push(logEntry);
                if (messageBuffer.length > MAX_BUFFER) {
                    messageBuffer.shift();
                }

                // Broadcast to all clients
                broadcastLog(logEntry);
            }
        });
    });

    rokuSocket.on('error', (err) => {
        stats.connected = false;
        stats.errorsCount++;
        console.error(`[${new Date().toISOString()}] Roku connection error:`, err.message);
        broadcastStatus('error', { message: err.message });
        scheduleReconnect();
    });

    rokuSocket.on('close', () => {
        if (stats.connected) {
            stats.connected = false;
            console.log(`[${new Date().toISOString()}] Disconnected from Roku`);
            broadcastStatus('disconnected', { message: 'Disconnected from Roku' });
            scheduleReconnect();
        }
    });
}

function disconnectRoku() {
    if (rokuSocket) {
        rokuSocket.destroy();
        rokuSocket = null;
    }
    if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
        reconnectTimeout = null;
    }
    stats.connected = false;
}

function scheduleReconnect() {
    if (reconnectTimeout) {
        clearTimeout(reconnectTimeout);
    }

    // Exponential backoff: 2s, 4s, 8s, 16s, max 60s
    const delay = Math.min(1000 * Math.pow(2, Math.min(stats.connectionAttempts - 1, 5)), 60000);
    console.log(`[${new Date().toISOString()}] Scheduling reconnect in ${delay}ms`);

    reconnectTimeout = setTimeout(() => {
        connectToRoku();
    }, delay);
}

function determineLogLevel(line) {
    if (line.includes('ERROR') || line.includes('error')) return 'error';
    if (line.includes('WARNING') || line.includes('warning')) return 'warning';
    if (line.includes('Stream URL') || line.includes('Magnet')) return 'info';
    if (line.includes('response code') || line.includes('POST')) return 'debug';
    return 'log';
}

function broadcastLog(logEntry) {
    broadcastToClients({
        type: 'log',
        data: logEntry,
    });
}

function broadcastStatus(status, details = {}) {
    broadcastToClients({
        type: 'status',
        status,
        stats,
        ...details,
    });
}

function broadcastToClients(message) {
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify(message));
        }
    });
}

// Start the server
server.listen(DASHBOARD_PORT, () => {
    console.log(`Dashboard running at http://localhost:${DASHBOARD_PORT}`);
    console.log(`Roku target: ${ROKU_IP}:${ROKU_PORT}`);
    connectToRoku();
});

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\nShutting down gracefully...');
    disconnectRoku();
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
