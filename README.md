# steamos-config: webterm

## What it is

webterm gives you a real shell in the browser. The page uses
[xterm.js](https://xtermjs.org/) for the terminal and talks to a small Node.js
server. The server runs your shell in a pseudo-terminal (`node-pty`). systemd
socket activation starts the server the first time you open the page, and the
server exits by itself once no browser tab is connected, so it uses no
resources while you aren't using it.

## How it works

```
browser (xterm.js)  ⇄  WebSocket /term  ⇄  Node server  ⇄  pty  ⇄  your shell
```

- The browser renders the terminal. It sends keystrokes and resize events as
  JSON over a WebSocket and writes whatever comes back.
- The Node server serves the static page, including xterm.js from
  `node_modules` (no CDN, no bundler). For each WebSocket it spawns one
  shell in a pty and relays bytes both ways.
- The backend is required because a web page cannot spawn processes. Only a
  local program can start a shell and attach it to a terminal.

## Requirements

- Linux with systemd
- Node.js >= 18
- Build tools for `node-pty`, which compiles a native module on install.
  On Arch: `sudo pacman -S base-devel python nodejs npm`

## Quick start

```sh
npm install && npm start
```

Then open <http://localhost:3000>.

### One-shot setup script

`setup.sh` is self-contained. It writes every project file, runs `npm ci`,
installs the systemd units and checks that the socket answers. You can copy
this one file to a machine and run it without cloning the repo:

```sh
./setup.sh                 # installs to ~/webterm and enables the socket
./setup.sh --dir ~/apps/webterm --tmux
./setup.sh --no-service    # files + npm install only
```

It checks for Node, npm and the build tools before it changes anything.
`setup.sh` is generated, so don't edit it by hand. After you change a source
file, run `bash scripts/gen-setup.sh` to rebuild it.

## Run on demand (systemd)

```sh
npm run service:install
```

This installs two **user** units into `~/.config/systemd/user/`:

- `webterm.socket` listens on `127.0.0.1:3000` and is enabled at login.
- `webterm.service` has no `[Install]` section. On the first connection,
  systemd starts it and passes it the already-open socket.

The server exits (code 0) after `IDLE_MS` with zero WebSocket connections.
That includes the case where it started but no page ever connected. The
socket keeps listening, so your next visit starts the server again.
A ping/pong heartbeat every 10 s drops dead connections, for example after a
browser crash or laptop suspend.

To remove the units:

```sh
npm run service:uninstall
```

## Configuration

| Variable       | Default | Meaning                                         |
| -------------- | ------- | ----------------------------------------------- |
| `PORT`         | `3000`  | Port for `npm start` and the allowed `Origin`   |
| `IDLE_MS`      | `30000` | Exit after this long with no connections        |
| `WEBTERM_TMUX` | unset   | `1` runs the shell inside tmux (see below)      |

To change the port for the systemd setup, you also need to edit
`ListenStream` in `systemd/webterm.socket` and set `PORT` in the service
(so the Origin check matches). Then re-run the installer.

## Security

**This is a full shell running as your user.** Anyone who can use the page
can do anything you can.

- The server binds to `127.0.0.1` only.
- It rejects WebSocket connections whose `Origin` isn't
  `http://localhost:<PORT>` or `http://127.0.0.1:<PORT>`. This stops other
  websites from reaching your shell, but it also means you must open the page
  through `http://localhost:<PORT>`, not from a `file://` URL.
- Don't expose it beyond localhost (port forwarding, reverse proxy,
  `0.0.0.0`) without adding authentication and TLS.

## Tmux mode

With `WEBTERM_TMUX=1`, each connection runs `tmux new-session -A -s web`
instead of a bare shell. Closing the tab only detaches, and the next visit
reattaches to the same session. The tmux server outlives webterm's idle
exit, so running programs keep going.

For the systemd service, run `systemctl --user edit webterm.service` and add:

```ini
[Service]
Environment=WEBTERM_TMUX=1
```

(`./setup.sh --tmux` writes this drop-in for you.)

## SteamOS notes

SteamOS is Arch-based, so the Arch instructions apply, with two caveats:

- The root filesystem is read-only, and the build tools and headers aren't
  installed. To get them you need something like
  `sudo steamos-readonly disable`, then `sudo pacman-key --init`,
  `sudo pacman-key --populate archlinux holo`, and
  `sudo pacman -S base-devel python nodejs npm`. SteamOS updates wipe these
  changes. **These steps were not tested on a Steam Deck.**
- The user systemd units live in your home directory, so they survive
  updates. Only the system packages need reinstalling.

## Testing

```sh
npm test
```

The test starts the server on port 3999 with `IDLE_MS=4000` and checks three
things: a bad `Origin` is rejected, a shell command round-trips, and the
server exits with code 0 once idle.

## Possible future work

Authentication, TLS, multi-user support, and Windows/macOS support are out
of scope for now.

## License

MIT. See [LICENSE](LICENSE).
