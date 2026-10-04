# steamos-config: webterm

## What it is

webterm gives you a real shell in the browser. It runs
[ttyd](https://github.com/tsl0922/ttyd), a single static binary (about
1.3 MB) that serves an [xterm.js](https://xtermjs.org/) page and connects it
to your shell. systemd starts it the first time you open the page and stops
it once no browser has been connected for 30 s.

There is nothing to compile and no Node, npm, Python or root access needed.
That's handy on SteamOS, where the root filesystem is read-only.

## How it works

```
browser ⇄ 127.0.0.1:3000 ──► webterm.socket            (always listening)
                              │ first connection starts
                              ▼
                             webterm.service          systemd-socket-proxyd
                              │ --exit-idle-time=30s
                              ▼ $XDG_RUNTIME_DIR/webterm.sock
                             webterm-ttyd.service     ttyd ⇄ pty ⇄ your shell
```

- **`webterm.socket`** listens on `127.0.0.1:3000`. It's the only part that
  runs all the time, and systemd itself does the listening.
- **`webterm.service`** runs `systemd-socket-proxyd`, which ships with
  systemd. ttyd can't take over a socket that systemd opened, so the proxy
  takes it and forwards each connection to ttyd. After 30 s with no open
  connections, the proxy exits. That covers both a closed tab and a page
  that never connected.
- **`webterm-ttyd.service`** runs ttyd on a UNIX socket in your private
  runtime directory, so other local users can't reach it. It has
  `StopWhenUnneeded=yes`, so it stops when the proxy exits. The socket keeps
  listening, so your next visit starts everything again.
- ttyd pings each browser every 10 s, so dead connections (a browser crash,
  a laptop suspend) get closed and the idle timer can run.

A backend is needed because a web page can't start processes. Only a local
program can start a shell and attach it to a terminal.

## Requirements

All of these come with a stock SteamOS or Arch install:

- Linux with systemd (including `/usr/lib/systemd/systemd-socket-proxyd`)
- `git`, `curl`, `sha256sum`
- x86_64 or aarch64 (the CPU types ttyd publishes static builds for)
- Optional: `tmux` for [tmux mode](#tmux-mode)

## Quick start

```sh
./setup.sh                 # download ttyd, install the units, enable the socket
./setup.sh --tmux          # same, but the shell runs inside tmux
./setup.sh --no-service    # just download ttyd
```

When it finishes, it prints your URL, which looks like
`http://localhost:3000/<token>/`. Bookmark it. The token is explained in
[Security](#security).

`setup.sh` works out which checkout to use:

- If you run it from inside a steamos-config checkout (or run the copy inside
  one), it uses that checkout.
- Otherwise it clones the repo to `~/git/steamos-config`. If that clone
  already exists, it updates it with `git pull --ff-only` and uses it.

`WEBTERM_CLONE_DIR` and `WEBTERM_REPO_URL` override the clone location and
URL. If the repo is private, cloning needs your GitHub credentials (for
example an SSH URL in `WEBTERM_REPO_URL`).

What gets installed:

- **ttyd:** `scripts/fetch-ttyd.sh` downloads ttyd 1.7.7 to `bin/ttyd`
  (git ignores it) and checks it against a pinned SHA-256.
- **Units:** they go into `~/.config/systemd/user/`. Everything stays in
  your home directory, so SteamOS updates don't remove it.

To install or remove just the units:

```sh
bash scripts/install-systemd.sh
bash scripts/uninstall-systemd.sh
```

## Configuration

| Setting      | Where                                                     | Default            |
| ------------ | --------------------------------------------------------- | ------------------ |
| Idle timeout | `WEBTERM_IDLE` in `webterm.service`                       | `30s`              |
| Tmux mode    | `WEBTERM_TMUX=1` in `webterm-ttyd.service`                | off                |
| URL token    | `WEBTERM_TOKEN` in `~/.config/webterm/env`                | random, 32 hex     |
| Port         | `ListenStream` in `systemd/webterm.socket`                | `127.0.0.1:3000`   |

Change the environment settings with a drop-in, for example:

```sh
systemctl --user edit webterm.service       # [Service] Environment=WEBTERM_IDLE=5min
```

To change the port, edit `systemd/webterm.socket` and re-run
`scripts/install-systemd.sh`. After editing the token, stop the service
(`systemctl --user stop webterm.service`). The next visit then uses the new
token.

## Security

**This is a full shell running as your user.** Anyone who can use the page
can do anything you can.

- It only listens on `127.0.0.1`, and ttyd itself sits on a UNIX socket that
  only your user can open.
- ttyd's `-O` rejects WebSocket connections whose `Origin` doesn't match the
  page's own host.
- `-O` alone doesn't stop DNS rebinding, where a malicious site's domain
  resolves to 127.0.0.1 so the browser treats it as the same origin. That's
  what the random URL token is for. ttyd only serves the terminal under
  `/<token>/` and answers 404 everywhere else, so such a page can't find it.
  Keep the token private, like a password. Setting `WEBTERM_TOKEN=` (empty)
  turns this protection off.
- Don't expose it beyond localhost (port forwarding, reverse proxy,
  `0.0.0.0`) without real authentication and TLS.

## Tmux mode

In tmux mode, each connection runs `tmux new-session -A -s web` instead of a
bare shell. Closing the tab only detaches, and the next visit reattaches to
the same session. The tmux server outlives webterm's idle exit, so running
programs keep going.

`./setup.sh --tmux` sets this up for you. To do it by hand, run
`systemctl --user edit webterm-ttyd.service` and add:

```ini
[Service]
Environment=WEBTERM_TMUX=1
```

## Upgrading from the Node.js version

Re-run `./setup.sh`. The unit names stay the same, so it overwrites the old
units. You can then delete the leftover `node_modules/` folder.

## Testing

```sh
python3 test/smoke.py
```

The test needs no running systemd. `systemd-socket-activate` stands in for
`webterm.socket`, and the real ttyd and `systemd-socket-proxyd` do the rest.
It checks that:

- the page is only served under the token,
- a cross-origin WebSocket is rejected,
- a shell command round-trips, and
- the proxy exits once idle.

It doesn't cover `webterm-ttyd.service` stopping with the proxy, because that
step needs a real systemd.

## Possible future work

Authentication beyond the URL token, TLS, and multi-user support are out of
scope for now.

## License

MIT. See [LICENSE](LICENSE). ttyd is MIT-licensed by its authors and is
downloaded from its GitHub releases, not stored in this repo.
