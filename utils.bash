#! /usr/bin/env bash

HUE=$((RANDOM % 56 + 112))

bailout() {
  local message=$*
  if [[ "$#" == "0" ]]; then
    message="error"
  fi
  echo -ne "\\e[1;31m❌\\040 $message\\e[0m"
  if [[ ! "$-" =~ i ]]; then
    exit 1
  fi
}

cleanup() {
  unset N_VERSION LINES INDEX line_version few_version
  local dir="$HOME/.compile-node-helper-temp"
  if [ -d "$dir" ]; then
    rm -rf "${dir:?}/*"
  fi
}

precho() {
  printf "\\033[38;05;251m"
  echo -e "  $*"
  printf "\\033[0m"
}

color() {
  printf "\\033[3;38;05;%sm" "$HUE"
  echo -ne "$*"
  printf "\\033[0m"
}

filesize() {
  echo -en "$(du -k "$*" | cut -f1)"
}
