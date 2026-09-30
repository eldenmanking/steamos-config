const os = require('os');
const http = require('http');
const express = require('express');
const { WebSocketServer } = require('ws');
const pty = require('node-pty');

const PORT = Number(process.env.PORT) || 3000;
const HOST = '127.0.0.1';
const IDLE_MS = Number(process.env.IDLE_MS) || 30_000;
const HEARTBEAT_MS = 10_000;
const ALLOWED_ORIGINS = new Set([
  `http://localhost:${PORT}`,
  `http://127.0.0.1:${PORT}`,
]);

const app = express();
app.use(express.static('public'));
app.use('/vendor/xterm', express.static('node_modules/@xterm/xterm'));
app.use('/vendor/fit', express.static('node_modules/@xterm/addon-fit'));

const server = http.createServer(app);
const wss = new WebSocketServer({ server, path: '/term' });

// --- idle shutdown: exit when no connections for IDLE_MS ---
let idleTimer = null;
function armIdleTimer() {
  clearTimeout(idleTimer);
  idleTimer = setTimeout(() => {
    if (wss.clients.size === 0) {
      console.log('No connections, exiting.');
      process.exit(0);
    }
  }, IDLE_MS);
}
armIdleTimer(); // covers "page loaded but never connected"

function spawnShell() {
  const env = { ...process.env, TERM: 'xterm-256color' };
  const opts = {
    name: 'xterm-256color',
    cols: 80,
    rows: 24,
    cwd: os.homedir(),
    env,
  };
  if (process.env.WEBTERM_TMUX === '1') {
    return pty.spawn('tmux', ['new-session', '-A', '-s', 'web'], opts);
  }
  const shell = process.env.SHELL || os.userInfo().shell || 'bash';
  return pty.spawn(shell, [], opts);
}

wss.on('connection', (ws, req) => {
  // Stop other websites from reaching this local shell
  if (!ALLOWED_ORIGINS.has(req.headers.origin)) {
    ws.close();
    return;
  }

  clearTimeout(idleTimer);
  const term = spawnShell();

  ws.isAlive = true;
  ws.on('pong', () => (ws.isAlive = true));

  term.onData((data) => {
    if (ws.readyState === ws.OPEN) ws.send(data);
  });
  term.onExit(() => ws.close());

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw);
    } catch {
      return;
    }
    if (msg.type === 'input' && typeof msg.data === 'string') {
      term.write(msg.data);
    } else if (msg.type === 'resize') {
      const cols = Math.max(1, Math.min(500, Number(msg.cols) || 80));
      const rows = Math.max(1, Math.min(200, Number(msg.rows) || 24));
      term.resize(cols, rows);
    }
  });

  ws.on('close', () => {
    term.kill();
    armIdleTimer();
  });
});

// Heartbeat: terminate connections that stopped answering pings
setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.isAlive === false) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    ws.ping();
  }
}, HEARTBEAT_MS);

// systemd socket activation passes the listening socket as fd 3
if (process.env.LISTEN_FDS) {
  server.listen({ fd: 3 }, () => console.log('Listening on systemd socket'));
} else {
  server.listen(PORT, HOST, () => console.log(`Listening on http://localhost:${PORT}`));
}
