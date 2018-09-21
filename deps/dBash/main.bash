#! /usr/bin/env bash

alias conditional='ternary'
alias all='and'
alias any='or'

export MUTEOUT=\>/dev/null
export MUTEERR=2\>/dev/null
export MUTE="$MUTEOUT $MUTEERR"

#- - - - - - - - - - -

noop() {
  true
}

#- - - - - - - - - - -

exitwith() {
  [ $# == 0 ] && return 0
  return "$1"
}

#- - - - - - - - - - -

exitstatus() {
  return $?
}

#- - - - - - - - - - -

iflast() { # add a not first arg to invert logic
  local previous=$?
  [ $previous != 0 ] && return $previous
  eval "$@"
}

#- - - - - - - - - - -

not() { # make it invert the last exit status
  [ $# == 0 ] && return 1
  eval "$@" && return 1
  return 0
}

#- - - - - - - - - - -

truthy() { # remove truthy
  [ $# == 0 ] && return 1
  [ "$1" ] && return ${#1}
  return 1
}

#- - - - - - - - - - -

ok() {
  [ $# == 0 ] && return 1
  local predicate="$*" isNotTruthyTestOrInvalid='^-[[:alpha:]][ ][^ ]+|[^ ]+[ ]-[[:alpha:]][[:alpha:]][ ][^ ]+|[^ ]+[ ]=[ ][^ ]+|[^ ]+[ ]==[ ][^ ]+|[^ ]+[ ]!=[ ][^ ]+|[^ ]+[ ]<[ ][^ ]+|[^ ]+[ ]>[ ][^ ]+'
  if [[ "$predicate" =~ $isNotTruthyTestOrInvalid ]]; then
    # shellcheck disable=SC2086
    [ $predicate ] 2>/dev/null && return 0
  fi
  return 1
}

#- - - - - - - - - - -

splitQC() {
  # foo ? bar : baz -> "foo" "bar" "baz"
  # args: strings
  # returns: sets array SPLITQC
  local args="$*" temp
  # foo[ ? bar : baz] -> remove [...]
  SPLITQC[0]=${args% '?' * ':' *}
  # foo ? bar[ : baz]
  temp=${args% : *}
  # [foo ? ]bar
  SPLITQC[1]=${temp#* '?' }
  # [foo ? bar : ]baz
  SPLITQC[2]=${args#* '?' * ':' }
  export SPLITQC
}

splitC() {
  # foo : bar -> "foo" "bar"
  # args: strings
  # returns: sets array SPLITC
  local args="$*"
  # foo[ : bar] -> remove [...]
  SPLITC[0]=${args% ':' *}
  # [foo : ]bar
  SPLITC[1]=${args#* ':' }
  export SPLITC
}

firstWord() {
  # args: strings
  # returns: FIRSTWORD var
  if [[ "$*" =~ ^[[:space:]]*([^ ]+) ]]; then
    FIRSTWORD=${BASH_REMATCH[1]}
    export FIRSTWORD
    return 0
  fi
  return 1
}

ternary() {
  [ $# -lt 5 ] && return 1
  # reject malformed arguments. This is good: foo ? a : b.
  [[ ! "$*" =~ [[:space:]]+[?][[:space:]]+[^:]+[[:space:]]+[:][[:space:]]+ ]] && return 1

  local condition pass fail passCommand failCommand
  splitQC "$@"
  condition=${SPLITQC[0]}
  pass=${SPLITQC[1]}
  fail=${SPLITQC[2]}

  firstWord "$pass" && passCommand=${FIRSTWORD}
  firstWord "$fail" && failCommand=${FIRSTWORD}
  # if it's not a command, assume it's a value and append printf
  if ! command -v "$passCommand" >/dev/null; then pass="printf \"$pass\""; fi
  if ! command -v "$failCommand" >/dev/null; then fail="printf \"$fail\""; fi
  # "false" will fail implicitly.
  if [[ "$condition" =~ "true" ]]; then eval "$pass" && return; fi
  # main logic
  if ok "$condition"; then
    eval "$pass"
  else
    eval "$fail"
  fi
}

#- - - - - - - - - - -

ifdo() { #probably remove ok. make it exit status based
  [ $# -lt 2 ] && return 1
  splitC "$@"
  condition=${SPLITC[0]}
  commands=${SPLITC[1]}
  if [[ "$condition" =~ "true" ]]; then eval "$commands" && return; fi
  if ok "$condition"; then eval "$commands" && return; fi
  return 1
}

#- - - - - - - - - - -

status() {
  local status=$?
  if [ "$#" == 0 ]; then echo $status && return 0; fi
  eval "$@" >/dev/null 2>&1
  echo $?
}

#- - - - - - - - - - -

trim() {
  # todo: proper trim using a for reading each char
  true
}

#- - - - - - - - - - -

mute() {
  [ "$#" == 0 ] && return 1

  case $1 in
  "1")
    shift && eval "$@" "$MUTEOUT"
    ;;
  "2")
    shift && eval "$@" "$MUTEERR"
    ;;
  *)
    eval "$@" "$MUTE"
    ;;
  esac

  return 0
}

#- - - - - - - - - - -

and() {
  [ "$#" == 0 ] && return 1
  for ((i = 1; i <= ${#}; i++)); do
    if ! eval "\$$i"; then return 1; fi
  done
  return 0
}

#- - - - - - - - - - -

or() {
  [ "$#" == 0 ] && return 1
  for ((i = 1; i <= ${#}; i++)); do
    if eval "\$$i"; then return 0; fi
  done
  return 1
}

#- - - - - - - - - - -

iscommand() {
  [ "$#" == 0 ] && return 1
  command -v "$1" >/dev/null || return 1
}

# improve readme to showcase the lib in the examples.