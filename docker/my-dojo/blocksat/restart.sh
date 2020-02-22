#!/bin/bash
set -e

echo "## Start blocksat #############################"

blocksat_options=(
  -f $BLOCKSAT_FREQUENCY
)


blocksat-rx "${blocksat_options[@]}"

# Keep the container up
while true
do
  sleep 1
done
