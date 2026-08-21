#!/usr/bin/env bash
set -euo pipefail

# 1. Determine active project directory
ACTIVE_CWD=""
if command -v omarchy-cmd-terminal-cwd >/dev/null 2>&1; then
  ACTIVE_CWD=$(omarchy-cmd-terminal-cwd 2>/dev/null || true)
fi

if [[ -z "$ACTIVE_CWD" || "$ACTIVE_CWD" == "$HOME" || "$ACTIVE_CWD" == "/" ]]; then
  # Fallback to Hyprland active window PID
  ACTIVE_PID=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' || true)
  if [[ -n "$ACTIVE_PID" && "$ACTIVE_PID" != "null" ]]; then
    CHILD_PID=$(pgrep -P "$ACTIVE_PID" 2>/dev/null | head -n 1 || true)
    if [[ -n "$CHILD_PID" && -d "/proc/$CHILD_PID/cwd" ]]; then
      ACTIVE_CWD=$(readlink -f "/proc/$CHILD_PID/cwd" 2>/dev/null || true)
    elif [[ -d "/proc/$ACTIVE_PID/cwd" ]]; then
      ACTIVE_CWD=$(readlink -f "/proc/$ACTIVE_PID/cwd" 2>/dev/null || true)
    fi
  fi
fi

if [[ -z "$ACTIVE_CWD" || "$ACTIVE_CWD" == "/" ]]; then
  ACTIVE_CWD="$HOME"
fi

# 2. Check for project stack files
HAS_PACKAGE_JSON=false
HAS_CARGO=false
HAS_PYTHON=false
HAS_GO=false
HAS_COMPOSE=false
STACK_TYPE="generic"

if [[ -f "$ACTIVE_CWD/package.json" ]]; then
  HAS_PACKAGE_JSON=true
  STACK_TYPE="node"
elif [[ -f "$ACTIVE_CWD/Cargo.toml" ]]; then
  HAS_CARGO=true
  STACK_TYPE="rust"
elif [[ -f "$ACTIVE_CWD/pyproject.toml" || -f "$ACTIVE_CWD/requirements.txt" ]]; then
  HAS_PYTHON=true
  STACK_TYPE="python"
elif [[ -f "$ACTIVE_CWD/go.mod" ]]; then
  HAS_GO=true
  STACK_TYPE="go"
fi

if [[ -f "$ACTIVE_CWD/docker-compose.yml" || -f "$ACTIVE_CWD/docker-compose.yaml" || -f "$ACTIVE_CWD/compose.yaml" || -f "$ACTIVE_CWD/compose.yml" ]]; then
  HAS_COMPOSE=true
fi

# 3. Detect Git Repository
GIT_HAS_REPO=false
GIT_REPO_PATH=""
GIT_REPO_NAME=""
GIT_BRANCH=""
GIT_DIRTY_COUNT=0
GIT_STAGED_COUNT=0
GIT_UNTRACKED_COUNT=0
GIT_AHEAD=0
GIT_BEHIND=0
GIT_LAST_COMMIT=""

if command -v git >/dev/null 2>&1; then
  if GIT_TOPLEVEL=$(git -C "$ACTIVE_CWD" rev-parse --show-toplevel 2>/dev/null); then
    GIT_HAS_REPO=true
    GIT_REPO_PATH="$GIT_TOPLEVEL"
    GIT_REPO_NAME=$(basename "$GIT_TOPLEVEL")
    GIT_BRANCH=$(git -C "$GIT_TOPLEVEL" branch --show-current 2>/dev/null || git -C "$GIT_TOPLEVEL" rev-parse --short HEAD 2>/dev/null || echo "HEAD")
    GIT_LAST_COMMIT=$(git -C "$GIT_TOPLEVEL" log -1 --pretty=format:"%s" 2>/dev/null || true)
    
    STATUS_OUT=$(git -C "$GIT_TOPLEVEL" status --porcelain 2>/dev/null || true)
    if [[ -n "$STATUS_OUT" ]]; then
      GIT_STAGED_COUNT=$(echo "$STATUS_OUT" | grep -c '^[MADRC]' || true)
      GIT_DIRTY_COUNT=$(echo "$STATUS_OUT" | grep -c '^.[MADRCU]' || true)
      GIT_UNTRACKED_COUNT=$(echo "$STATUS_OUT" | grep -c '^\?\?' || true)
    fi

    UPSTREAM=$(git -C "$GIT_TOPLEVEL" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || true)
    if [[ -n "$UPSTREAM" ]]; then
      AHEAD_BEHIND=$(git -C "$GIT_TOPLEVEL" rev-list --left-right --count HEAD..."$UPSTREAM" 2>/dev/null || echo "0 0")
      GIT_AHEAD=$(echo "$AHEAD_BEHIND" | awk '{print $1}')
      GIT_BEHIND=$(echo "$AHEAD_BEHIND" | awk '{print $2}')
    fi
  fi
fi

# 4. Scan listening TCP ports
PORTS_JSON="[]"
if command -v ss >/dev/null 2>&1; then
  SS_RAW=$(ss -tlpn 2>/dev/null | tail -n +2 || true)
  if [[ -n "$SS_RAW" ]]; then
    PORTS_JSON=$(echo "$SS_RAW" | awk '{
      local_addr = $4;
      proc_info = $6;
      
      split(local_addr, addr_parts, ":");
      port = addr_parts[length(addr_parts)];
      gsub(/%.*/, "", port);
      
      ip = "";
      for (i=1; i<length(addr_parts); i++) {
        if (i > 1) ip = ip ":" addr_parts[i];
        else ip = addr_parts[i];
      }
      if (ip == "" || ip == "*") ip = "0.0.0.0";

      pname = "unknown";
      pid = 0;
      if (match(proc_info, /users:\(\("([^"]+)",pid=([0-9]+)/, m)) {
        pname = m[1];
        pid = m[2];
      } else if (match(proc_info, /users:\(\("([^"]+)"/, m)) {
        pname = m[1];
      }

      # Filter out internal resolver on 53 unless requested
      if (port ~ /^[0-9]+$/ && port > 0 && port != 53) {
        printf "{\"port\":%d,\"ip\":\"%s\",\"process\":\"%s\",\"pid\":%d}\n", port, ip, pname, pid;
      }
    }' | jq -s 'sort_by(.port) | unique_by(.port)')
  fi
fi

# 5. Scan Docker Containers
DOCKER_AVAILABLE=false
DOCKER_JSON="[]"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    DOCKER_AVAILABLE=true
    DOCKER_RAW=$(docker ps -a --format '{"id":"{{.ID}}","name":"{{.Names}}","image":"{{.Image}}","status":"{{.Status}}","state":"{{.State}}","ports":"{{.Ports}}"}' 2>/dev/null || true)
    if [[ -n "$DOCKER_RAW" ]]; then
      DOCKER_JSON=$(echo "$DOCKER_RAW" | jq -s '.')
    fi
  fi
fi

# Output JSON
jq -n \
  --arg active_cwd "$ACTIVE_CWD" \
  --arg active_name "$(basename "$ACTIVE_CWD")" \
  --arg stack_type "$STACK_TYPE" \
  --argjson has_compose "$HAS_COMPOSE" \
  --argjson git_has "$GIT_HAS_REPO" \
  --arg git_path "$GIT_REPO_PATH" \
  --arg git_name "$GIT_REPO_NAME" \
  --arg git_branch "$GIT_BRANCH" \
  --arg git_commit "$GIT_LAST_COMMIT" \
  --argjson git_dirty "$GIT_DIRTY_COUNT" \
  --argjson git_staged "$GIT_STAGED_COUNT" \
  --argjson git_untracked "$GIT_UNTRACKED_COUNT" \
  --argjson git_ahead "$GIT_AHEAD" \
  --argjson git_behind "$GIT_BEHIND" \
  --argjson ports "$PORTS_JSON" \
  --argjson docker_avail "$DOCKER_AVAILABLE" \
  --argjson docker_containers "$DOCKER_JSON" \
  '{
    project: {
      path: $active_cwd,
      name: (if $git_name != "" then $git_name else $active_name end),
      stack: $stack_type,
      hasCompose: $has_compose
    },
    git: {
      hasRepo: $git_has,
      repoPath: $git_path,
      repoName: $git_name,
      branch: $git_branch,
      lastCommit: $git_commit,
      dirty: $git_dirty,
      staged: $git_staged,
      untracked: $git_untracked,
      ahead: $git_ahead,
      behind: $git_behind
    },
    ports: $ports,
    docker: {
      available: $docker_avail,
      containers: $docker_containers
    }
  }'
