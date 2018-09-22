#! /usr/bin/env bash

set -e

HUE=$((RANDOM % 56 + 164))

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
  unset N_VERSION LINES INDEX line_version few_version version test_fail DIR_NAME ZIP_NAME PAD HUE
}

precho() {
  printf "\\033[38;05;251m"
  echo -e "${PAD}$*"
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

isDecimal() {
  [[ "$*" =~ ^[[:digit:]]+$ ]] && return
  return 1
}

clearAndPause() {
  read -rt 2 || true;
  clear
}

pause() {
  precho "\\n"
  read -rt 2 || true;
}

repliedYes() {
 if [ "$REPLY" == "y" ] || [ "$REPLY" == "yes" ] || [ "$REPLY" == "Y" ] || [ "$REPLY" == "YES" ]; then
  return 0
fi
return 1
}
