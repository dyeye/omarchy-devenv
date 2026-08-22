# 󱁐 Omarchy DevEnv

> Local development mission control for **Omarchy / Hyprland**, built with **Quickshell (QML & JavaScript)**.

Omarchy DevEnv consolidates real-time port inspection, Docker container lifecycle controls, Git repository & GitHub radar, and an offline developer toolbox into a native status bar widget and popout panel.

---

## 󰈚 Architecture & Workflow

Omarchy DevEnv is engineered for low latency and zero context switching:

1. **Sub-50ms System Scanning (`devenv-scan.sh`):** Scans active Hyprland window focus, listening TCP ports (`ss`), local Docker daemon state (`docker ps`), active Git repository status (`git log`, `git status`, `git branch`, `git stash`), and GitHub CLI data (`gh pr list`, `gh issue list`).
2. **Reactive UI State (`Model.js`):** Parses raw outputs into structured reactive JavaScript models consumed by Qt Quick / Quickshell delegates.
3. **Safe Async Action Dispatcher (`devenv-action.sh`):** Executes port termination, Docker lifecycle, git checkout, and browser URLs in the background without blocking the UI thread.
4. **Native Omarchy Bar Integration:** Implements the official `bar-widget` popout coordinator contract, supporting sequential panel navigation (`Super + Ctrl + <number>`) and `Tab` / `Shift+Tab` switching.

---

## 󱥸 Core Modules

### 1. 󰒋 Ports & Server Pilot
Detect and manage local development servers and listening sockets.

* **Live TCP Port Discovery:** Detects all active listening TCP ports on `127.0.0.1`, `0.0.0.0`, and `::1`.
* **Process Attribution:** Identifies binary names (`node`, `vite`, `python`, `cargo`, `docker-proxy`, etc.) and system PIDs.
* **󰐊 Open in Browser:** 1-click launch of `http://localhost:<port>` in your default browser.
* **󰆏 Copy URL:** Instant clipboard copy with rich hover tooltips.
* **󰅖 Process Terminator:** Safe `SIGTERM` / `SIGKILL` by PID to instantly release stuck sockets.

---

### 2.  Docker & Compose Manager
Monitor and control local containers and database dependencies without opening a terminal.

* **Container Health Indicators:** Real-time state badges (󰄳 Running, 󰑐 Restarting, 󰅖 Exited).
* **Safe Confirmation Popups:** Interactive Yes / No confirmation dialogs before Stop, Restart, and Compose Down actions to prevent accidental downtime.
* **Quick Compose Pilot:** Automatically detects `docker-compose.yml` in the active project directory with 1-click **Compose Up** and **Down**.
* **󰈙 Embedded Logs Viewer:** Expandable drawer to inspect recent container stdout/stderr logs and stack traces.

---

### 3.  Git Radar & GitHub Hub
Comprehensive repository tracking, multi-branch switching, and GitHub integration.

* **Active Workspace Tracking:** Automatically detects Git repositories based on the focused terminal or editor in Hyprland.
* **󰊢 Interactive Branch Switcher:** Active branch pill (`󰊢 <branch> 󰅂`) with an anchored dropdown listing all local and remote tracking branches, executing automated `git checkout` on click.
* **󰜘 Commit History:** Recent commits with short SHA badge (1-click clipboard copy), author, relative date, and hover marquee scrolling for long messages.
* ** GitHub Pull Requests:** Lists open PRs (`#<number> <title>`) with author info, target branches, 1-click browser launchers, and "Create PR" shortcut.
* ** GitHub Issues:** Displays open repository issues with author details, direct browser links, and "Create Issue" shortcut.
* **󰅖 Git Stashes Manager:** View saved stashes with 1-click `Pop` action (`git stash pop`).
* **󱁤 Smart Hover Marquee:** Long commit messages, PR titles, and issue titles remain neatly truncated (`...`) in rest state and scroll smoothly on hover.
* **Quick Launchers:**
  *  **GitHub Web:** Opens the remote repository in the browser.
  * 󰘐 **Lazygit:** Launches `lazygit` in a floating terminal within the repo.
  *  **Terminal:** Opens your default terminal (`ghostty`, `kitty`, `foot`, `alacritty`).
  * 󰈙 **Editor:** Opens the project in your configured code editor.
  * 󰑐 **Fetch:** Fetches upstream remote updates.

---

### 4. 󰞋 Offline Developer Toolbox
Essential utilities that work offline without third-party web converters.

* **`{ }` JSON Formatter & Minifier:** Format with clean indentation or minify into single-line strings with live syntax error reporting.
* **󱁤 Timestamp Converter:** Bidirectional conversion between UNIX Epoch timestamps (seconds / milliseconds) and formatted ISO / local dates.
* **󰮔 Base64 & URL:** Offline UTF-8 string encoding and decoding.
* **󰌠 UUID v4 Generator:** Instant cryptographic UUID generation with 1-click clipboard copy.

---

### 5. 󰋜 Omarchy Bar Widget & Keyboard Shortcuts

* **Ambient Bar Readout:** Displays active project name and open port counter (`󱁐 󰒋3`).
* **Mouse Controls:**
  * **Left Click:** Toggles the DevEnv panel anchored to the widget icon.
  * **Right Click:** Forces an immediate background scan and refresh.
* **Keyboard Navigation:**
  * **`Super + Ctrl + <number>`:** Directly opens or switches to DevEnv based on its position in the bar.
  * **`Tab` / `Shift+Tab`:** Cycles forward and backward to adjacent Omarchy bar panels.
  * **`Escape`:** Dismisses the panel.

---

## 󰌌 Installation & Configuration

### Prerequisites
* Omarchy Linux with Quickshell
* Hyprland compositor
* Optional tools: `docker`, `git`, `gh` (GitHub CLI), `lazygit`, `ss`, `jq`

### 1. Install Plugin
Clone the repository into your Omarchy user plugins directory:

```bash
git clone https://github.com/dyeye/omarchy-devenv.git ~/.config/omarchy/plugins/dyeye.devenv
```

### 2. Add to Omarchy Bar
Place the widget in your bar configuration:

```bash
omarchy bar put dyeye.devenv --before omarchy.agents
```

Or manually add `dyeye.devenv` into `~/.config/omarchy/shell.json` inside the `bar.layout.right` section.

### 3. Custom Hyprland Keybinding (Optional)
To bind a direct dedicated key combination (e.g. `Super + D`), edit `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + D", "DevEnv Panel", "omarchy-shell -q shell toggle dyeye.devenv")
```

---

## 󰉋 Project File Hierarchy

```text
~/.config/omarchy/plugins/dyeye.devenv/
├── manifest.json              # Omarchy bar-widget plugin contract
├── BarWidget.qml              # Status bar pill component & popout host
├── Panel.qml                  # Main popout panel window & key navigation
├── Model.js                   # State parsers, dev toolbox math & path utilities
├── tabs/
│   ├── PortsTab.qml           # TCP port scanner & process terminator
│   ├── DockerTab.qml          # Containers list, safe popups & logs drawer
│   ├── GitTab.qml             # Git radar, branch switcher, GitHub PRs/Issues & stashes
│   └── ToolboxTab.qml         # Offline JSON, Base64, Time & UUID tools
└── helpers/
    ├── devenv-scan.sh         # Background scanner for ports, docker, git & gh
    └── devenv-action.sh       # Async runner for docker, git, processes & browser
```

---

## 󰈚 License

MIT License. Designed and crafted for Omarchy Linux.
