#!/usr/bin/env bash
set -euo pipefail

# Execute the smart Python scanner for ultra-fast, robust detection
python3 - <<'EOF'
import os
import sys
import subprocess
import json
import re

home = os.environ.get("HOME", "/home/dyeye")
search_roots = [
    os.path.join(home, "Projects"),
    os.path.join(home, ".config/omarchy/plugins"),
    os.path.join(home, "projects"),
    os.path.join(home, "workspace"),
    os.path.join(home, "code"),
    os.path.join(home, "Documents/Omarchy/Plugins"),
    os.path.join(home, "Documents")
]

# Helper to find known project from path or name
def resolve_project_dir(path_or_name):
    if not path_or_name:
        return None
    p = os.path.expanduser(str(path_or_name).strip())
    if os.path.isdir(p) and p != home and p != "/":
        try:
            git_root = subprocess.check_output(["git", "-C", p, "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.DEVNULL).strip()
            if git_root and os.path.isdir(git_root):
                return git_root
        except Exception:
            pass
        return p
    name = os.path.basename(p)
    if name and name != "." and name != "..":
        for sroot in search_roots:
            candidate = os.path.join(sroot, name)
            if os.path.isdir(candidate):
                return candidate
    return None

# Helper to find project from any file path
def project_from_filepath(fpath):
    if not fpath:
        return None, None
    real = os.path.realpath(fpath)
    if not real or real == home or real == "/":
        return None, None
    for sroot in search_roots:
        if real.startswith(sroot + "/"):
            rel = real[len(sroot)+1:]
            proj_name = rel.split("/")[0]
            proj_dir = os.path.join(sroot, proj_name)
            if os.path.isdir(proj_dir):
                return proj_name, proj_dir
    # Check git repo root
    try:
        git_dir = real if os.path.isdir(real) else os.path.dirname(real)
        git_root = subprocess.check_output(["git", "-C", git_dir, "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.DEVNULL).strip()
        if git_root and git_root != home and git_root != "/":
            return os.path.basename(git_root), git_root
    except Exception:
        pass
    return None, None

# 1. Determine active project from active window
active_project_path = ""
active_project_name = ""

try:
    hypr_raw = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True, stderr=subprocess.DEVNULL)
    win = json.loads(hypr_raw)
except Exception:
    win = {}

win_title = win.get("title", "")
win_pid = win.get("pid", 0)
win_class = win.get("class", "").lower()

# Check if active window is a terminal or editor
is_terminal_window = any(t in win_class for t in ["foot", "kitty", "alacritty", "ghostty", "wezterm", "terminal", "tmux"]) or "herdr" in win_class

# 1a. For GUI Editors & Apps: Check window title FIRST (e.g. Zed "dyeye.devenv — Panel.qml", VSCode "file - project - Code")
if not is_terminal_window and win_title:
    title_parts = re.split(r"[\s—\-\|:]+", win_title)
    for part in title_parts:
        part = part.strip()
        if not part or part.lower() in {"zed", "visual", "studio", "code", "obsidian", "nvim", "neovim", "panel.qml"}:
            continue
        resolved = resolve_project_dir(part)
        if resolved:
            active_project_path = resolved
            active_project_name = os.path.basename(resolved)
            break

# 1b. If active window is a terminal or multiplexer:
if not active_project_path and is_terminal_window:
    # Check if running herdr
    is_herdr = "herdr" in win_class or "herdr" in win_title.lower()
    if not is_herdr and win_pid > 0:
        try:
            ptree = subprocess.check_output(["pgrep", "-P", str(win_pid)], text=True, stderr=subprocess.DEVNULL).split()
            for p in ptree:
                cmd = open(f"/proc/{p}/cmdline", "rb").read().decode("utf-8", errors="ignore")
                if "herdr" in cmd:
                    is_herdr = True
                    break
        except Exception:
            pass

    if is_herdr:
        try:
            h_raw = subprocess.check_output(["herdr", "pane", "list"], text=True, stderr=subprocess.DEVNULL)
            h_data = json.loads(h_raw)
            panes = h_data.get("result", {}).get("panes", [])
            for p in panes:
                if p.get("focused") is True:
                    h_cwd = p.get("foreground_cwd") or p.get("cwd")
                    p_name, p_dir = project_from_filepath(h_cwd)
                    if p_dir:
                        active_project_name = p_name
                        active_project_path = p_dir
                    elif h_cwd and h_cwd != "/" and h_cwd != home:
                        active_project_name = os.path.basename(h_cwd)
                        active_project_path = h_cwd
                    break
        except Exception:
            pass

    # Check if running tmux
    if not active_project_path:
        is_tmux = "tmux" in win_class or "tmux" in win_title.lower() or os.environ.get("TMUX")
        if is_tmux:
            try:
                t_cwd = subprocess.check_output(["tmux", "display-message", "-p", "-F", "#{pane_current_path}"], text=True, stderr=subprocess.DEVNULL).strip()
                p_name, p_dir = project_from_filepath(t_cwd)
                if p_dir:
                    active_project_name = p_name
                    active_project_path = p_dir
                elif t_cwd and t_cwd != "/" and t_cwd != home:
                    active_project_name = os.path.basename(t_cwd)
                    active_project_path = t_cwd
            except Exception:
                pass

    # Check standard terminal child processes (bash/zsh/fish/nvim running in foot/kitty)
    if not active_project_path and win_pid > 0:
        try:
            children = subprocess.check_output(["pgrep", "-P", str(win_pid)], text=True, stderr=subprocess.DEVNULL).split()
            for cpid in reversed(children):
                c_cwd = os.path.realpath(f"/proc/{cpid}/cwd")
                p_name, p_dir = project_from_filepath(c_cwd)
                if p_dir:
                    active_project_name = p_name
                    active_project_path = p_dir
                    break
        except Exception:
            pass

# 1c. Check open file descriptors of active window process (e.g. Zed / VSCode open files)
if not active_project_path and win_pid > 0:
    try:
        fd_dir = f"/proc/{win_pid}/fd"
        if os.path.exists(fd_dir):
            for fd in os.listdir(fd_dir):
                try:
                    target = os.path.realpath(os.path.join(fd_dir, fd))
                    p_name, p_dir = project_from_filepath(target)
                    if p_dir:
                        active_project_name = p_name
                        active_project_path = p_dir
                        break
                except Exception:
                    pass
    except Exception:
        pass

# 1d. Fallback: try omarchy-cmd-terminal-cwd
if not active_project_path:
    try:
        t_cwd = subprocess.check_output(["omarchy-cmd-terminal-cwd"], text=True, stderr=subprocess.DEVNULL).strip()
        p_name, p_dir = project_from_filepath(t_cwd)
        if p_dir:
            active_project_name = p_name
            active_project_path = p_dir
        elif t_cwd and t_cwd != "/" and t_cwd != home:
            active_project_name = os.path.basename(t_cwd)
            active_project_path = t_cwd
    except Exception:
        pass

# 1g. Ultimate fallback to $HOME
if not active_project_path:
    active_project_path = home
    active_project_name = os.path.basename(home)

# 2. Check stack & docker-compose for active project
has_compose = False
stack_type = "generic"
if os.path.isfile(os.path.join(active_project_path, "package.json")):
    stack_type = "node"
elif os.path.isfile(os.path.join(active_project_path, "Cargo.toml")):
    stack_type = "rust"
elif os.path.isfile(os.path.join(active_project_path, "pyproject.toml")) or os.path.isfile(os.path.join(active_project_path, "requirements.txt")):
    stack_type = "python"
elif os.path.isfile(os.path.join(active_project_path, "go.mod")):
    stack_type = "go"

compose_files = ["docker-compose.yml", "docker-compose.yaml", "compose.yaml", "compose.yml"]
has_compose = any(os.path.isfile(os.path.join(active_project_path, cf)) for cf in compose_files)

# 3. Detect Git status for active project
git_has_repo = False
git_repo_path = ""
git_repo_name = ""
git_branch = ""
git_last_commit = ""
git_dirty = 0
git_staged = 0
git_untracked = 0
git_ahead = 0
git_behind = 0

try:
    git_root = subprocess.check_output(["git", "-C", active_project_path, "rev-parse", "--show-toplevel"], text=True, stderr=subprocess.DEVNULL).strip()
    if git_root:
        git_has_repo = True
        git_repo_path = git_root
        git_repo_name = os.path.basename(git_root)
        active_project_name = git_repo_name

        try:
            git_branch = subprocess.check_output(["git", "-C", git_root, "branch", "--show-current"], text=True, stderr=subprocess.DEVNULL).strip()
            if not git_branch:
                git_branch = subprocess.check_output(["git", "-C", git_root, "rev-parse", "--short", "HEAD"], text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            git_branch = "HEAD"

        try:
            git_last_commit = subprocess.check_output(["git", "-C", git_root, "log", "-1", "--pretty=format:%s"], text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            git_last_commit = ""

        try:
            status_lines = subprocess.check_output(["git", "-C", git_root, "status", "--porcelain"], text=True, stderr=subprocess.DEVNULL).splitlines()
            for sl in status_lines:
                if not sl: continue
                if sl.startswith("??"):
                    git_untracked += 1
                else:
                    if sl[0] in "MADRC":
                        git_staged += 1
                    if len(sl) > 1 and sl[1] in "MADRCU":
                        git_dirty += 1
        except Exception:
            pass

        try:
            upstream = subprocess.check_output(["git", "-C", git_root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], text=True, stderr=subprocess.DEVNULL).strip()
            if upstream:
                counts = subprocess.check_output(["git", "-C", git_root, "rev-list", "--left-right", "--count", f"HEAD...{upstream}"], text=True, stderr=subprocess.DEVNULL).split()
                if len(counts) == 2:
                    git_ahead = int(counts[0])
                    git_behind = int(counts[1])
        except Exception:
            pass
except Exception:
    pass

# 4. Scan listening TCP ports and accurately resolve each to project vs general process
ports = []
general_tools = {"agy", "opencode", "steam", "cupsd", "systemd", "systemd-resolve", "rpcbind", "avahi-daemon", "sshd"}

try:
    ss_raw = subprocess.check_output(["ss", "-tlpn"], text=True, stderr=subprocess.DEVNULL)
    seen_ports = set()

    for line in ss_raw.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 4:
            continue
        local_addr = parts[3]

        addr_parts = local_addr.rsplit(":", 1)
        if len(addr_parts) != 2:
            continue
        port_str = re.sub(r"%.*", "", addr_parts[1])
        if not port_str.isdigit():
            continue
        port = int(port_str)
        if port == 53 or port in seen_ports:
            continue
        seen_ports.add(port)

        ip = addr_parts[0]
        if ip == "" or ip == "*":
            ip = "0.0.0.0"

        pname = "unknown"
        pid = 0
        m = re.search(r"users:\(\(\"([^\"]+)\".*?pid=(\d+)", line)
        if m:
            pname = m.group(1)
            pid = int(m.group(2))
        else:
            m2 = re.search(r"users:\(\(\"([^\"]+)\"", line)
            if m2:
                pname = m2.group(1)

        # Clean process name
        pname = re.sub(r"\s+\(v\d+.*", "", pname)

        cat_type = "process"
        cat_name = "General Processes"
        cat_path = ""

        if pid > 0 and pname.lower() not in general_tools:
            # Check 1: Direct working directory of process
            try:
                proc_cwd = os.path.realpath(f"/proc/{pid}/cwd")
                p_name, p_dir = project_from_filepath(proc_cwd)
                if p_dir:
                    cat_type = "project"
                    cat_name = p_name
                    cat_path = p_dir
            except Exception:
                pass

            # Check 2: Check process cmdline for project paths
            if cat_type != "project":
                try:
                    with open(f"/proc/{pid}/cmdline", "rb") as f:
                        cmdline_str = f.read().replace(b"\x00", b" ").decode("utf-8", errors="ignore")
                    for token in cmdline_str.split():
                        p_name, p_dir = project_from_filepath(token)
                        if p_dir:
                            cat_type = "project"
                            cat_name = p_name
                            cat_path = p_dir
                            break
                except Exception:
                    pass

            # Check 3: Check open file descriptors for project files
            if cat_type != "project":
                try:
                    fd_dir = f"/proc/{pid}/fd"
                    if os.path.exists(fd_dir):
                        for fd in os.listdir(fd_dir):
                            try:
                                target = os.path.realpath(os.path.join(fd_dir, fd))
                                p_name, p_dir = project_from_filepath(target)
                                if p_dir:
                                    cat_type = "project"
                                    cat_name = p_name
                                    cat_path = p_dir
                                    break
                            except Exception:
                                pass
                except Exception:
                    pass

            # Check 4: Check parent process working directories (e.g. shell / editor that spawned node/vite)
            if cat_type != "project":
                try:
                    with open(f"/proc/{pid}/stat", "r") as f:
                        stat_parts = f.read().split()
                        ppid = int(stat_parts[3])
                        if ppid > 1:
                            pproc_cwd = os.path.realpath(f"/proc/{ppid}/cwd")
                            p_name, p_dir = project_from_filepath(pproc_cwd)
                            if p_dir:
                                cat_type = "project"
                                cat_name = p_name
                                cat_path = p_dir
                except Exception:
                    pass

        ports.append({
            "port": port,
            "ip": ip,
            "process": pname,
            "pid": pid,
            "categoryType": cat_type,
            "categoryName": cat_name,
            "categoryPath": cat_path
        })

    ports.sort(key=lambda x: (0 if x["categoryType"] == "project" else 1, x["categoryName"], x["port"]))
except Exception:
    pass

# 5. Scan Docker Containers
docker_avail = False
docker_containers = []

try:
    d_info = subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if d_info.returncode == 0:
        docker_avail = True
        d_out = subprocess.check_output(["docker", "ps", "-a", "--format", "{{json .}}"], text=True, stderr=subprocess.DEVNULL)
        for line in d_out.splitlines():
            if line.strip():
                try:
                    c = json.loads(line)
                    docker_containers.append({
                        "id": c.get("ID", ""),
                        "name": c.get("Names", ""),
                        "image": c.get("Image", ""),
                        "status": c.get("Status", ""),
                        "state": c.get("State", ""),
                        "ports": c.get("Ports", "")
                    })
                except Exception:
                    pass
except Exception:
    pass

# 6. Output final consolidated JSON
result = {
    "project": {
        "path": active_project_path,
        "name": active_project_name,
        "stack": stack_type,
        "hasCompose": has_compose
    },
    "git": {
        "hasRepo": git_has_repo,
        "repoPath": git_repo_path,
        "repoName": git_repo_name,
        "branch": git_branch,
        "lastCommit": git_last_commit,
        "dirty": git_dirty,
        "staged": git_staged,
        "untracked": git_untracked,
        "ahead": git_ahead,
        "behind": git_behind
    },
    "ports": ports,
    "docker": {
        "available": docker_avail,
        "containers": docker_containers
    }
}

print(json.dumps(result))
EOF
