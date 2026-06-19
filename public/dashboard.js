class RokuDashboard {
    constructor() {
        this.ws = null;
        this.logs = [];
        this.autoScroll = true;
        this.filterLevel = '';
        this.stats = {
            connected: false,
            uptime: 0,
            messagesReceived: 0,
            errorsCount: 0,
            warningsCount: 0,
            lastConnected: null,
            connectionAttempts: 0,
        };

        this.initElements();
        this.initEventListeners();
        this.connectWebSocket();
        this.startStatsTimer();
    }

    initElements() {
        this.statusDot = document.getElementById('statusDot');
        this.statusText = document.getElementById('statusText');
        this.logsPanel = document.getElementById('logsPanel');
        this.clearLogsBtn = document.getElementById('clearLogsBtn');
        this.reconnectBtn = document.getElementById('reconnectBtn');
        this.pauseBtn = document.getElementById('pauseBtn');
        this.filterSelect = document.getElementById('filterLevel');
        this.statMessages = document.getElementById('statMessages');
        this.statErrors = document.getElementById('statErrors');
        this.statWarnings = document.getElementById('statWarnings');
        this.statUptime = document.getElementById('statUptime');
        this.logCount = document.getElementById('logCount');
    }

    initEventListeners() {
        this.clearLogsBtn.addEventListener('click', () => this.clearLogs());
        this.reconnectBtn.addEventListener('click', () => this.reconnect());
        this.pauseBtn.addEventListener('click', () => this.toggleAutoScroll());
        this.filterSelect.addEventListener('change', (e) => this.setFilter(e.target.value));
    }

    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}`;

        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
            console.log('Connected to dashboard server');
        };

        this.ws.onmessage = (event) => {
            const message = JSON.parse(event.data);

            switch (message.type) {
                case 'initial':
                    this.stats = message.stats;
                    this.logs = message.logs;
                    this.renderAllLogs();
                    this.updateStats();
                    break;

                case 'log':
                    this.logs.push(message.data);
                    this.addLogEntry(message.data);
                    break;

                case 'status':
                    this.stats = message.stats;
                    this.updateStatus(message.status);
                    this.updateStats();
                    break;
            }
        };

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.updateStatus('error');
        };

        this.ws.onclose = () => {
            console.log('Disconnected from server');
            this.updateStatus('disconnected');
            setTimeout(() => this.connectWebSocket(), 3000);
        };
    }

    updateStatus(status) {
        const statusMap = {
            connected: { text: 'Connected', class: 'connected', color: '#10b981' },
            disconnected: { text: 'Disconnected', class: '', color: '#ef4444' },
            error: { text: 'Connection Error', class: '', color: '#ef4444' },
        };

        const statusInfo = statusMap[status] || statusMap.disconnected;
        this.statusText.textContent = statusInfo.text;
        this.statusDot.className = `status-dot ${statusInfo.class}`;
        this.statusDot.style.background = statusInfo.color;
    }

    addLogEntry(log) {
        if (this.shouldShowLog(log.level)) {
            const entry = this.createLogElement(log);
            this.logsPanel.appendChild(entry);
            this.updateLogCount();

            if (this.autoScroll) {
                this.logsPanel.scrollTop = this.logsPanel.scrollHeight;
            }
        }
    }

    renderAllLogs() {
        this.logsPanel.innerHTML = '';
        this.logs.forEach((log) => {
            if (this.shouldShowLog(log.level)) {
                const entry = this.createLogElement(log);
                this.logsPanel.appendChild(entry);
            }
        });
        if (this.autoScroll) {
            this.logsPanel.scrollTop = this.logsPanel.scrollHeight;
        }
        this.updateLogCount();
    }

    createLogElement(log) {
        const entry = document.createElement('div');
        entry.className = 'log-entry';
        entry.dataset.level = log.level;

        const timestamp = document.createElement('span');
        timestamp.className = 'log-timestamp';
        timestamp.textContent = new Date(log.timestamp).toLocaleTimeString('en-US', {
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            fractionalSecondDigits: 3,
        });

        const level = document.createElement('span');
        level.className = `log-level ${log.level}`;
        level.textContent = log.level.toUpperCase();

        const message = document.createElement('span');
        message.className = 'log-message';
        if (log.level === 'error') message.classList.add('error');
        if (log.level === 'warning') message.classList.add('warning');
        message.textContent = log.message;

        entry.appendChild(timestamp);
        entry.appendChild(level);
        entry.appendChild(message);

        return entry;
    }

    shouldShowLog(level) {
        return !this.filterLevel || level === this.filterLevel;
    }

    setFilter(level) {
        this.filterLevel = level;
        this.renderAllLogs();
    }

    updateStats() {
        this.statMessages.textContent = this.stats.messagesReceived.toLocaleString();
        this.statErrors.textContent = this.stats.errorsCount.toLocaleString();
        this.statWarnings.textContent = this.stats.warningsCount.toLocaleString();
        this.statUptime.textContent = this.formatUptime(this.stats.uptime);
    }

    formatUptime(ms) {
        if (ms <= 0) return '--:--:--';

        const totalSeconds = Math.floor(ms / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    updateLogCount() {
        const visibleCount = this.logsPanel.querySelectorAll('.log-entry').length;
        this.logCount.textContent = `${visibleCount} ${visibleCount === 1 ? 'log' : 'logs'}`;
    }

    toggleAutoScroll() {
        this.autoScroll = !this.autoScroll;
        this.pauseBtn.textContent = this.autoScroll ? 'Pause Auto-scroll' : 'Resume Auto-scroll';
        this.pauseBtn.style.background = this.autoScroll ? '' : 'rgba(239, 68, 68, 0.2)';

        if (this.autoScroll) {
            this.logsPanel.scrollTop = this.logsPanel.scrollHeight;
        }
    }

    clearLogs() {
        if (confirm('Clear all logs?')) {
            fetch('/api/clear-logs', { method: 'POST' })
                .then((res) => res.json())
                .then(() => {
                    this.logs = [];
                    this.renderAllLogs();
                });
        }
    }

    reconnect() {
        fetch('/api/reconnect', { method: 'POST' })
            .then((res) => res.json())
            .then(() => {
                console.log('Reconnect initiated');
            })
            .catch((err) => console.error('Reconnect failed:', err));
    }

    startStatsTimer() {
        setInterval(() => {
            if (this.stats.connected) {
                this.stats.uptime += 1000;
                this.updateStats();
            }
        }, 1000);
    }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    new RokuDashboard();
});
