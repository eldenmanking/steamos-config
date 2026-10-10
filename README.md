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
- `git`, `curl`, `sha256sum`, `tar`, `xz`
- x86_64 or aarch64 (the CPU types ttyd publishes static builds for)
- Optional: `tmux`, to [keep work running](#keeping-work-with-tmux)

## Quick start

```sh
./setup.sh                 # font + ttyd, install the units, enable the socket
./setup.sh --no-font       # skip installing JetBrainsMono Nerd Font
./setup.sh --no-service    # just download ttyd (and the font)
./setup.sh --no-home-units # skip the sudo step for encrypted homes
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

- **Font:** `scripts/fetch-font.sh` installs JetBrainsMono Nerd Font
  (Nerd Fonts v3.4.0, the same release your dotfiles use) into
  `~/.local/share/fonts/JetBrainsMonoNerdFont/`, after checking its SHA-256.
  It does nothing if `fc-list` already lists the font.
- **ttyd:** `scripts/fetch-ttyd.sh` downloads ttyd 1.7.7 to `bin/ttyd`
  (git ignores it) and checks it against a pinned SHA-256.
- **Units:** they go into `~/.config/systemd/user/`. Everything stays in
  your home directory, so SteamOS updates don't remove it. With an encrypted
  home directory, also see [Encrypted home directory](#encrypted-home-directory-dirlock).

To install or remove just the units:

```sh
bash scripts/install-systemd.sh     # also restarts it if running
bash scripts/uninstall-systemd.sh
```

## Configuration

| Setting      | Where                                                     | Default            |
| ------------ | --------------------------------------------------------- | ------------------ |
| Idle timeout | `WEBTERM_IDLE` in `webterm.service`                       | `30s`              |
| Font         | `WEBTERM_FONT` in `webterm-ttyd.service` or the env file  | JetBrainsMono Nerd Font Mono |
| URL token    | `WEBTERM_TOKEN` in `~/.config/webterm/env`                | random, 32 hex     |
| Port         | `ListenStream` in `systemd/webterm.socket`                | `127.0.0.1:3000`   |

Change the environment settings with a drop-in, for example:

```sh
systemctl --user edit webterm.service       # [Service] Environment=WEBTERM_IDLE=5min
```

To change the port, edit `systemd/webterm.socket`. After any change, apply it
as described in [Applying changes](#applying-changes).

## Applying changes

```sh
bash scripts/restart.sh
```

You don't need to close the browser. The script:

1. re-renders the units from the repo (so edited templates and a `git pull`
   take effect),
2. reloads systemd, and
3. restarts the proxy and ttyd, but only if they're running. If they aren't,
   the next visit starts them with the new settings anyway.

`~/.config/webterm/env` is read again on every start, so changes there apply
too.

Open tabs show "Reconnecting..." and come back by themselves with the new
settings (font, title and so on), without a page reload. Each tab gets a
**fresh shell**, so anything running in a bare shell ends. tmux sessions
survive; see [Keeping work with tmux](#keeping-work-with-tmux).

The exception is the token. After changing it, open the new URL; tabs still
on the old one can't reconnect.

## Font

The terminal uses **JetBrainsMono Nerd Font Mono** by default. The Mono
variant draws Nerd Font icons one cell wide, so prompts line up in the grid.

How it works:

- ttyd's `-t key=value` passes any option straight to xterm.js, so the unit
  runs `-t "fontFamily=${WEBTERM_FONT}"`. No custom build is needed.
- The page only names the font. The browser draws it from fonts installed
  on the machine it runs on, which is the Deck here. That's why `setup.sh`
  installs the font. Flatpak browsers (the default on SteamOS) should also
  see `~/.local/share/fonts`.
- If the browser was already open when the font was installed, restart it.
  Until then it uses the next font in the list.

To use a different font, add it to `~/.config/webterm/env` and restart.
Open tabs switch fonts when they reconnect:

```sh
echo 'WEBTERM_FONT=JetBrainsMonoNL Nerd Font Mono, monospace' >> ~/.config/webterm/env
bash scripts/restart.sh
```

The value can be any CSS font list without an `=`. Run
`fc-list : family | grep -i nerd` to see the exact names that are installed.

## Encrypted home directory (dirlock)

With an encrypted home directory, webterm doesn't start after a reboot. The
user manager (`systemd --user`) starts before dirlock unlocks the home
directory, so it can't see `~/.config/systemd/user` and skips
`webterm.socket`. `systemctl --user status webterm.socket` then shows
`inactive (dead)` with no log entries for this boot.

`home-units.service` fixes this for every unit in your home directory, not
just webterm, in Game Mode and Desktop Mode. It is the one piece installed
outside your home directory, so the scripts must run as root. `setup.sh`
installs it for you (asking for your sudo password) when your home directory
is encrypted, and reinstalls it when the repo has a newer version, unless
you pass `--no-home-units`. To do it by hand:

```sh
sudo bash scripts/install-home-units.sh
sudo bash scripts/uninstall-home-units.sh
```

What it installs:

Everything this repo adds to `/etc` is named after it (`steamos-config`),
except the unit itself, which must sit where systemd looks for units:

- `/etc/systemd/user/home-units.service`, enabled for all users. Each user
  manager sees it while the home directory is still locked. It runs
  `/etc/steamos-config/home-units-start` (from `bin/home-units-start`), which
  waits until `~/.config` is readable and runs `systemctl --user daemon-reload`.
  Then, for each `~/.config/systemd/user/<target>.wants/` (and `.requires/`)
  whose target is already up, it starts the units linked there. Nothing else is started, so
  SteamOS's own units that already ran aren't run again. A target that isn't
  up yet, like `graphical-session.target` before Desktop Mode, starts its units
  itself later.
- `/etc/atomic-update.conf.d/steamos-config.conf`, a keep list. Since SteamOS
  3.6 an update drops every change in `/etc` that isn't on a keep list (into
  `/etc/previous`). The default list, `/usr/lib/rauc/atomic-update-keep.conf`,
  covers `/etc/systemd/system` but not `/etc/systemd/user`, so this one names
  the unit, its enablement symlink and `/etc/steamos-config/home-units-start`.

Which units it starts is up to you: `systemctl --user enable foo.service`
adds a link under the target named in the unit's `WantedBy=`, and
`systemctl --user disable` removes it. `journalctl --user -b -u home-units`
shows what it started this boot.

To check it after a reboot: `systemctl --user status home-units.service`
should be `active (exited)` and `webterm.socket` `active (listening)`. To test
that it survives an update, switch branches and update
(`sudo steamos-select-branch beta && sudo steamos-atomupd-client`), reboot,
and check that `/etc/systemd/user/home-units.service` is still there.

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

## Keeping work with tmux

Bare shells are disposable. A bare shell ends when you close its tab, when
webterm stops on idle, and when you run `scripts/restart.sh`.

To keep something running, start `tmux` in the terminal. The tmux server
survives all three, and you reattach with `tmux attach` on your next visit.

Why the tmux server survives: everything started from webterm, including a
tmux server, belongs to `webterm-ttyd.service`. By default systemd kills all
of a service's processes when it stops. The unit sets `KillMode=process`, so
on stop systemd signals only ttyd. ttyd then hangs up its shells, which ends
them. tmux detaches and keeps running.

When the service next starts, systemd logs a "left-over process" notice about
the tmux server. That's expected.

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
