#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/share/mise/shims:$HOME/.local/share/mise/installs/gh/latest/gh_2.98.0_linux_amd64/bin:$PATH"

ACTION="${1:-}"
TARGET="${2:-}"
EXTRA="${3:-}"

case "$ACTION" in
  kill-pid)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[0-9]+$ && "$TARGET" -gt 1 ]]; then
      kill -15 "$TARGET" 2>/dev/null || kill -9 "$TARGET" 2>/dev/null || true
      echo "{\"success\":true,\"action\":\"kill-pid\",\"target\":$TARGET}"
    else
      echo "{\"success\":false,\"error\":\"Invalid PID\"}"
    fi
    ;;

  kill-port)
    if [[ -n "$TARGET" && "$TARGET" =~ ^[0-9]+$ ]]; then
      fuser -k -n tcp "$TARGET" 2>/dev/null || true
      echo "{\"success\":true,\"action\":\"kill-port\",\"port\":$TARGET}"
    else
      echo "{\"success\":false,\"error\":\"Invalid port\"}"
    fi
    ;;

  docker-start)
    if [[ -n "$TARGET" ]]; then
      docker start "$TARGET" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"docker-start\",\"target\":\"$TARGET\"}"
    fi
    ;;

  docker-stop)
    if [[ -n "$TARGET" ]]; then
      docker stop "$TARGET" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"docker-stop\",\"target\":\"$TARGET\"}"
    fi
    ;;

  docker-restart)
    if [[ -n "$TARGET" ]]; then
      docker restart "$TARGET" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"docker-restart\",\"target\":\"$TARGET\"}"
    fi
    ;;

  docker-logs)
    if [[ -n "$TARGET" ]]; then
      docker logs --tail 40 "$TARGET" 2>&1 || echo "No logs found for $TARGET"
    fi
    ;;

  compose-up)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      (cd "$DIR" && docker compose up -d 2>&1) || echo "Failed to run docker compose up"
    fi
    ;;

  compose-down)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      (cd "$DIR" && docker compose down 2>&1) || echo "Failed to run docker compose down"
    fi
    ;;

  git-checkout)
    DIR="${TARGET:-$HOME}"
    BRANCH="${EXTRA:-}"
    if [[ -d "$DIR" && -n "$BRANCH" ]]; then
      git -C "$DIR" checkout "$BRANCH" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-checkout\",\"branch\":\"$BRANCH\"}"
    fi
    ;;

  git-fetch)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      git -C "$DIR" fetch --all >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-fetch\"}"
    fi
    ;;

  git-pull)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      git -C "$DIR" pull >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-pull\"}"
    fi
    ;;

  git-push)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      git -C "$DIR" push >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-push\"}"
    fi
    ;;

  git-stash-pop)
    DIR="${TARGET:-$HOME}"
    STASH_IDX="${EXTRA:-0}"
    if [[ -d "$DIR" ]]; then
      git -C "$DIR" stash pop "stash@{$STASH_IDX}" >/dev/null 2>&1 || true
      echo "{\"success\":true,\"action\":\"git-stash-pop\",\"stash\":$STASH_IDX}"
    fi
    ;;

  open-browser)
    if [[ -n "$TARGET" ]]; then
      xdg-open "$TARGET" >/dev/null 2>&1 &
      echo "{\"success\":true,\"action\":\"open-browser\",\"url\":\"$TARGET\"}"
    fi
    ;;

  open-terminal)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
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
      echo "{\"success\":true,\"action\":\"open-terminal\",\"dir\":\"$DIR\"}"
    fi
    ;;

  open-lazygit)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
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
      echo "{\"success\":true,\"action\":\"open-lazygit\",\"dir\":\"$DIR\"}"
    fi
    ;;

  open-editor)
    DIR="${TARGET:-$HOME}"
    if [[ -d "$DIR" ]]; then
      if command -v zeditor >/dev/null 2>&1; then
        zeditor "$DIR" >/dev/null 2>&1 &
      elif command -v zed >/dev/null 2>&1; then
        zed "$DIR" >/dev/null 2>&1 &
      elif command -v code >/dev/null 2>&1; then
        code "$DIR" >/dev/null 2>&1 &
      elif command -v cursor >/dev/null 2>&1; then
        cursor "$DIR" >/dev/null 2>&1 &
      elif command -v nvim >/dev/null 2>&1; then
        if command -v foot >/dev/null 2>&1; then
          foot -D "$DIR" nvim . >/dev/null 2>&1 &
        else
          xdg-terminal-exec --dir="$DIR" nvim . >/dev/null 2>&1 &
        fi
      else
        xdg-open "$DIR" >/dev/null 2>&1 &
      fi
      echo "{\"success\":true,\"action\":\"open-editor\",\"dir\":\"$DIR\"}"
    fi
    ;;

  *)
    echo "{\"success\":false,\"error\":\"Unknown action $ACTION\"}"
    exit 1
    ;;
esac
