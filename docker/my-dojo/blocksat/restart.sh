#!/bin/bash
set -e

echo "## Start blocksat #############################"

blocksat_options=(
  -f $BLOCKSAT_FREQUENCY
)

# Avoid timeout waiting for stdin in docker compose
sleep infinity | blocksat-rx "${blocksat_options[@]}"

# Keep the container up
while true
do
  sleep 1
done
