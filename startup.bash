#!/usr/bin/env bash
source "./src/storage.bash"

k=$1
if [ -z "$k" ]; then
  echoerr "Usage: $0 <number_of_nodes>"
  exit 1
fi

echoerr "Starting a ${k}-node network."

sto_start_network "$k"