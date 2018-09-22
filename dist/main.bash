#! /usr/bin/env bash

##################################
# These are dependencies bundled in.
# Script starts around line 370.
#################################


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

parse-options() {
#input   - $@ or string containing shorts (-s), longs (--longs), and arguments
#returns - arrays with parsed data and opts set as vars
#exports a var for each option. (-s => $s, --foo => $foo, --long-opt => $long_opt)
#"-" are translated i(nto "_"
#"--" signals the end of options
#shorts take no arguments, to give args to an option use a --long=arg

if [[ "$1" == "--debug" ]]; then
  echo -e "\\n\\e[4;33m$(printf %${COLUMNS}s) $(center DEBUGGING "${FUNCNAME[0]}"!)$(printf %${COLUMNS}s)\\e[0m\\n"
  set -x
fi

if [[ "$#" == 0 ]]; then
  return
fi

# Opts we may have inherited from a parent function also using parse-options. Unset to void collisions.
if [ "$allOptions" ]; then
  for opt in "${allOptions[@]}"; do
    unset "$opt"
  done
fi

local argn long short noMoreOptions

#echo to split quoted args, repeat until no args left
for arg in $(echo "$@"); do
  argn=$((argn + 1))

  # if flag set
  if [[ "$noMoreOptions" ]]; then
    #end of options seen, just push remaining args
    arguments+=("$arg")
    continue
  fi

  # if end of options is seen
  if [[ "$arg" =~ ^--$ ]]; then
    # set flag to stop parsing
    noMoreOptions="true"
    continue
  fi

  # if long
  if [[ "$arg" =~ ^--[[:alnum:]] ]]; then
    #start on char 2, skip leading --
    long=${arg:2}
    # substitute any - with _
    long=${long/-/_}
    # if opt has an =, it means it has an arg
    if [[ "$arg" =~ ^--[[:alnum:]][[:alnum:]]+= ]]; then
      # split opt from arg. Ann=choco makes export ann=choco
      export ${long%=*}="${long#*=}"
      longsWithArgs+=(${long%=*})
    else
      #no arg, just push
      longs+=($long)
    fi
    continue
  fi

  # if short
  if [[ "$arg" =~ ^-[[:alnum:]] ]]; then
    local i=1 #start on 1, skip leading -
    # since shorts can be chained (-gpH), look at one char at a time
    while [ $i != ${#arg} ]; do
      short=${arg:$i:1}
        shorts+=($short)
      i=$((i + 1))
    done
    continue
  fi

  # not a long or short, push as an arg
  arguments+=($arg)
done

# give opts with no arguments value "true"
for short in ${shorts[@]}; do
  export $short="true"
done

for long in ${longs[@]}; do
  export $long="true"
done

export allOptions="$(get-shorts)$(get-longs)"
}

#part of parse-options
get-shorts() {
  if [ "$shorts" ]; then
    for short in ${shorts[@]}; do
      echo -ne "$short "
    done
  fi
}

#part of parse-options
get-longs() {
  if [ "$longs" ]; then
    for long in ${longs[@]}; do
      echo -ne "$long "
    done
  fi
  if [ "$longsWithArgs" ]; then
    for long in ${longsWithArgs[@]}; do
      echo -ne "${long}* "
    done
  fi
}

#part of parse-options
get-arguments() {
  for arg in ${arguments[@]}; do
    echo -ne "$arg "
  done
}

get-optionsWithArgs() {
  for opt in ${shortsWithArgs[@]}; do
    echo -ne "${opt}* "
  done
  for opt in ${longsWithArgs[@]}; do
    echo -ne "${opt}* "
  done
  printf "\\n"
}

function _eraseLine() {
  printf "\\r%${progress_line_length}s"
}

function _printMessageWithRunner() {
  printf "\\r%0s%s%s%${time_padding}s\\e[33m" '' "$progress_message" "$accumulated_runner" ''
}

function _show_longrunner() {
  local pad_right=$progress_pad_left
  local pos=1
  while :; do
    printf "\\r%${progress_pad_left}s%s%${pos}s%s" '' "$progress_message" '' "$progress_runner"
    pos=$((pos + 1))
    sleep "$progress_speed"
    if [[ "$pos" == "$pad_right" ]]; then
      pos=0
      _eraseLine
    fi
  done
}

function _show() {
  local accumulated_runner pad_right right_offset time_padding i
  accumulated_runner=$progress_runner
  pad_right=$progress_pad_left
  right_offset=$((progress_line_length / 10))
  i=0
  SECONDS=0

  while :; do
    time_padding=$((progress_line_length - ${#progress_message} - ${#accumulated_runner} - 5 - right_offset))
    _printMessageWithRunner
    _print_time $SECONDS
    printf "\\e[0m"
    i=$((i + 1))
    accumulated_runner=$accumulated_runner$progress_runner
    sleep "$progress_speed"
    if [[ "$i" == "$((pad_right / 2))" ]]; then
      i=0
      accumulated_runner=$progress_runner
      _eraseLine
    fi
  done
}

function _print() {
  local time_padding=$((progress_line_length - progress_pad_left - ${#progress_message} - ${#accumulated_runner} - 5))
  _printMessageWithRunner
  printf "     "
  printf "\\e[0m"
}

function progress() {
  case "$1" in
  "start")
    if [[ "$progress_pid" ]]; then
      printf "\\r%2s\\e[31m✘ %b\\n" '' "Progress is already running. Kill it with \\e[100;37mkill $progress_pid\\e[0m"
      exit 1
    fi
    shift
    progress_speed=0.075 #0.050 good for _show_longrunner
    progress_runner="."
    progress_message="$*"
    progress_line_length=$(tput cols)
    progress_pad_left=$(((progress_line_length - ${#progress_message} - ${#progress_runner}) / 2))
    _show &
    #removes last job put to bg from shell list. Now when killed, it says nothing to stdout.
    disown
    progress_pid="$!"
    ;;
  "finish")
    # hard to find a good value here. ${#accumulated_runner} can't be referenced because _show is called with &
    local time_padding=$(((progress_pad_left / 2) + ${#progress_message} + 4)) # +4: the emoji (3) + 1 space

    # echo time_padding $time_padding >foo.txt
    # echo progress_line_length "$progress_line_length" >>foo.txt
    # echo progress_pad_left $progress_pad_left >>foo.txt
    # echo progress_message ${#progress_message} >>foo.txt

    printf "\\r%${time_padding}s" '' #erases line from beginning to the clock
    if [ "${#progress_pid}" == "0" ]; then
      true # noop
    else
      kill "$progress_pid"
    fi
    progress_pad_left=$((progress_pad_left - 2))
    case "$2" in
    # will reprint the message with color indicating the status
    "0") #success
      printf "\\r%0s\\e[32m✔ %s\\e[0m\\n" '' "$progress_message"
      ;;
    "1") #failure
      printf "\\r%0s\\e[31m✘ %s\\e[0m\\n" '' "$progress_message"
      ;;
    "*") #other status, or no status passed
      printf "\\r%0s\\e[33m● %s\\e[0m\\n" '' "$progress_message"
      ;;
    esac
    unset progress_speed progress_runner progress_message progress_pid progress_line_length progress_pad_left
    ;;
  "total")
    shift
    progress_message="Total "
    local progress_message2=''
    if [[ -f "$1" ]]; then
      _print_time "$SECONDS" >>"$1"
      progress_message="Total✝ "
    fi
    progress_line_length=$(tput cols)
    progress_pad_left=$((progress_line_length - ${#progress_message} - 5))
    printf "%0s\\e[33;1m%s%s%s\\e[0m\\n" '' "$progress_message" "$(_print_time $SECONDS)" "$progress_message2"
    ;;
  "print")
    shift
    progress_message="$*"
    progress_line_length=$(tput cols)
    progress_pad_left=$(((progress_line_length - ${#progress_message} - ${#progress_runner}) / 2))
    _print
    ;;
  "error")
    local last="$?"
    if [ "$last" == 0 ]; then
      last=1
    fi
    shift
    progress finish "$last"
    ;;
  "die")
    progress error
    [[ ! "$-" =~ i ]] && exit 1
    return 1
    ;;
  *)
    echo "Please give a valid command"
    echo "start, finish, total or print"
    ;;
  esac
}

function _print_time() { #$1 - a number in seconds
  if [[ "$#" == 0 ]]; then exit 1; fi
  printf "%02d:%02d" "$(($1 / 60))" "$(($1 % 60))"
}

##############################
##########  SETUP  ###########
##############################

cleanup
parse-options "$*"

# Globals.
TEMP_DIR="$HOME/.compile-node-helper"
[ -n "$version" ] && N_VERSION="$version"
PAD=""

mkdir -p "$TEMP_DIR"

[ -n "$clean" ] && rm -rf "$TEMP_DIR" && exit 0

##############################
####  PROMPT FOR VERSION  ####
##############################

cd "$TEMP_DIR"
filter_non_link_tags='/^<a/!d'
link_tags_to_strings='s/^<a [^>]+>([^<]+)<[/]a>.*$/\1/g'
curl -L --silent https://nodejs.org/dist/ | gsed -Ee "$filter_non_link_tags" | gsed -Ee "$link_tags_to_strings" | tr -d / >download-options.txt

clear
while [ ! -n "$N_VERSION" ]; do
  precho "Please type a Node version to download."
  precho "Type 'all' too see all available ($(wc -l <download-options.txt | tr -d " ") versions)."
  precho "Or a partial string too see matches.\\n"

  if ! read -r; then
    exit "$?"
  fi
  if [ "$REPLY" != "all" ]; then
    gsed -Ene "/.*${REPLY}.*/p" <download-options.txt >selection.txt
    LINES=$(wc -l <selection.txt | tr -d " ")

    if [ "$LINES" == 1 ]; then
      line_version=$(gsed -Ene 1p <selection.txt | tr -d " \\n")
      precho "Proceed with $(color Node "$line_version") ? (y/n)\\n"
      if ! read -r; then
        exit "$?"
      fi
      if repliedYes; then
        N_VERSION="$line_version"
      fi

    elif [ "$LINES" -le 30 ] && [ "$LINES" != "0" ]; then
      INDEX=1
      precho "\\n"
      while read -r few_version; do
        color "${PAD}${INDEX} "
        precho "$few_version"
        ((INDEX += 1))
      done <selection.txt
      precho "\\n"
      precho "Please type a line number, or anything else to try again.\\n"
      if ! read -r; then
        exit "$?"
      fi
      if [[ "$REPLY" =~ ^[[:digit:]]{1,2}$ ]]; then
        # print line with sed
        N_VERSION="$(gsed -Ene "${REPLY}p" <selection.txt)"
      fi

    else
      precho "\\n"
      precho "Got $LINES matching Node versions."
      if [ "$LINES" != "0" ]; then
        precho "Type 'show' to see inside terminal. Type anything else to try again.\\n"
        read -r
        if [ "$REPLY" == "show" ]; then
          less selection.txt
        fi
      fi
    fi

  else
    less download-options.txt
  fi
done

precho "You selected $(color Node "$N_VERSION")"
clearAndPause

##############################
#########  DOWNLOAD  #########
##############################

# strip leading v
if [[ "$N_VERSION" =~ ^v ]]; then
  N_VERSION=${N_VERSION#v}
fi

# don't download twice the same zip
if [ ! -f "$N_VERSION.tar.gz" ] && [ ! -f "$N_VERSION" ]; then
  if [[ "$N_VERSION" =~ [[:digit:]]$ ]]; then
    progress start "Downloading source code"
    ZIP_NAME="${N_VERSION}.tar.gz"
    curl -L --silent "https://nodejs.org/dist/v${N_VERSION}/node-v${N_VERSION}.tar.gz" >"$ZIP_NAME"
    progress finish "$?"
  elif [[ "$N_VERSION" =~ ^latest ]]; then
    bailout "Downloading with latest isn't supported atm. Sorry :(\\n"
    # progress start "Downloading source code"
    # curl -L --silent "https://nodejs.org/dist/${N_VERSION}/node-v${N_VERSION}.tar.gz" >"${N_VERSION}.tar.gz"
    # ZIP_NAME="${N_VERSION}.tar.gz"
    # progress finish "$?"
  else
    VERSION_IS_ZIP_NAME="true"
    progress start "Downloading source code"
    ZIP_NAME="${N_VERSION}"
    curl -L --silent "https://nodejs.org/dist/${N_VERSION}" >"$ZIP_NAME"
    progress finish "$?"
  fi

  # catch failed downloads
  if [ -f "$ZIP_NAME" ]; then
    if isDecimal "$(filesize "$ZIP_NAME")" && [ "$(filesize "$ZIP_NAME")" -lt 1000 ]; then
      if grep --silent '<html' "$ZIP_NAME"; then
        mv "$ZIP_NAME" "${N_VERSION}-error.html"
        precho "Download failed and fetched an HTML page."
        precho "You can download manually from https://nodejs.org/dist/"
        bailout "404 or other download error\\n"
      fi
    fi
  fi
else
  color "${PAD}Already downloaded"
fi
clearAndPause

# manage naming differences
[[ "$N_VERSION" =~ ^node-v ]] && VERSION_IS_ZIP_NAME="true"
if [ ! -n "$ZIP_NAME" ]; then
  if [ -n "$VERSION_IS_ZIP_NAME" ]; then
    ZIP_NAME="$N_VERSION"
  else
    ZIP_NAME="${N_VERSION}.tar.gz"
  fi
fi

##############################
####  SETUP COMPILATION  #####
##############################

# check for tooling
if ! command -v gcc >/dev/null || ! command -v g++ >/dev/null; then
  setup_failed_tool="true"
  color "${PAD}Are 'gcc' and 'g++' installed?.\\n"
fi
if ! command -v clang >/dev/null || ! command -v clang++ >/dev/null; then
  setup_failed_tool="true"
  color "${PAD}Are 'clang' and 'clang++' installed?.\\n"
fi
if ! command -v python2.6 >/dev/null && ! command -v python2.7 >/dev/null; then
  if ! python --version 2>&1 | grep --silent -e 2.6 -e 2.7; then
    setup_failed_tool="true"
    color "${PAD}Is 'python2.6' or 'python2.7' installed?.\\n"
  fi
fi
if ! command -v make >/dev/null; then
  setup_failed_tool="true"
  color "${PAD}Is 'make' installed?.\\n"
fi

if [ -n "$setup_failed_tool" ]; then
  color "${PAD}Failed to find some required compilation tools installed.\\n"
  printTools
  bailout "Compilation tools not present\\n"
else
  # check for versions
  # setup_gcc_ver=? find out how gcc speaks
  setup_clang_ver=$(clang --version 2>&1 | gsed -Ene /version/p | gsed -Ee 's/^.*version (.*) \(clang.*$/\1/' | tr -d .)
  setup_make_ver=$(make -v | head -1 | gsed -Ee 's/^.*Make (.*)$/\1/' | tr -d .)

  if [ ! "$setup_clang_ver" -ge 342 ]; then
    setup_failed_version="true"
    color "${PAD}clang is too old.\\n"
  fi
  if [ ! "$setup_make_ver" -ge 381 ]; then
    setup_failed_version="true"
    color "${PAD}make is too old.\\n"
  fi

  if [ -n "$setup_failed_version" ]; then
    color "${PAD}Compilation tools are below minimum version.\\n"
    printTools
    bailout "Compilation tools are too old.\\n"
  fi
fi

##############################
#########  COMPILE  ##########
##############################

# manage naming differences
if [ -n "$VERSION_IS_ZIP_NAME" ]; then
  DIR_NAME="${N_VERSION%.tar.gz}"
else
  DIR_NAME="node-v${ZIP_NAME%.tar.gz}"
fi

# don't extract twice the same zip
if [ ! -d "$DIR_NAME" ]; then
  tar xf "$ZIP_NAME"
fi

cd "$DIR_NAME"
if ! ./configure >/dev/null 2>&1; then
  precho "To see errors and get help run: '${PWD}/configure'"
  bailout "./configure didn't run successfully.\\n"
fi

# don't compile twice the same version
if [ ! -f "./out/Release/node" ]; then
  precho "Note: Compilation takes a while and is CPU heavy."
  precho "\\n"
  # catch errors locally to stop spinner
  set +e
  progress start "Compiling"
  make "-j$(sysctl -n hw.ncpu)" >last-compile-stdout.txt 2>last-compile-stderr.txt || progress die
  progress finish "$?"
  set -e
else
  color "${PAD}Already compiled"
fi
clearAndPause

##############################
############ TEST ############
##############################

precho "After compiling it's recommended to run the test suite on the binary."

if isMac; then
  precho "On MacOS the tests make hundreds of firewall popups appear."
  precho "Node ships with a script to add firewall rules and prevent that,"
  precho "but it requires root access."
  precho "For more info run:"
  precho "'less +g\\/firewall ${PWD}/BUILDING.md'"
  precho "\\n"
  color "${PAD}a "
  precho "Authorize the script (your password will be required)."
  color "${PAD}* "
  precho "Run tests and get popups (it's not that bad)."
else
  precho "\\n"
fi

color "${PAD}s "
precho "Skip testing."
precho "\\n"
precho "Please type your selection. Type anything else to test."
precho "\\n"

if ! read -r; then exit "$?"; fi
precho "\\n"
if [ "$REPLY" == "a" ] || [ "$REPLY" == "A" ]; then
  sudo true
  set +e
  progress start "testing"
  sudo ./tools/macos-firewall.sh || progress die
  make test-only || progress die
  progress finish "$?"
  set -e
elif [ "$REPLY" == "s" ] || [ "$REPLY" == "S" ]; then
  color "${PAD}Skipping tests.\\n"
else
  set +e
  progress start "testing"
  if ! make "test-only" 1>test-stdout.txt 2>test-stderr.txt; then
    if ! make "test" 1>test-stdout.txt 2>test-stderr.txt; then
      test_fail="true"
      progress error
    fi
  fi
  [ ! -n "$test_fail" ] && echo progress finish "$?"
  set -e
fi
if [ -n "$test_fail" ]; then
  color "${PAD}Test suite exited with a failure status\\n"
  precho "Test output may have some information on what went wrong"
  precho "'less ${PWD}/test-stdout.txt'"
  precho "'less ${PWD}/test-stderr.txt'"
  precho "Hit return/enter to continue"
  read -r
else
  clearAndPause
fi

##############################
######### WRAPPING UP ########
##############################

progress total

precho "\\n"
color "${PAD}node --eval 'console.log(process.version)'\\n"
./out/Release/node --eval 'console.log(process.version)'
pause

precho "Done. Node is here:"
color "${PAD}${PWD}/out/Release/node\\n"
precho "Run 'node' to test the REPL? (y/n)"

read -r
if repliedYes; then
  color "${PAD}node\\n"
  ./out/Release/node
fi
