const { spawn } = require('child_process');
const WebSocket = require('ws');

const PORT = 3999;
const server = spawn('node', ['server.js'], {
  env: { ...process.env, PORT: String(PORT), IDLE_MS: '4000' },
  stdio: 'inherit',
});

const fail = (msg) => {
  console.error('FAIL:', msg);
  server.kill();
  process.exit(1);
};

const connect = (origin) =>
  new WebSocket(`ws://127.0.0.1:${PORT}/term`, { headers: { Origin: origin } });

function testBadOrigin(next) {
  const ws = connect('http://evil.example');
  let gotData = false;
  ws.on('message', () => (gotData = true));
  ws.on('error', () => {});
  const t = setTimeout(() => fail('bad origin was not closed'), 3000);
  ws.on('close', () => {
    clearTimeout(t);
    if (gotData) fail('bad origin received data');
    console.log('ok: bad origin rejected');
    next();
  });
}

function testRoundTrip(next) {
  const ws = connect(`http://localhost:${PORT}`);
  let out = '';
  ws.on('open', () =>
    // arithmetic so the typed echo differs from the command's real output
    ws.send(JSON.stringify({ type: 'input', data: 'echo web$((40+2))term\n' }))
  );
  ws.on('message', (d) => {
    out += d;
    if (out.includes('web42term')) ws.close();
  });
  const t = setTimeout(() => fail('no shell output'), 5000);
  ws.on('close', () => {
    clearTimeout(t);
    if (!out.includes('web42term')) fail('no shell output');
    console.log('ok: shell round-trip');
    next();
  });
}

function testIdleExit() {
  const t = setTimeout(() => fail('server did not exit after idle'), 10000);
  server.on('exit', (code) => {
    clearTimeout(t);
    console.log('ok: server exited when idle, code', code);
    process.exit(code === 0 ? 0 : 1);
  });
}

setTimeout(() => testBadOrigin(() => testRoundTrip(testIdleExit)), 1000);
