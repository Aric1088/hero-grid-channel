# Roku Dashboard

A web-based dashboard that maintains a persistent telnet connection to your Roku TV and displays real-time logs, metrics, and system status.

## Features

✨ **Real-time Telnet Connection**
- Persistent connection to Roku TV
- Automatic reconnection with exponential backoff
- Connection status indicator

📊 **Live Metrics**
- Message count
- Error/Warning tracking
- Connection uptime
- Connection attempts

🎨 **Web Dashboard**
- Beautiful, responsive UI
- Color-coded log levels (Error, Warning, Info, Debug)
- Real-time log streaming via WebSocket
- Auto-scrolling with pause control
- Log filtering by level
- One-click log clearing

🔌 **REST API**
- `/api/stats` - Get current statistics
- `/api/logs` - Fetch all logs
- `/api/clear-logs` - Clear log history
- `/api/reconnect` - Force reconnection

## Setup

### 1. Install Dependencies
```powershell
npm install
```

### 2. Configure Roku IP (Optional)
Create a `.env` file from the example:
```powershell
Copy-Item .env.example .env
```

Edit `.env` with your Roku IP and port:
```
ROKU_IP=192.168.1.155
ROKU_PORT=8085
DASHBOARD_PORT=3000
```

### 3. Start the Dashboard
```powershell
npm run dashboard:dev
```

Or with environment variables:
```powershell
npm run dashboard
```

### 4. Open in Browser
Navigate to: `http://localhost:3000`

## How It Works

### Server (`dashboard-server.js`)
- Creates persistent TCP socket connection to Roku
- Parses incoming telnet data into structured log entries
- Maintains connection with automatic reconnection logic
- Broadcasts logs to all connected web clients via WebSocket
- Tracks statistics (errors, warnings, message count, uptime)

### Client (`public/dashboard.js`)
- WebSocket connection to server
- Real-time log rendering with syntax highlighting
- Live statistics updates
- Filtering and search capabilities
- Auto-scrolling with manual pause control

## Configuration

All configuration via environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `ROKU_IP` | `192.168.1.155` | Roku TV IP address |
| `ROKU_PORT` | `8085` | Roku telnet debug port |
| `DASHBOARD_PORT` | `3000` | Web dashboard port |

## Log Levels

Logs are automatically categorized:

- **ERROR** - Contains "ERROR" or "error"
- **WARNING** - Contains "WARNING" or "warning"
- **INFO** - Stream URLs, Magnet links
- **DEBUG** - Response codes, POST requests
- **LOG** - Generic log entries

## Keyboard Shortcuts

- **Filter by level** - Use the dropdown menu
- **Clear logs** - Click "Clear Logs" button
- **Pause/Resume** - Click "Pause Auto-scroll" button
- **Reconnect** - Click "Reconnect" button

## Troubleshooting

### Can't connect to Roku?
1. Verify Roku IP: Check `ROKU_IP` in dashboard or `.env`
2. Enable Developer Mode on Roku
3. Ensure Roku is powered on and on same network
4. Check port 8085 is open: `Test-NetConnection -ComputerName 192.168.1.155 -Port 8085`

### Dashboard shows "Disconnected"
- Check your network connection
- Verify Roku hasn't gone to sleep
- Restart Roku and try reconnecting

### No logs appearing?
1. Check browser console for errors (F12)
2. Verify WebSocket connection is open
3. Try clicking "Reconnect" button
4. Check Roku is actually sending debug logs

## Advanced Usage

### Multiple Dashboards
Start multiple instances with different ports:
```powershell
# Terminal 1
$env:DASHBOARD_PORT = 3000; npm run dashboard:dev

# Terminal 2
$env:DASHBOARD_PORT = 3001; npm run dashboard:dev
```

### Production Deployment
```powershell
npm run dashboard
```

Set environment variables before running or in your hosting platform.

### Log Persistence
Logs are kept in memory (max 500 entries). To extend:
Edit `dashboard-server.js` line 15:
```javascript
const MAX_BUFFER = 1000;  // Increase buffer size
```

## Architecture

```
┌─────────────────────────────────────┐
│     Roku TV (Port 8085)             │
│  Telnet Debug Protocol              │
└────────────┬────────────────────────┘
             │ TCP Socket
             │
┌────────────▼────────────────────────┐
│   dashboard-server.js               │
│  • TCP Connection                   │
│  • Log Parsing                      │
│  • Statistics Tracking              │
│  • Express Server                   │
└────────────┬────────────────────────┘
             │ WebSocket
      ┌──────┴──────┐
      │             │
  ┌───▼──────┐  ┌──▼────────┐
  │ Browser  │  │  Browser   │
  │ Tab 1    │  │  Tab 2     │
  └──────────┘  └────────────┘
```

## Performance Notes

- Logs kept in memory: ~500 entries (configurable)
- WebSocket messages: Real-time with minimal latency
- CPU usage: Minimal (single TCP connection)
- Memory: ~30-50 MB (Node.js + logs)

## Future Enhancements

- [ ] SQLite log persistence
- [ ] Log export/download functionality
- [ ] Advanced filtering and search
- [ ] Dark/Light mode toggle
- [ ] Log retention policy
- [ ] Multi-Roku support
- [ ] Custom alert rules
- [ ] Log archiving
