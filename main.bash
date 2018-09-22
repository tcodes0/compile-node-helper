#! /usr/bin/env bash
# shellcheck disable=SC1090 disable=SC2154

##############################
##########  SETUP  ###########
##############################

# exit on errors
set -e

for name in ./deps/optar.sh ./deps/progress.sh utils.bash; do
  # shellcheck disable=SC1090
  source "$name" || bailout "Dependency $name failed. Try cloning the repo?\\n"
done

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
