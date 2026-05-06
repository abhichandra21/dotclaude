#!/bin/bash

# Claude Code status line - mirrors Powerlevel10k Pure style
# Segments: dir [eks] [venv] [git] | model context%

input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# dir: convert to ~/... form
home_dir="$HOME"
if [[ "$cwd" == "$home_dir"* ]]; then
  rel_path="~${cwd#$home_dir}"
else
  rel_path="$cwd"
fi

# EKS cluster indicator — reads ~/.aws_sessions written by your session manager.
# Customize the case statement to match your own AWS profile names.
get_eks_cluster() {
  if [[ -f ~/.aws_sessions ]]; then
    local active_profile
    local session_mode
    active_profile=$(grep "^ACTIVE_PROFILE=" ~/.aws_sessions 2>/dev/null | cut -d'"' -f2)
    session_mode=$(grep "^SESSION_MODE=" ~/.aws_sessions 2>/dev/null | cut -d'"' -f2)
    if [[ "$session_mode" == "eks" && -n "$active_profile" ]]; then
      case "$active_profile" in
        *-dev)   printf "\033[32mλ dev\033[0m" ;;
        *-stage) printf "\033[33m☸ stage\033[0m" ;;
        *-prod)  printf "\033[31m☸ prod\033[0m" ;;
        *)       printf "\033[36m☸ %s\033[0m" "$active_profile" ;;
      esac
    fi
  fi
}

# Git branch + dirty/ahead/behind indicators (no lock contention)
get_git_status() {
  git -c gc.auto=0 rev-parse --git-dir > /dev/null 2>&1 || return
  local branch
  branch=$(git -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null \
    || git -c gc.auto=0 rev-parse --short HEAD 2>/dev/null)
  local suffix=""
  git -c gc.auto=0 diff-index --quiet HEAD -- 2>/dev/null || suffix="*"
  local ahead_behind
  ahead_behind=$(git -c gc.auto=0 rev-list --count --left-right "@{upstream}...HEAD" 2>/dev/null)
  if [[ -n "$ahead_behind" ]]; then
    local behind ahead
    behind=$(printf '%s' "$ahead_behind" | cut -f1)
    ahead=$(printf '%s'  "$ahead_behind" | cut -f2)
    [[ "$behind" != "0" ]] && suffix="${suffix}⇣"
    [[ "$ahead"  != "0" ]] && suffix="${suffix}⇡"
  fi
  printf "\033[33m%s\033[0m%s" "$branch" "$suffix"
}

# Python virtual environment (grey, matching p10k virtualenv segment)
get_venv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    printf "\033[38;5;242m%s\033[0m" "$(basename "$VIRTUAL_ENV")"
  elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    printf "\033[38;5;242m%s\033[0m" "$CONDA_DEFAULT_ENV"
  fi
}

eks=$(get_eks_cluster)
git_info=$(get_git_status)
venv=$(get_venv)

# Build left side: dir [eks] [venv] [git]
left=$(printf "\033[36m%s\033[0m" "$rel_path")
[[ -n "$eks"      ]] && left="$left \033[38;5;242m|\033[0m $eks"
[[ -n "$venv"     ]] && left="$left \033[38;5;242m|\033[0m $venv"
[[ -n "$git_info" ]] && left="$left \033[38;5;242m|\033[0m $git_info"

# Build right side: model [context%]
right=$(printf "\033[38;5;51m%s\033[0m" "$model")
if [[ -n "$used_pct" ]]; then
  # Color context bar: green <50%, yellow <80%, red >=80%
  pct_int=${used_pct%.*}
  if   [[ "$pct_int" -ge 80 ]]; then ctx_color="\033[31m"
  elif [[ "$pct_int" -ge 50 ]]; then ctx_color="\033[33m"
  else                                ctx_color="\033[32m"
  fi
  right="$right \033[38;5;242m|\033[0m ${ctx_color}${used_pct}%\033[0m"
fi

printf "%b \033[38;5;242m|\033[0m %b" "$left" "$right"
