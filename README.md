# Rice Center

A native KDE app that shows every part of the [kde-rice](../kde-rice) setup with its live state and lets you
turn features on and off, change their settings, switch the whole desktop look (rice / stock KDE / the original
pre-rice look) and restore snapshots. Plus an **Everyday** page of quality-of-life settings (sounds, volume step,
lock and screen-off timing, lid action, touchpad, Caps Lock, Night Light, single-click, animation speed…).

> **Built with [Claude](https://claude.com/claude-code).** This app (the `rice-ctl` backend, the Kirigami
> window, the launcher and these docs) was designed, written and tested by Claude, Anthropic's AI assistant,
> working in Claude Code at the owner's direction. The owner chose the features and reviewed the result.

## What the app does

Open it with **Meta+Alt+R**, from the app menu (Settings → Rice Center), or `rice-center` in KRunner.

| Page | What you can do there |
|---|---|
| **Overview** | Run the rice health check (summary or full report), turn on **Lite mode** (blur, rounded corners and window animations off for this session, for games or heavy work), restart Plasma, open the how-to and ideas files, sync the repos. |
| **Everyday** | Quality-of-life settings: turn **all sounds** off or just one kind (volume-change pop, device plug, charger/battery, warnings, dialogs and beep, login/logout, password prompt, trash, timers and alarms); volume step and volume above 100 %; when the screen locks or turns off, locking after sleep, what closing the lid does; Night Light; centered new windows, focus follows mouse, single-click to open, animation speed, which apps open at login; touchpad tap-to-click, natural scrolling and ignore-while-typing; NumLock at login, Caps Lock as Esc or Ctrl; file indexing and recent files. |
| **Look** | Colour scheme, Rice Plasma style, rounded corners, blur, window animations, GTK apps matching KDE, login splash, lock-screen wallpaper, sound theme. |
| **Wallpaper** | Day/night wallpaper switching and the wallpaper mood. |
| **Windows & keys** | Tiling (Karousel), Snap Layouts, Scratchpad, the rice's global shortcuts, drop-down terminal at login, top-bar auto-hide. |
| **Focus & time** | Focus mode (Pomodoro), Awake (keep the PC awake for 1/2/4 h or until off), StandBy night clock, Screen Time and its reminders. |
| **Sound & power** | Power Saver tie-in, automatic power profile, Brave GPU video decoding, battery charge limit. |
| **Maintenance** | Notices after KDE updates, monthly speed check, keeping GTK styles in sync. |
| **Looks & backups** | Switch the whole desktop to **stock KDE** or to the **original look from before the ricing**, and **back to the rice**; take a snapshot or restore any earlier one. |

Every card shows the feature's current state. A **?** button opens its how-to, and the search box finds any feature.


## How it is built

| Part | What it does |
|---|---|
| `rice-ctl` | Python CLI (system `python3`, dbus-python). The feature registry and all the work: `list [--json]`, `get`, `on`/`off`, `set`, `action`, `help`, `look`. Uses the documented on/off commands of the rice (systemd user units, KWin effects/scripts, kglobalaccel shortcuts, `kwriteconfig6 --notify` + reload hooks, the `rice-*` scripts). |
| `center/main.qml` | The window: Kirigami + KirigamiAddons FormCard (same widgets as System Settings), run by `qml-qt6 --apptype widget`, so it uses the Darkly style. Runs `rice-ctl` through Plasma's P5Support "executable" engine and only displays the JSON. Nothing to compile. |
| `rice-center` | Launcher: opens the app, or brings the open window to the front. `--shot file.png [page]` renders a page to a PNG and quits (for checks). |
| `rice-center.desktop` | App-menu entry (Settings), global shortcut **Meta+Alt+R**. |

Everything the app does also works from a terminal: `rice-ctl list`, `rice-ctl on blur`, `rice-ctl set vol-step 10`,
`rice-ctl look stock`, `rice-ctl look rice`.

## Requirements

Plasma 6, `qml-qt6` (qt6-qtdeclarative-devel), KirigamiAddons, Plasma's plasma5support QML module, python3-dbus,
and the kde-rice scripts in `~/kde-rice/bin` (rice-ctl drives them).

## Install (from the kde-rice repo)

`install.sh` links `rice-ctl`, `rice-center` and the desktop entry. By hand:

```sh
ln -s ~/kde-rice/bin/rice-ctl ~/kde-rice/bin/rice-center ~/.local/bin/
ln -s ~/kde-rice/bin/rice-center.desktop ~/.local/share/applications/
ln -s ~/kde-rice/bin/rice-center.desktop ~/.local/share/kglobalaccel/   # Meta+Alt+R after the next login
```

## Safety

- Switching the look is reversible: a snapshot is taken first (`rice-backup`) and no files are deleted.
- Restoring a snapshot saves the current state first.
- Nothing runs with sudo silently; such actions open Konsole so the password prompt is visible.
