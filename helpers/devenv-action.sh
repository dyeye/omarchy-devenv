#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$PATH"
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"

# Neutralize repo-local git config that can execute arbitrary commands.
# Env-scoped config (command scope) takes precedence over .git/config, so a
# malicious cloned repository cannot weaponize git invocations via
# core.fsmonitor (runs on `git status`), core.pager, or core.hooksPath
# (repo-supplied hooks like post-checkout / post-merge / pre-push).
export GIT_CONFIG_COUNT=3
export GIT_CONFIG_KEY_0="core.fsmonitor"
export GIT_CONFIG_VALUE_0="false"
export GIT_CONFIG_KEY_1="core.pager"
export GIT_CONFIG_VALUE_1="cat"
export GIT_CONFIG_KEY_2="core.hooksPath"
export GIT_CONFIG_VALUE_2="/dev/null"

if ! command -v gh >/dev/null 2>&1; then
  for gh_bin in "$HOME"/.local/share/mise/installs/gh/*/*/bin/gh; do
    if [[ -x "$gh_bin" ]]; then
      export PATH="$(dirname "$gh_bin"):$PATH"
      break
    fi
  done
fi

ACTION="${1:-}"
TARGET="${2:-}"
EXTRA="${3:-}"
EXTRA2="${4:-}"

# ---------------------------------------------------------------- Process-group-aware deadline runner
run_with_deadline() {
  local deadline_secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    if command -v setsid >/dev/null 2>&1; then
      setsid timeout -k 1s "${deadline_secs}s" "$@"
    else
      timeout -k 1s "${deadline_secs}s" "$@"
    fi
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- Secure Atomic State Management
STATE_DIR="$HOME/.local/state/omarchy/devenv"
PINNED_FILE="$STATE_DIR/pinned_project.txt"

save_pinned_project() {
  local target_path="$1"
  if [[ -z "$target_path" || ! -d "$target_path" || "$target_path" == -* ]]; then
    return 1
  fi

  # Create state directory with strict 0700 permissions
  mkdir -p -m 0700 "$STATE_DIR"

  # Create exclusive temporary file with 0600 permissions in the same directory/filesystem
  local tmp_file
  tmp_file="$( (umask 077 && mktemp -p "$STATE_DIR" .pinned_project.XXXXXX) 2>/dev/null || true )"
  if [[ -z "$tmp_file" || ! -f "$tmp_file" ]]; then
    return 1
  fi

  chmod 0600 "$tmp_file" 2>/dev/null || true
  printf '%s\n' "$target_path" > "$tmp_file"

  # Atomic replace: replaces symlinks directly without following them
  mv -f "$tmp_file" "$PINNED_FILE"
  return 0
}

# Safe JSON string escaper
json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

case "$ACTION" in
  kill-pid)
    PID="${TARGET:-}"
    EXPECTED_NAME="${EXTRA:-}"
    EXPECTED_STARTTIME="${EXTRA2:-}"

    if [[ -n "$PID" && "$PID" =~ ^[0-9]+$ && "$PID" -gt 1 ]]; then
      # 1. Process directory must exist
      if [[ ! -d "/proc/$PID" ]]; then
        echo "{\"success\":false,\"error\":\"Process $PID does not exist\"}"
        exit 0
      fi

      # 2. Ownership check: Must belong to current user
      proc_uid="$(stat -c %u "/proc/$PID" 2>/dev/null || true)"
      if [[ "$proc_uid" != "$(id -u)" ]]; then
        echo "{\"success\":false,\"error\":\"Process $PID not owned by current user\"}"
        exit 0
      fi

      # 3. Read process stat and comm
      stat_content="$(cat "/proc/$PID/stat" 2>/dev/null || true)"
      if [[ -z "$stat_content" ]]; then
        echo "{\"success\":false,\"error\":\"Cannot read process stat for $PID\"}"
        exit 0
      fi

      after_comm="${stat_content##*)}"
      read -r -a stat_fields <<< "$after_comm"
      curr_starttime="${stat_fields[19]:-}"
      curr_comm="$(cat "/proc/$PID/comm" 2>/dev/null || true)"

      # 4. Start time verification (PID reuse protection)
      if [[ -n "$EXPECTED_STARTTIME" && "$curr_starttime" != "$EXPECTED_STARTTIME" ]]; then
        echo "{\"success\":false,\"error\":\"Process start time changed (PID reuse detected)\"}"
        exit 0
      fi

      # 5. Process identity verification (check comm, exe, argv0)
      if [[ -n "$EXPECTED_NAME" && "$EXPECTED_NAME" != "unknown" ]]; then
        curr_exe="$(basename "$(readlink -f "/proc/$PID/exe" 2>/dev/null || true)" 2>/dev/null || true)"
        curr_argv0="$(tr '\0' '\n' < "/proc/$PID/cmdline" 2>/dev/null | head -n 1 || true)"
        curr_argv0_base="$(basename "$curr_argv0" 2>/dev/null || true)"
        
        matched=false
        if [[ -n "$curr_comm" && ("$curr_comm" == "$EXPECTED_NAME"* || "$EXPECTED_NAME" == "$curr_comm"*) ]]; then
          matched=true
        elif [[ -n "$curr_exe" && ("$curr_exe" == "$EXPECTED_NAME"* || "$EXPECTED_NAME" == "$curr_exe"*) ]]; then
          matched=true
        elif [[ -n "$curr_argv0_base" && ("$curr_argv0_base" == "$EXPECTED_NAME"* || "$EXPECTED_NAME" == "$curr_argv0_base"*) ]]; then
          matched=true
        fi

        if [[ "$matched" != "true" ]]; then
          esc_exp="$(json_escape "$EXPECTED_NAME")"
          esc_act="$(json_escape "$curr_comm")"
          echo "{\"success\":false,\"error\":\"Process identity mismatch (expected: $esc_exp, actual: $esc_act)\"}"
          exit 0
        fi
      fi

      # 6. Revalidation passed: send SIGTERM, wait briefly, then SIGKILL if still alive
      run_with_deadline 3 kill -15 "$PID" 2>/dev/null || true
      sleep 0.1
      if [[ -d "/proc/$PID" ]]; then
        # Re-verify start time before SIGKILL
        re_stat="$(cat "/proc/$PID/stat" 2>/dev/null || true)"
        re_after="${re_stat##*)}"
        read -r -a re_fields <<< "$re_after"
        re_starttime="${re_fields[19]:-}"
        if [[ -z "$curr_starttime" || "$re_starttime" == "$curr_starttime" ]]; then
          run_with_deadline 2 kill -9 "$PID" 2>/dev/null || true
        fi
      fi
      echo "{\"success\":true,\"action\":\"kill-pid\",\"target\":$PID}"
    else
      echo "{\"success\":false,\"error\":\"Invalid PID\"}"
    fi
    ;;

  kill-port)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[0-9]+$ && "$TARGET" -ge 1 && "$TARGET" -le 65535 ]]; then
      run_with_deadline 5 fuser -k -n tcp "$TARGET" 2>/dev/null || true
      echo "{\"success\":true,\"action\":\"kill-port\",\"port\":$TARGET}"
    else
      echo "{\"success\":false,\"error\":\"Invalid port\"}"
    fi
    ;;

  docker-start)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      run_with_deadline 10 docker start -- "$TARGET" >/dev/null 2>&1 || true
      esc_target="$(json_escape "$TARGET")"
      echo "{\"success\":true,\"action\":\"docker-start\",\"target\":\"$esc_target\"}"
    else
      echo "{\"success\":false,\"error\":\"Invalid container identifier\"}"
    fi
    ;;

  docker-stop)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      run_with_deadline 15 docker stop -- "$TARGET" >/dev/null 2>&1 || true
      esc_target="$(json_escape "$TARGET")"
      echo "{\"success\":true,\"action\":\"docker-stop\",\"target\":\"$esc_target\"}"
    else
      echo "{\"success\":false,\"error\":\"Invalid container identifier\"}"
    fi
    ;;

  docker-restart)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      run_with_deadline 15 docker restart -- "$TARGET" >/dev/null 2>&1 || true
      esc_target="$(json_escape "$TARGET")"
      echo "{\"success\":true,\"action\":\"docker-restart\",\"target\":\"$esc_target\"}"
    else
      echo "{\"success\":false,\"error\":\"Invalid container identifier\"}"
    fi
    ;;

  docker-logs)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
      # Bound producer bytes and enforce process-group-aware deadline
      set +o pipefail
      logs="$(run_with_deadline 5 docker logs --tail 40 -- "$TARGET" 2>&1 | head -c 131072 || true)"
      set -o pipefail
      if [[ -n "$logs" ]]; then
        printf '%s\n' "$logs"
      else
        echo "No logs found for $TARGET"
      fi
    else
      echo "Invalid container identifier"
    fi
    ;;

  compose-up)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      set +o pipefail
      out="$(cd "$DIR" && run_with_deadline 30 docker compose up -d 2>&1 | head -c 8192 || true)"
      set -o pipefail
      if [[ -z "$out" ]]; then
        echo "Failed to run docker compose up"
      else
        printf '%s\n' "$out"
      fi
    else
      echo "Invalid compose directory"
    fi
    ;;

  compose-down)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      set +o pipefail
      out="$(cd "$DIR" && run_with_deadline 20 docker compose down 2>&1 | head -c 8192 || true)"
      set -o pipefail
      if [[ -z "$out" ]]; then
        echo "Failed to run docker compose down"
      else
        printf '%s\n' "$out"
      fi
    else
      echo "Invalid compose directory"
    fi
    ;;

  git-checkout)
    DIR="${TARGET:-$HOME}"
    BRANCH="${EXTRA:-}"
    if [[ -d "$DIR" && "$DIR" != -* && -n "$BRANCH" && "$BRANCH" =~ ^[a-zA-Z0-9_./@#-]+$ && "$BRANCH" != -* ]]; then
      # `git switch` only accepts branch names (never pathspecs), unlike
      # `git checkout -- <arg>` which would treat the branch as a file path
      # and could silently overwrite working-tree files from the index.
      esc_branch="$(json_escape "$BRANCH")"
      if run_with_deadline 5 git -C "$DIR" switch -- "$BRANCH" >/dev/null 2>&1; then
        echo "{\"success\":true,\"action\":\"git-checkout\",\"branch\":\"$esc_branch\"}"
      else
        echo "{\"success\":false,\"action\":\"git-checkout\",\"branch\":\"$esc_branch\",\"error\":\"git switch failed\"}"
      fi
    else
      echo "{\"success\":false,\"error\":\"Invalid checkout arguments\"}"
    fi
    ;;

  git-fetch)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      run_with_deadline 15 git -C "$DIR" fetch --all >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-fetch\"}"
    fi
    ;;

  git-pull)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      run_with_deadline 15 git -C "$DIR" pull >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-pull\"}"
    fi
    ;;

  git-push)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      run_with_deadline 15 git -C "$DIR" push >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-push\"}"
    fi
    ;;

  git-stash-pop)
    DIR="${TARGET:-$HOME}"
    STASH_IDX="${EXTRA:-0}"
    if [[ -d "$DIR" && "$DIR" != -* && "$STASH_IDX" =~ ^[0-9]+$ ]]; then
      run_with_deadline 5 git -C "$DIR" stash pop "stash@{$STASH_IDX}" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-stash-pop\",\"stash\":$STASH_IDX}"
    else
      echo "{\"success\":false,\"error\":\"Invalid stash arguments\"}"
    fi
    ;;

  open-browser)
    # Validate strictly that target is an HTTP/HTTPS URL to prevent arbitrary file execution via xdg-open
    if [[ -n "$TARGET" && ( "$TARGET" == http://* || "$TARGET" == https://* ) && "$TARGET" != *[[:cntrl:]\ \'\"\\\|\<\>\`]* ]]; then
      run_with_deadline 3 xdg-open -- "$TARGET" >/dev/null 2>&1 &
      esc_url="$(json_escape "$TARGET")"
      echo "{\"success\":true,\"action\":\"open-browser\",\"url\":\"$esc_url\"}"
    else
      echo "{\"success\":false,\"error\":\"Invalid HTTP/HTTPS URL\"}"
    fi
    ;;

  open-terminal)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      if command -v foot >/dev/null 2>&1; then
        foot -D "$DIR" >/dev/null 2>&1 &
      elif command -v kitty >/dev/null 2>&1; then
        kitty --directory "$DIR" >/dev/null 2>&1 &
      elif command -v alacritty >/dev/null 2>&1; then
        alacritty --working-directory "$DIR" >/dev/null 2>&1 &
      elif command -v ghostty >/dev/null 2>&1; then
        ghostty --working-directory="$DIR" >/dev/null 2>&1 &
      else
        xdg-terminal-exec --dir="$DIR" >/dev/null 2>&1 &
      fi
      esc_dir="$(json_escape "$DIR")"
      echo "{\"success\":true,\"action\":\"open-terminal\",\"dir\":\"$esc_dir\"}"
    else
      echo "{\"success\":false,\"action\":\"open-terminal\",\"error\":\"Invalid project directory\"}"
    fi
    ;;

  open-lazygit)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      if command -v foot >/dev/null 2>&1; then
        foot -D "$DIR" lazygit >/dev/null 2>&1 &
      elif command -v kitty >/dev/null 2>&1; then
        kitty --directory "$DIR" lazygit >/dev/null 2>&1 &
      elif command -v alacritty >/dev/null 2>&1; then
        alacritty --working-directory "$DIR" -e lazygit >/dev/null 2>&1 &
      elif command -v ghostty >/dev/null 2>&1; then
        ghostty --working-directory="$DIR" -e lazygit >/dev/null 2>&1 &
      else
        xdg-terminal-exec --dir="$DIR" lazygit >/dev/null 2>&1 &
      fi
      esc_dir="$(json_escape "$DIR")"
      echo "{\"success\":true,\"action\":\"open-lazygit\",\"dir\":\"$esc_dir\"}"
    else
      echo "{\"success\":false,\"action\":\"open-lazygit\",\"error\":\"Invalid project directory\"}"
    fi
    ;;

  open-editor)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" && "$DIR" != -* ]]; then
      if command -v zeditor >/dev/null 2>&1; then
        zeditor -- "$DIR" >/dev/null 2>&1 &
      elif command -v zed >/dev/null 2>&1; then
        zed -- "$DIR" >/dev/null 2>&1 &
      elif command -v code >/dev/null 2>&1; then
        code -- "$DIR" >/dev/null 2>&1 &
      elif command -v cursor >/dev/null 2>&1; then
        cursor -- "$DIR" >/dev/null 2>&1 &
      elif command -v nvim >/dev/null 2>&1; then
        if command -v foot >/dev/null 2>&1; then
          foot -D "$DIR" nvim . >/dev/null 2>&1 &
        else
          xdg-terminal-exec --dir="$DIR" nvim . >/dev/null 2>&1 &
        fi
      else
        xdg-open -- "$DIR" >/dev/null 2>&1 &
      fi
      esc_dir="$(json_escape "$DIR")"
      echo "{\"success\":true,\"action\":\"open-editor\",\"dir\":\"$esc_dir\"}"
    else
      echo "{\"success\":false,\"action\":\"open-editor\",\"error\":\"Invalid project directory\"}"
    fi
    ;;

  pick-project-folder)
    # Generous but finite deadline: a hung zenity (dbus/display issues) must
    # not block the shared action process forever.
    SELECTED=$(run_with_deadline 300 zenity --file-selection --directory --title="Select Dev Project Folder" 2>/dev/null || true)
    if [[ -n "$SELECTED" && -d "$SELECTED" ]] && save_pinned_project "$SELECTED"; then
      esc_path="$(json_escape "$SELECTED")"
      echo "{\"success\":true,\"action\":\"pin-project\",\"path\":\"$esc_path\"}"
    else
      echo "{\"success\":false,\"action\":\"pick-project-folder\",\"canceled\":true}"
    fi
    ;;

  pin-project)
    if [[ -n "$TARGET" && -d "$TARGET" ]] && save_pinned_project "$TARGET"; then
      esc_path="$(json_escape "$TARGET")"
      echo "{\"success\":true,\"action\":\"pin-project\",\"path\":\"$esc_path\"}"
    else
      echo "{\"success\":false,\"action\":\"pin-project\",\"error\":\"Invalid target directory\"}"
    fi
    ;;

  unpin-project)
    rm -f "$PINNED_FILE"
    echo "{\"success\":true,\"action\":\"unpin-project\"}"
    ;;

  *)
    esc_action="$(json_escape "$ACTION")"
    echo "{\"success\":false,\"error\":\"Unknown action $esc_action\"}"
    exit 1
    ;;
esac
