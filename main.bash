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

if [ "$PWD" != "$TEMP_DIR" ]; then
  cleanup
else
  cd "$HOME"
  cleanup
fi

parse-options "$*"
TEMP_DIR="$HOME/.compile-node-helper-temp"
[ -n "$version" ] && N_VERSION="$version"

mkdir -p "$HOME/.compile-node-helper-temp"

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

    elif [ "$LINES" -le 10 ] && [ "$LINES" != "0" ]; then
      INDEX=1
      precho "\\n"
      while read -r few_version; do
        color "  ${INDEX}) $few_version\\n"
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
#######  DL & COMPILE  #######
##############################

if [[ "$N_VERSION" =~ [[:digit:]]$ ]]; then
  progress start "Downloading source code"
  echo curl -L --silent "https://nodejs.org/dist/v${N_VERSION}/node-v${N_VERSION}.tar.gz" >"${N_VERSION}.tar.gz"
  ZIP_NAME="${N_VERSION}.tar.gz"
  progress finish "$?"
else
  progress start "Downloading source code"
  curl -L --silent "https://nodejs.org/dist/${N_VERSION}">"${N_VERSION}"
  ZIP_NAME="${N_VERSION}"
  progress finish "$?"
fi

if [ "$(filesize "$ZIP_NAME")" -lt 1000 ]; then
  color "  Warning\\n"
  precho "File $ZIP_NAME seems too small to be source code."
  precho "Download may have failed and fetched an html page instead"
fi
