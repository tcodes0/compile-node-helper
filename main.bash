#! /usr/bin/env bash
# shellcheck disable=SC1090 disable=SC2154

##############################
##########  SETUP  ###########
##############################

# exit on errors
set -e

for name in ./deps/optar.sh ./deps/progress.sh ./deps/dbash/main.bash utils.bash; do
  # shellcheck disable=SC1090
  source "$name" || bailout "Dependency $name failed. Try cloning the repo?"
done

cleanup
parse-options "$*"

# Globals.
TEMP_DIR="$HOME/.compile-node-helper-temp"
[ -n "$version" ] && N_VERSION="$version"
PAD="  "

mkdir -p "$TEMP_DIR"

##############################
####  PROMPT FOR VERSION  ####
##############################

cd "$TEMP_DIR"
filter_non_link_tags='/^<a/!d'
link_tags_to_strings='s/^<a [^>]+>([^<]+)<[/]a>.*$/\1/g'
curl -L --silent https://nodejs.org/dist/ | gsed -Ee "$filter_non_link_tags" | gsed -Ee "$link_tags_to_strings" | tr -d / >download-options.txt

while [ ! -n "$N_VERSION" ]; do
  precho "\\n"
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
      if [ "$REPLY" == "y" ] || [ "$REPLY" == "yes" ] || [ "$REPLY" == "Y" ] || [ "$REPLY" == "YES" ]; then
        N_VERSION="$line_version"
      fi

    elif [ "$LINES" -le 30 ] && [ "$LINES" != "0" ]; then
      INDEX=1
      precho "\\n"
      while read -r few_version; do
        color "${PAD}${INDEX}) $few_version\\n"
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
fi

##############################
##########  COMPILE  #########
##############################

precho "\\n"

[ -n "$ZIP_NAME" ] && DIR_NAME=node-v${ZIP_NAME%.tar.gz}
DIR_NAME=node-v${N_VERSION%.tar.gz}

# don't extract twice the same zip
if [ ! -d "$DIR_NAME" ]; then
  tar xf 6.14.0.tar.gz
fi

cd "$DIR_NAME"
if ! ./configure >/dev/null 2>&1; then
  precho "To see errors and get help run: '${PWD}/configure'"
  bailout "./configure didn't run successfully."
fi

# don't compile twice the same version
if [ ! -f "./out/Release/node" ]; then
  precho "Compilation takes a while and is CPU heavy."
  progress start "Compiling"
  make "-j$(sysctl -n hw.ncpu)" >/dev/null 2>&1
  progress finish "$?"
else
  precho "Already compiled"
fi

##############################
############ TEST  ###########
##############################

