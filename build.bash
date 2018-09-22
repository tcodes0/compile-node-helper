#! /usr/bin/env bash

{
  echo "\
#! /usr/bin/env bash

##################################
# These are dependencies bundled in.
# Script starts around line 400.
#################################
"
  gsed -Ene 2,9999p <utils.bash
  echo
  gsed -Ene 2,9999p <deps/optar.sh
  echo
  gsed -Ene 2,9999p <deps/progress.sh
  echo
  gsed -Ene 12,9999p <main.bash
} >dist/main.bash

chmod u+x dist/main.bash