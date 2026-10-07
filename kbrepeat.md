# Keyboard repeat in Big Picture

Big Picture can leave the keyboard with a different repeat delay and rate
than you want. `kbrepeat.service` sets your values each time it opens.

## How it works

`bin/kbrepeat-watch` runs `xprop -root -spy _NET_ACTIVE_WINDOW`, which prints
a line every time the active window changes. When the newly active window is
titled `Steam Big Picture Mode`, it runs `xset r rate <delay> <rate>`. Steam
may change the values again just after its window shows, so the script applies
them a second time 2 s later.

This happens each time Big Picture becomes active, including when you switch
back to it from another window. Nothing is polled; the script just waits for
X to report a change.

The service is a systemd user service tied to `graphical-session.target`, so
it starts and stops with your desktop session. If the X server goes away, the
script exits and systemd starts it again after 5 s.

## Requirements

- An X11 session (SteamOS Desktop Mode). On Wayland, `xset` only changes
  XWayland, not the compositor's keyboard settings.
- `xprop` and `xset`, which come with SteamOS and most Arch desktops.

## Install

```sh
bash scripts/install-kbrepeat.sh     # also restarts it if running
bash scripts/uninstall-kbrepeat.sh
```

The unit goes into `~/.config/systemd/user/` and runs the script from this
checkout, so keep the checkout where it is (or re-run the install script after
moving it).

## Configuration

By default it uses the delay and rate from KDE's keyboard settings
(`~/.config/kcminputrc`), so Big Picture matches the desktop. If KDE has none
saved, it uses the X defaults, 600 ms and 25/s.

To pick other values, put them in `~/.config/kbrepeat/env`:

```sh
mkdir -p ~/.config/kbrepeat
cat > ~/.config/kbrepeat/env <<'END'
KBREPEAT_DELAY=250
KBREPEAT_RATE=40
END
bash scripts/install-kbrepeat.sh
```

| Setting           | Meaning                                        | Default                  |
| ----------------- | ---------------------------------------------- | ------------------------ |
| `KBREPEAT_DELAY`  | ms before a held key starts repeating          | KDE's, else `600`        |
| `KBREPEAT_RATE`   | repeats per second                             | KDE's, else `25`         |
| `KBREPEAT_TITLE`  | Big Picture window title to watch for          | `Steam Big Picture Mode` |
| `KBREPEAT_SETTLE` | seconds before applying the values again       | `2`                      |

## Checking it

```sh
systemctl --user status kbrepeat.service
journalctl --user -u kbrepeat.service -f     # logs "Set key repeat: ..."
xset q | grep 'repeat delay'
```

If nothing is logged when Big Picture opens, check the window's title with
`xprop _NET_WM_NAME` and clicking the Big Picture window, then set
`KBREPEAT_TITLE` to match.
