const term = new Terminal({ cursorBlink: true, fontFamily: 'monospace' });
const fit = new FitAddon.FitAddon();
term.loadAddon(fit);
term.open(document.getElementById('terminal'));
fit.fit();

const ws = new WebSocket(`ws://${location.host}/term`);
const send = (obj) => ws.readyState === WebSocket.OPEN && ws.send(JSON.stringify(obj));

ws.onopen = () => send({ type: 'resize', cols: term.cols, rows: term.rows });
ws.onmessage = (e) => term.write(e.data);
ws.onclose = () => term.write('\r\n\x1b[31m[connection closed - reload to reconnect]\x1b[0m\r\n');

term.onData((data) => send({ type: 'input', data }));

window.addEventListener('resize', () => {
  fit.fit();
  send({ type: 'resize', cols: term.cols, rows: term.rows });
});
