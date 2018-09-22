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
  read -rt 2 || true
  clear
}

pause() {
  precho "\\n"
  read -rt 2 || true
}

repliedYes() {
  if [ "$REPLY" == "y" ] || [ "$REPLY" == "yes" ] || [ "$REPLY" == "Y" ] || [ "$REPLY" == "YES" ]; then
    return 0
  fi
  return 1
}

printTools() {
  precho <<<"
  ### Unix/macOS
    #### Prerequisites

    * gcc and g++ 4.9.4 or newer, or
    * clang and clang++ 3.4.2 or newer (macOS: latest Xcode Command Line Tools)
    * Python 2.6 or 2.7
    * GNU Make 3.81 or newer

    On macOS, you will need to install the 'Xcode Command Line Tools' by running
    'xcode-select --install'. This step will install 'clang', 'clang++', and
    'make'.
  "
  precho "See '${PWD}/BUILDING.md'"
}

isMac(){
  [[ "$(uname -s)" =~ Darwin ]] && return 0
  return 1
}

isUnix(){
  [[ "$(uname -s)" =~ Darwin ]] || [[ "$(uname -s)" =~ Linux ]] && return 0
  return 1
}

isWindows(){
  [[ ! "$(uname -s)" =~ Darwin ]] && [[ ! "$(uname -s)" =~ Linux ]] && return 0
  return 1
}