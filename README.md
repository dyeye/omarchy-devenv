# 󱁐 Omarchy DevEnv

> Local development mission control for **Omarchy / Hyprland**, built with **Quickshell (QML & JavaScript)**.

Omarchy DevEnv consolidates port management, Docker containers, Git repository health, and an offline developer toolbox into a single native status bar widget and popout panel.

---

## 󰈚 Overview & Walkthrough

Omarchy DevEnv eliminates context switching and resolves daily development friction on Arch Linux.

![DevEnv Hero Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/hero-preview.png)

---

## 󱥸 Core Features

### 1. 󰒋 Dev Ports & Server Pilot
Never get stuck on `EADDRINUSE: 3000` or wonder what is holding a port again.

![Ports Tab Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/ports-tab.png)

* **Live Detection:** Real-time scanning of all listening local TCP sockets (`127.0.0.1`, `0.0.0.0`, `::1`).
* **Process Attribution:** Identifies the binary (`node`, `vite`, `python`, `cargo`, `docker-proxy`, etc.) and PID.
* **󰐊 Open in Browser:** 1-click launch of `http://localhost:<port>` in your default browser.
* **󰆏 Copy URL:** Instant clipboard copy (`wl-copy`).
* **󰅖 Kill Process:** Instant `SIGTERM` / `SIGKILL` by PID or port number to immediately free stuck sockets.

---

### 2.  Docker & Container Management
Inspect and control local containers and database dependencies without opening a terminal.

![Docker Tab Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/docker-tab.png)

* **Container Overview:** Visual state indicators (󰄳 Running, 󰑐 Restarting, 󰅖 Exited).
* **Container Lifecycle:** Direct **Start**, **Stop**, and **Restart** actions per container.
* **Quick Compose:** Automatically detects `docker-compose.yml` in the active project directory with 1-click **Compose Up** and **Down** buttons.
* **󰈙 Embedded Logs Viewer:** Inspect the last 40 lines of container output and stack traces in-panel.

---

### 3.  Git Radar & Workspace Context
Stay on top of uncommitted work and remote synchronization across all your projects.

![Git Tab Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/git-tab.png)

* **Smart Context Tracking:** Automatically detects your active repository based on the focused terminal or editor in Hyprland.
* **Branch & Commit Metadata:** Displays the current branch name, last commit summary, and upstream status (󰁝 ahead / 󰁅 behind).
* **Work Tracker:** Live counters for staged (`+X`), modified (`~Y`), and untracked (`?Z`) files.
* **Quick Launchers:**
  * 󰘐 **Lazygit:** Launches `lazygit` in a floating window inside the project directory.
  *  **Terminal:** Launches your configured terminal (`foot`, `kitty`, `ghostty`, `alacritty`).
  * 󰈙 **Editor:** Opens the project in `$EDITOR` (`code`, `cursor`, `nvim`).

---

### 4. 󰞋 Offline Developer Toolbox
Essential developer utilities available in milliseconds without third-party web tools.

![Toolbox Tab Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/toolbox-tab.png)

* **`{ }` JSON Formatter & Minifier:** Clean formatting with 2-space indentation and validation error reporting.
* **󱁤 Timestamp Converter:** Bidirectional conversion between UNIX Epoch (seconds/milliseconds) and formatted ISO / local dates.
* **󰮔 Base64 & URL:** Offline UTF-8 string encoding and decoding.
* **󰌠 UUID v4 Generator:** Instant cryptographic UUID generation with 1-click clipboard copy.

---

## 󰋜 Bar Widget Integration

The status bar widget provides a compact, ambient readout:

![Bar Widget Preview](https://raw.githubusercontent.com/dyeye/omarchy-devenv/main/assets/screenshots/bar-widget.png)

* **Active Project & Port Count:** `󱁐 󰒋3`
* **Interaction:**
  * **Left Click:** Toggles the main DevEnv popout panel.
  * **Right Click:** Forces an immediate background scan of ports, Docker, and Git.

---

## 󰌌 Installation & Setup

### Prerequisites
* Omarchy Linux with Quickshell
* Hyprland compositor
* Optional tools: `docker`, `git`, `lazygit`, `ss`, `jq`

### Install Plugin
Clone into your user plugin directory:

```bash
mkdir -p ~/.config/omarchy/plugins
git clone https://github.com/dyeye/omarchy-devenv.git ~/.config/omarchy/plugins/dyeye.devenv
```

### Place in Omarchy Bar
Add the widget to your status bar layout:

```bash
omarchy bar put dyeye.devenv --before omarchy.agents
```

### Hyprland Keybinding (Optional)
Add a shortcut in `~/.config/hypr/bindings.lua` to toggle the panel:

```lua
o.bind("$mainMod, D, exec, omarchy-shell shell toggle dyeye.devenv")
```

---

## 󰉋 Project Structure

```text
~/.config/omarchy/plugins/dyeye.devenv/
├── manifest.json              # Omarchy Quattro plugin contract
├── BarWidget.qml              # Status bar pill component
├── Panel.qml                  # Main popout panel host
├── Model.js                   # State parsers and dev utilities
├── tabs/
│   ├── PortsTab.qml           # Port scanner and process killer
│   ├── DockerTab.qml          # Container controls and logs viewer
│   ├── GitTab.qml             # Git radar and quick launchers
│   └── ToolboxTab.qml         # Offline JSON, Base64, Time, UUID tools
└── helpers/
    ├── devenv-scan.sh         # Sub-50ms system scanner
    └── devenv-action.sh       # Process, Docker, and browser runner
```

---

## 󰈚 License

MIT License. Developed for Omarchy Linux.
