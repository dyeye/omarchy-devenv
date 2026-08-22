#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$PATH"

if ! command -v gh >/dev/null 2>&1; then
  for gh_bin in "$HOME"/.local/share/mise/installs/gh/*/*/bin/gh; do
    if [[ -x "$gh_bin" ]]; then
      export PATH="$(dirname "$gh_bin"):$PATH"
      break
    fi
  done
fi

## Execute the memory-bounded Python scanner
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

# ---------------------------------------------------------------- Bounded Subprocess & String Helpers

def run_cmd(cmd, cwd=None, max_bytes=65536, timeout=1.5):
    """Executes a command with strict timeout and bounded byte capture."""
    try:
        res = subprocess.run(
            cmd,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=timeout
        )
        if res.returncode == 0 and res.stdout:
            return res.stdout[:max_bytes]
    except Exception:
        pass
    return ""

def str_limit(s, max_len=128):
    """Truncates string to a deterministic maximum length."""
    if not s:
        return ""
    st = str(s).strip()
    return st[:max_len] if len(st) > max_len else st

def resolve_project_dir(path_or_name):
    if not path_or_name:
        return None
    p = os.path.expanduser(str(path_or_name).strip())
    if os.path.isdir(p) and p != home and p != "/":
        git_root = run_cmd(["git", "-C", p, "rev-parse", "--show-toplevel"], timeout=1.0).strip()
        if git_root and os.path.isdir(git_root):
            return git_root
        return p
    name = os.path.basename(p)
    if name and name != "." and name != "..":
        for sroot in search_roots:
            candidate = os.path.join(sroot, name)
            if os.path.isdir(candidate):
                return candidate
    return None

def project_from_filepath(fpath):
    if not fpath:
        return None, None
    try:
        real = os.path.realpath(fpath)
    except Exception:
        return None, None
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
    git_dir = real if os.path.isdir(real) else os.path.dirname(real)
    git_root = run_cmd(["git", "-C", git_dir, "rev-parse", "--show-toplevel"], timeout=1.0).strip()
    if git_root and git_root != home and git_root != "/":
        return os.path.basename(git_root), git_root
    return None, None

def get_descendant_pids(root_pid, max_count=20):
    """Find child PIDs with strict queue bounds and timeout."""
    desc = []
    queue = [str(root_pid)]
    visited = set(queue)
    while queue and len(desc) < max_count:
        curr = queue.pop(0)
        out = run_cmd(["pgrep", "-P", curr], timeout=0.5).split()
        for k in out:
            if k not in visited:
                visited.add(k)
                desc.append(k)
                queue.append(k)
                if len(desc) >= max_count:
                    break
    return desc

# ---------------------------------------------------------------- 1. Active Project Resolution

active_project_path = ""
active_project_name = ""
is_manual_mode = False

pinned_file = os.path.join(home, ".local/state/omarchy/devenv/pinned_project.txt")
if os.path.isfile(pinned_file):
    try:
        with open(pinned_file, "r") as pf:
            pcontent = pf.read(1024).strip()
            if pcontent and os.path.isdir(pcontent):
                active_project_path = os.path.realpath(pcontent)
                active_project_name = os.path.basename(active_project_path)
                is_manual_mode = True
    except Exception:
        pass

if not is_manual_mode:
    hypr_raw = run_cmd(["hyprctl", "activewindow", "-j"], max_bytes=32768, timeout=1.0)
    try:
        win = json.loads(hypr_raw) if hypr_raw else {}
    except Exception:
        win = {}

    win_title = str_limit(win.get("title", ""), 256)
    win_pid = win.get("pid", 0) if isinstance(win.get("pid"), int) else 0
    win_class = str_limit(win.get("class", ""), 128).lower()

    is_terminal_window = any(t in win_class for t in ["foot", "kitty", "alacritty", "ghostty", "wezterm", "terminal", "tmux"]) or "herdr" in win_class

    # 1a. Check window title for GUI editors
    if not is_terminal_window and win_title:
        title_parts = re.split(r"[\s—\-\|:]+", win_title)
        for part in title_parts[:10]:
            part = part.strip()
            if not part or part.lower() in {"zed", "visual", "studio", "code", "obsidian", "nvim", "neovim", "panel.qml"}:
                continue
            resolved = resolve_project_dir(part)
            if resolved:
                active_project_path = resolved
                active_project_name = os.path.basename(resolved)
                break

    # 1b. Terminal windows & child process inspection
    if not active_project_path and (is_terminal_window or win_pid > 0):
        desc_pids = get_descendant_pids(win_pid, max_count=15) if win_pid > 0 else []
        all_pids_to_check = [str(win_pid)] + desc_pids

        is_tmux = any("tmux" in win_class for _ in [1]) or "tmux" in win_title.lower()
        if not is_tmux and all_pids_to_check:
            for p in all_pids_to_check[:10]:
                try:
                    if os.path.exists(f"/proc/{p}/comm"):
                        comm = open(f"/proc/{p}/comm", "r").read(64).strip().lower()
                        if "tmux" in comm:
                            is_tmux = True
                            break
                except Exception:
                    pass

        if is_tmux:
            clients_raw = run_cmd(["tmux", "list-clients", "-F", "#{client_pid} #{pane_current_path}"], max_bytes=8192, timeout=1.0)
            matched_tmux_path = ""
            for cline in clients_raw.splitlines()[:10]:
                if cline.strip():
                    parts = cline.split(None, 1)
                    if len(parts) == 2:
                        c_pid_str, c_path = parts[0], parts[1]
                        if c_pid_str in all_pids_to_check:
                            matched_tmux_path = c_path
                            break
                        elif not matched_tmux_path:
                            matched_tmux_path = c_path
            if not matched_tmux_path:
                matched_tmux_path = run_cmd(["tmux", "display-message", "-p", "-F", "#{pane_current_path}"], max_bytes=1024, timeout=1.0).strip()

            if matched_tmux_path:
                p_name, p_dir = project_from_filepath(matched_tmux_path)
                if p_dir:
                    active_project_name = p_name
                    active_project_path = p_dir
                elif matched_tmux_path != "/" and matched_tmux_path != home:
                    active_project_name = os.path.basename(matched_tmux_path)
                    active_project_path = matched_tmux_path

        # 1b-ii. Herdr check
        if not active_project_path and "herdr" in win_class:
            h_raw = run_cmd(["herdr", "pane", "list"], max_bytes=16384, timeout=1.0)
            try:
                h_data = json.loads(h_raw) if h_raw else {}
                for p in h_data.get("result", {}).get("panes", [])[:10]:
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

        # 1b-iii. Standard terminal child processes
        if not active_project_path and desc_pids:
            for cpid in reversed(desc_pids[:10]):
                try:
                    c_cwd = os.path.realpath(f"/proc/{cpid}/cwd")
                    p_name, p_dir = project_from_filepath(c_cwd)
                    if p_dir:
                        active_project_name = p_name
                        active_project_path = p_dir
                        break
                except Exception:
                    pass

    # 1c. Open file descriptors inspection
    if not active_project_path and win_pid > 0:
        try:
            fd_dir = f"/proc/{win_pid}/fd"
            if os.path.exists(fd_dir):
                for fd in list(os.listdir(fd_dir))[:20]:
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

    # 1d. Fallback via terminal-cwd helper
    if not active_project_path:
        t_cwd = run_cmd(["omarchy-cmd-terminal-cwd"], max_bytes=1024, timeout=1.0).strip()
        if t_cwd:
            p_name, p_dir = project_from_filepath(t_cwd)
            if p_dir:
                active_project_name = p_name
                active_project_path = p_dir
            elif t_cwd != "/" and t_cwd != home:
                active_project_name = os.path.basename(t_cwd)
                active_project_path = t_cwd

if not active_project_path:
    active_project_path = home
    active_project_name = os.path.basename(home)

active_project_path = str_limit(active_project_path, 256)
active_project_name = str_limit(active_project_name, 64)

# ---------------------------------------------------------------- 2. Stack & Compose Detection

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

# ---------------------------------------------------------------- 3. Git Status Scanner (Bounded)

git_has_repo = False
git_repo_path = ""
git_repo_name = ""
git_branch = ""
git_branches = []
git_last_commit = ""
git_commits = []
git_stashes = []
git_dirty = 0
git_staged = 0
git_untracked = 0
git_ahead = 0
git_behind = 0
git_remote_url = ""
is_github = False
github_repo = ""
pull_requests = []
issues = []

if active_project_path and os.path.isdir(active_project_path):
    git_root = run_cmd(["git", "-C", active_project_path, "rev-parse", "--show-toplevel"], timeout=1.0).strip()
    if git_root:
        git_has_repo = True
        git_repo_path = str_limit(git_root, 256)
        git_repo_name = str_limit(os.path.basename(git_root), 64)
        active_project_name = git_repo_name

        # Current branch (bounded)
        git_branch = run_cmd(["git", "-C", git_root, "branch", "--show-current"], max_bytes=256, timeout=1.0).strip()
        if not git_branch:
            git_branch = run_cmd(["git", "-C", git_root, "rev-parse", "--short", "HEAD"], max_bytes=64, timeout=1.0).strip()
        git_branch = str_limit(git_branch or "HEAD", 64)

        # Branches list (bounded to 30 items, 100 chars per branch)
        raw_branches_out = run_cmd(["git", "-C", git_root, "branch", "-a", "--format=%(refname:short)"], max_bytes=32768, timeout=1.5)
        raw_branches = raw_branches_out.splitlines()[:60]
        seen_b = set()
        if git_branch:
            git_branches.append(git_branch)
            seen_b.add(git_branch)
        for b in raw_branches:
            if len(git_branches) >= 30:
                break
            b = b.strip()
            if not b or "->" in b: continue
            clean_b = re.sub(r"^(remotes/)?(origin|upstream)/", "", b).strip()
            clean_b = str_limit(clean_b, 100)
            if clean_b and clean_b not in {"origin", "upstream", "HEAD"} and clean_b not in seen_b:
                seen_b.add(clean_b)
                git_branches.append(clean_b)

        # Last commit
        git_last_commit = str_limit(run_cmd(["git", "-C", git_root, "log", "-1", "--pretty=format:%s"], max_bytes=512, timeout=1.0).strip(), 256)

        # Commits list (bounded to 15 items, per-field limits)
        log_out = run_cmd(["git", "-C", git_root, "log", "-15", "--pretty=format:%h|||%H|||%an|||%cr|||%s"], max_bytes=16384, timeout=1.5)
        for l in log_out.splitlines()[:15]:
            parts = l.split("|||")
            if len(parts) == 5:
                git_commits.append({
                    "hash": str_limit(parts[0], 16),
                    "fullHash": str_limit(parts[1], 64),
                    "author": str_limit(parts[2], 64),
                    "date": str_limit(parts[3], 32),
                    "message": str_limit(parts[4], 256)
                })

        # Stashes list (bounded to 10 items, per-field limits)
        stash_out = run_cmd(["git", "-C", git_root, "stash", "list", "--pretty=format:%gd|||%cr|||%gs"], max_bytes=8192, timeout=1.0)
        for l in stash_out.splitlines()[:10]:
            parts = l.split("|||")
            if len(parts) == 3:
                m = re.search(r"\{(\d+)\}", parts[0])
                s_idx = int(m.group(1)) if m else 0
                git_stashes.append({
                    "index": s_idx,
                    "date": str_limit(parts[1], 32),
                    "message": str_limit(parts[2], 256)
                })

        # Git status (bounded parsing to first 300 lines)
        status_out = run_cmd(["git", "-C", git_root, "status", "--porcelain"], max_bytes=32768, timeout=1.5)
        for sl in status_out.splitlines()[:300]:
            if not sl: continue
            if sl.startswith("??"):
                git_untracked += 1
            else:
                if sl[0] in "MADRC":
                    git_staged += 1
                if len(sl) > 1 and sl[1] in "MADRCU":
                    git_dirty += 1

        # Ahead/behind calculation
        rev_out = run_cmd(["git", "-C", git_root, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"], max_bytes=256, timeout=1.0)
        if rev_out.strip():
            cnt_parts = rev_out.split()
            if len(cnt_parts) == 2 and cnt_parts[0].isdigit() and cnt_parts[1].isdigit():
                git_behind = min(int(cnt_parts[0]), 999)
                git_ahead = min(int(cnt_parts[1]), 999)

        # Remote URL & GitHub detection
        remote_out = run_cmd(["git", "-C", git_root, "remote", "get-url", "origin"], max_bytes=512, timeout=1.0).strip()
        if not remote_out:
            remote_out = run_cmd(["git", "-C", git_root, "config", "--get", "remote.origin.url"], max_bytes=512, timeout=1.0).strip()
        git_remote_url = str_limit(remote_out, 256)

        if "github.com" in git_remote_url:
            is_github = True
            m_gh = re.search(r"github\.com[:/]([^/]+/[^/.]+)", git_remote_url)
            if m_gh:
                github_repo = str_limit(m_gh.group(1).replace(".git", ""), 128)

        # Query GitHub PRs & Issues via gh CLI (bounded to 8 items, strict limits)
        if github_repo:
            pr_raw = run_cmd(["gh", "pr", "list", "--limit", "8", "--json", "number,title,author,url,state,headRefName", "-C", git_root], max_bytes=16384, timeout=2.0)
            if pr_raw:
                try:
                    pr_list = json.loads(pr_raw)
                    for pr in pr_list[:8]:
                        pull_requests.append({
                            "number": int(pr.get("number", 0)),
                            "title": str_limit(pr.get("title", ""), 256),
                            "author": str_limit(pr.get("author", {}).get("login", "") if isinstance(pr.get("author"), dict) else str(pr.get("author", "")), 64),
                            "url": str_limit(pr.get("url", ""), 256),
                            "headRefName": str_limit(pr.get("headRefName", ""), 100)
                        })
                except Exception:
                    pass

            iss_raw = run_cmd(["gh", "issue", "list", "--limit", "8", "--json", "number,title,author,url,state", "-C", git_root], max_bytes=16384, timeout=2.0)
            if iss_raw:
                try:
                    iss_list = json.loads(iss_raw)
                    for iss in iss_list[:8]:
                        issues.append({
                            "number": int(iss.get("number", 0)),
                            "title": str_limit(iss.get("title", ""), 256),
                            "author": str_limit(iss.get("author", {}).get("login", "") if isinstance(iss.get("author"), dict) else str(iss.get("author", "")), 64),
                            "url": str_limit(iss.get("url", ""), 256)
                        })
                except Exception:
                    pass

# ---------------------------------------------------------------- 4. Bounded TCP Sockets Scanner

ports = []
general_tools = {"agy", "opencode", "steam", "cupsd", "systemd", "systemd-resolve", "rpcbind", "avahi-daemon", "sshd"}

ss_raw = run_cmd(["ss", "-tlpn"], max_bytes=65536, timeout=1.5)
if ss_raw:
    seen_ports = set()
    for line in ss_raw.splitlines()[1:]:
        if len(ports) >= 50:
            break
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
        ip = str_limit(ip, 48)

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

        pname = str_limit(re.sub(r"\s+\(v\d+.*", "", pname), 64)

        cat_type = "process"
        cat_name = "General Processes"
        cat_path = ""

        if pid > 0 and pname.lower() not in general_tools:
            # Check 1: Working directory
            try:
                if os.path.exists(f"/proc/{pid}/cwd"):
                    proc_cwd = os.path.realpath(f"/proc/{pid}/cwd")
                    p_name, p_dir = project_from_filepath(proc_cwd)
                    if p_dir:
                        cat_type = "project"
                        cat_name = str_limit(p_name, 64)
                        cat_path = str_limit(p_dir, 256)
            except Exception:
                pass

            # Check 2: Process cmdline
            if cat_type != "project":
                try:
                    if os.path.exists(f"/proc/{pid}/cmdline"):
                        with open(f"/proc/{pid}/cmdline", "rb") as f:
                            cmdline_str = f.read(2048).replace(b"\x00", b" ").decode("utf-8", errors="ignore")
                        for token in cmdline_str.split()[:20]:
                            p_name, p_dir = project_from_filepath(token)
                            if p_dir:
                                cat_type = "project"
                                cat_name = str_limit(p_name, 64)
                                cat_path = str_limit(p_dir, 256)
                                break
                except Exception:
                    pass

            # Check 3: File descriptors
            if cat_type != "project":
                try:
                    fd_dir = f"/proc/{pid}/fd"
                    if os.path.exists(fd_dir):
                        for fd in list(os.listdir(fd_dir))[:20]:
                            try:
                                target = os.path.realpath(os.path.join(fd_dir, fd))
                                p_name, p_dir = project_from_filepath(target)
                                if p_dir:
                                    cat_type = "project"
                                    cat_name = str_limit(p_name, 64)
                                    cat_path = str_limit(p_dir, 256)
                                    break
                            except Exception:
                                pass
                except Exception:
                    pass

            # Check 4: Parent process cwd
            if cat_type != "project":
                try:
                    if os.path.exists(f"/proc/{pid}/stat"):
                        with open(f"/proc/{pid}/stat", "r") as f:
                            stat_parts = f.read(512).split()
                            ppid = int(stat_parts[3])
                            if ppid > 1 and os.path.exists(f"/proc/{ppid}/cwd"):
                                pproc_cwd = os.path.realpath(f"/proc/{ppid}/cwd")
                                p_name, p_dir = project_from_filepath(pproc_cwd)
                                if p_dir:
                                    cat_type = "project"
                                    cat_name = str_limit(p_name, 64)
                                    cat_path = str_limit(p_dir, 256)
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

# ---------------------------------------------------------------- 5. Bounded Docker Scanner

docker_avail = False
docker_containers = []

d_out = run_cmd(["docker", "ps", "-a", "--format", "{{json .}}"], max_bytes=65536, timeout=2.0)
if d_out:
    docker_avail = True
    for line in d_out.splitlines()[:30]:
        if line.strip():
            try:
                c = json.loads(line)
                docker_containers.append({
                    "id": str_limit(c.get("ID", ""), 32),
                    "name": str_limit(c.get("Names", ""), 64),
                    "image": str_limit(c.get("Image", ""), 128),
                    "status": str_limit(c.get("Status", ""), 64),
                    "state": str_limit(c.get("State", ""), 32),
                    "ports": str_limit(c.get("Ports", ""), 128)
                })
            except Exception:
                pass
else:
    d_info = run_cmd(["docker", "info"], max_bytes=1024, timeout=1.0)
    if d_info:
        docker_avail = True

# ---------------------------------------------------------------- 6. Bounded Project Discovery

discovered_projects = []
seen_pdirs = set()

def scan_project_meta(pdir):
    if not pdir or not os.path.isdir(pdir):
        return None
    try:
        real_p = os.path.realpath(pdir)
    except Exception:
        return None
    if real_p in seen_pdirs or real_p == home or real_p == "/":
        return None
    seen_pdirs.add(real_p)

    pname = str_limit(os.path.basename(real_p), 64)
    has_git = os.path.isdir(os.path.join(real_p, ".git"))
    has_comp = any(os.path.isfile(os.path.join(real_p, f)) for f in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"])
    
    pstack = "generic"
    if os.path.isfile(os.path.join(real_p, "package.json")):
        pstack = "node"
    elif os.path.isfile(os.path.join(real_p, "Cargo.toml")):
        pstack = "rust"
    elif any(os.path.isfile(os.path.join(real_p, f)) for f in ["pyproject.toml", "requirements.txt", "Pipfile", "manage.py", "setup.py"]):
        pstack = "python"
    elif os.path.isfile(os.path.join(real_p, "go.mod")):
        pstack = "go"
    elif os.path.isfile(os.path.join(real_p, "manifest.json")):
        pstack = "qml"
    elif os.path.isfile(os.path.join(real_p, "pom.xml")) or os.path.isfile(os.path.join(real_p, "build.gradle")):
        pstack = "java"
    elif os.path.isfile(os.path.join(real_p, "composer.json")):
        pstack = "php"

    return {
        "name": pname,
        "path": str_limit(real_p, 256),
        "stack": str_limit(pstack, 32),
        "hasGit": has_git,
        "hasCompose": has_comp
    }

for sroot in search_roots:
    if len(discovered_projects) >= 25:
        break
    if os.path.isdir(sroot):
        try:
            for entry in list(os.listdir(sroot))[:30]:
                if len(discovered_projects) >= 25:
                    break
                cand = os.path.join(sroot, entry)
                if os.path.isdir(cand) and not entry.startswith(".") and entry != "node_modules":
                    meta = scan_project_meta(cand)
                    if meta:
                        discovered_projects.append(meta)
        except Exception:
            pass

if active_project_path:
    meta = scan_project_meta(active_project_path)
    if meta and len(discovered_projects) < 25:
        discovered_projects.append(meta)

discovered_projects.sort(key=lambda x: x["name"].lower())

# ---------------------------------------------------------------- 7. Response Ceiling & Output

result = {
    "project": {
        "path": active_project_path,
        "name": active_project_name,
        "stack": stack_type,
        "hasCompose": has_compose,
        "isManual": is_manual_mode
    },
    "discoveredProjects": discovered_projects,
    "git": {
        "hasRepo": git_has_repo,
        "repoPath": git_repo_path,
        "repoName": git_repo_name,
        "branch": git_branch,
        "branches": git_branches,
        "lastCommit": git_last_commit,
        "commits": git_commits,
        "stashes": git_stashes,
        "dirty": git_dirty,
        "staged": git_staged,
        "untracked": git_untracked,
        "ahead": git_ahead,
        "behind": git_behind,
        "remoteUrl": git_remote_url,
        "isGitHub": is_github,
        "githubRepo": github_repo,
        "pullRequests": pull_requests,
        "issues": issues
    },
    "ports": ports,
    "docker": {
        "available": docker_avail,
        "containers": docker_containers
    }
}

# Enforce final payload size ceiling (max 196 KB) to guarantee bounded memory in shell
payload = json.dumps(result)
if len(payload) > 200000:
    result["git"]["commits"] = result["git"]["commits"][:8]
    result["git"]["stashes"] = result["git"]["stashes"][:5]
    result["ports"] = result["ports"][:25]
    result["docker"]["containers"] = result["docker"]["containers"][:15]
    result["discoveredProjects"] = result["discoveredProjects"][:15]
    payload = json.dumps(result)

print(payload)
EOF
