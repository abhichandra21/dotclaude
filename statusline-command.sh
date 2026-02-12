#!/bin/bash

# Claude Code status line script based on Powerlevel10k configuration
# Replicates the shell prompt with EKS cluster, git status, and virtual environment

# Read JSON input from stdin
input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Function to get EKS cluster status (matching Powerlevel10k config)
get_eks_cluster() {
  if [[ -f ~/.aws_sessions ]]; then
    local active_profile=$(grep "^ACTIVE_PROFILE=" ~/.aws_sessions 2>/dev/null | cut -d'"' -f2)
    local session_mode=$(grep "^SESSION_MODE=" ~/.aws_sessions 2>/dev/null | cut -d'"' -f2)

    if [[ "$session_mode" == "eks" && -n "$active_profile" ]]; then
      case "$active_profile" in
        "shared-rsc-dev") printf "\033[32mλ dev\033[0m" ;;
        "shared-rsc-stage") printf "\033[33m☸ stage\033[0m" ;;
        "shared-rsc-prod") printf "\033[31m☸ prod\033[0m" ;;
        *) printf "\033[36m☸ $active_profile\033[0m" ;;
      esac
    fi
  fi
}

# Function to get git status
get_git_status() {
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local status=""
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
      status="*"
    fi
    
    # Check for ahead/behind status
    local ahead_behind=$(git rev-list --count --left-right @{upstream}...HEAD 2>/dev/null)
    if [[ -n "$ahead_behind" ]]; then
      local behind=$(echo "$ahead_behind" | cut -f1)
      local ahead=$(echo "$ahead_behind" | cut -f2)
      
      if [[ "$behind" != "0" ]]; then
        status="${status}:⇣"
      fi
      if [[ "$ahead" != "0" ]]; then
        status="${status}:⇡"
      fi
    fi
    
    printf "\033[33m$branch\033[0m$status"
  fi
}

# Function to get virtual environment
get_venv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    printf "\033[38;5;242m$(basename "$VIRTUAL_ENV")\033[0m"
  elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    printf "\033[38;5;242m$CONDA_DEFAULT_ENV\033[0m"
  fi
}

# Convert absolute path to relative path with ~ prefix if possible
home_dir="$HOME"
if [[ "$cwd" == "$home_dir"* ]]; then
  relative_path="~${cwd#$home_dir}"
else
  relative_path="$cwd"
fi
dir_display=$(printf "\033[36m$relative_path\033[0m")
eks_cluster=$(get_eks_cluster)
git_status=$(get_git_status)
venv=$(get_venv)

# Combine all components
components=("$dir_display")
[[ -n "$eks_cluster" ]] && components+=("$eks_cluster")
[[ -n "$venv" ]] && components+=("$venv")
[[ -n "$git_status" ]] && components+=("$git_status")

# Join with spaces
status=$(IFS=" "; echo "${components[*]}")

# Add model name at the end if it's not the default
if [[ "$model" != "Claude 3.5 Sonnet" ]]; then
  printf "$status | \033[36m$model\033[0m"
else
  printf "$status"
fi