#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Source a file
source_file() {
  if [ -f $1 ]; then
    source $1
  elif [ -f "$1.tpl" ]; then
    source "$1.tpl"
  else
    echo "Unable to find file $1"
  fi
}

# Source config files
source_file "$DIR/conf/docker-indexer.conf"
source_file "$DIR/conf/docker-bitcoind.conf"
source_file "$DIR/conf/docker-explorer.conf"
source_file "$DIR/conf/docker-common.conf"
source_file "$DIR/.env"

# Export some variables for compose
export BITCOIND_RPC_EXTERNAL_IP

# Select YAML files
select_yaml_files() {
  yamlFiles="-f $DIR/docker-compose.yaml"

  if [ "$BITCOIND_INSTALL" == "on" ]; then
    if [ "$DOJO_USE_BLOCKSAT" == "true" ]; then
      yamlFiles="$yamlFiles -f $DIR/overrides/bitcoinsatellite.install.yaml"
      yamlFiles="$yamlFiles -f $DIR/overrides/blocksat2.install.yaml"
    else
      yamlFiles="$yamlFiles -f $DIR/overrides/bitcoind.install.yaml"
    fi

    if [ "$BITCOIND_RPC_EXTERNAL" == "on" ]; then
      yamlFiles="$yamlFiles -f $DIR/overrides/bitcoind.rpc.expose.yaml"
    fi
  fi

  if [ "$EXPLORER_INSTALL" == "on" ]; then
    yamlFiles="$yamlFiles -f $DIR/overrides/explorer.install.yaml"
  fi

  if [ "$INDEXER_INSTALL" == "on" ]; then
    yamlFiles="$yamlFiles -f $DIR/overrides/indexer.install.yaml"
  fi

  # Return yamlFiles
  echo "$yamlFiles"
}

# Docker up
docker_up() {
  yamlFiles=$(select_yaml_files)
  eval "docker-compose $yamlFiles up $1 -d"
}
  
# Start
start() {
  # Check if dojo is running (check the db container)
  isRunning=$(docker inspect --format="{{.State.Running}}" db 2> /dev/null)

  if [ $? -eq 1 ] || [ "$isRunning" == "false" ]; then
    docker_up --remove-orphans
  else
    echo "Dojo is already running."
  fi
}

# Stop
stop() {
  # Check if dojo is running (check the db container)
  isRunning=$(docker inspect --format="{{.State.Running}}" db 2> /dev/null)
  if [ $? -eq 1 ] || [ "$isRunning" == "false" ]; then
    echo "Dojo is already stopped."
    exit
  fi
  # Shutdown the bitcoin daemon
  if [ "$BITCOIND_INSTALL" == "on" ]; then
    # Renewal of bitcoind onion address
    if [ "$BITCOIND_EPHEMERAL_HS" = "on" ]; then
      docker exec -it tor rm -rf /var/lib/tor/hsv2bitcoind
    fi
    # Stop the bitcoin daemon
    echo "Preparing shutdown of dojo. Please wait."
    docker exec -it bitcoind  bitcoin-cli \
      -rpcconnect=bitcoind \
      --rpcport=28256 \
      --rpcuser="$BITCOIND_RPC_USER" \
      --rpcpassword="$BITCOIND_RPC_PASSWORD" \
      stop
    # Check if the bitcoin daemon is still up
    # wait 3mn max
    i="0"
    while [ $i -lt 18 ]
    do
      echo "Waiting for shutdown of Bitcoin server."
      # Check if bitcoind rpc api is responding
      timeout -k 12 10 docker exec -it bitcoind  bitcoin-cli \
        -rpcconnect=bitcoind \
        --rpcport=28256 \
        --rpcuser="$BITCOIND_RPC_USER" \
        --rpcpassword="$BITCOIND_RPC_PASSWORD" \
        getblockchaininfo > /dev/null
      # rpc api is down
      if [[ $? > 0 ]]; then
        echo "Bitcoin server stopped."
        break
      fi
      i=$[$i+1]
    done
    # Bitcoin daemon is still up
    # => force close
    if [ $i -eq 18 ]; then
      echo "Force shutdown of Bitcoin server."
    fi
  fi
  # Stop docker containers
  yamlFiles=$(select_yaml_files)
  echo "stopping $yamlFiles"
  eval "docker-compose $yamlFiles stop"
}

# Restart dojo
restart() {
  stop
  docker_up
}

# Install
install() {
  source "$DIR/install/install-scripts.sh"

  launchInstall=1
  auto=1
  noLog=1

  # Extract install options from arguments
  if [ $# -gt 0 ]; then
    for option in $@
    do
      case "$option" in
        --auto )    auto=0 ;;
        --nolog )   noLog=0 ;;
        * )         break ;;
      esac
    done
  fi

  # Confirmation
  if [ $auto -eq 0 ]; then
    launchInstall=0
  else
    get_confirmation
    launchInstall=$?
  fi

  # Detection of past install
  if [ $launchInstall -eq 0 ]; then
    pastInstallsfound=$(docker image ls | grep samouraiwallet/dojo-db | wc -l)
    if [ $pastInstallsfound -ne 0 ]; then
      # Past installation found. Ask confirmation forreinstall
      echo -e "\nWarning: Found traces of a previous installation of Dojo on this machine."
      echo "A new installation requires to remove these elements first."
      if [ $auto -eq 0 ]; then
        launchReinstall=0
      else
        get_confirmation_reinstall
        launchReinstall=$?
      fi

      if [ $launchReinstall -eq 0 ]; then
        echo ""
        # Uninstall
        if [ $auto -eq 0 ]; then
          uninstall --auto
          launchReinstall=$?
        else
          uninstall
          launchReinstall=$?
        fi
      fi

      if [ $launchReinstall -eq 1 ]; then
        launchInstall=1
        echo -e "\nInstallation was cancelled."
      fi
    fi
  fi

  # Installation
  if [ $launchInstall -eq 0 ]; then
    # Initialize the config files
    init_config_files
    # Build and start Dojo
    docker_up --remove-orphans
    # Display the logs
    if [ $noLog -eq 1 ]; then
      logs
    fi
  fi
}

# Delete everything
uninstall() {
  source "$DIR/install/uninstall-scripts.sh"

  auto=1

  # Extract install options from arguments
  if [ $# -gt 0 ]; then
    for option in $@
    do
      case "$option" in
        --auto )    auto=0 ;;
        * )         break ;;
      esac
    done
  fi

  docker image rm samouraiwallet/dojo-db:"$DOJO_DB_VERSION_TAG"
  docker image rm samouraiwallet/dojo-bitcoind:"$DOJO_BITCOIND_VERSION_TAG"
  docker image rm samouraiwallet/dojo-explorer:"$DOJO_EXPLORER_VERSION_TAG"
  docker image rm samouraiwallet/dojo-nodejs:"$DOJO_NODEJS_VERSION_TAG"
  docker image rm samouraiwallet/dojo-nginx:"$DOJO_NGINX_VERSION_TAG"
  docker image rm samouraiwallet/dojo-tor:"$DOJO_TOR_VERSION_TAG"
  docker image rm samouraiwallet/dojo-indexer:"$DOJO_INDEXER_VERSION_TAG"
  docker image rm samouraiwallet/dojo-bitcoinfibre:"$DOJO_BITCOIND_VERSION_TAG"
  docker image rm blocksat
  # Confirmation
  if [ $auto -eq 0 ]; then
    launchUninstall=0
  else
    get_confirmation
    launchUninstall=$?
  fi

  if [ $launchUninstall -eq 0 ]; then
    docker-compose rm -f

    yamlFiles=$(select_yaml_files)
    eval "docker-compose $yamlFiles down"

    docker image rm -f samouraiwallet/dojo-db:"$DOJO_DB_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-bitcoind:"$DOJO_BITCOIND_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-explorer:"$DOJO_EXPLORER_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-nodejs:"$DOJO_NODEJS_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-nginx:"$DOJO_NGINX_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-tor:"$DOJO_TOR_VERSION_TAG"
    docker image rm -f samouraiwallet/dojo-indexer:"$DOJO_INDEXER_VERSION_TAG"

    docker volume prune -f
    return 0
  else
    return 1
  fi
}

# Clean-up (remove old docker images)
del_images_for() {
  # $1: image name
  # $2: most recent version of the image (do not delete this one)
  docker image ls | grep "$1" | sed "s/ \+/,/g" | cut -d"," -f2 | while read -r version ; do 
    if [ "$2" != "$version" ]; then
      docker image rm "$1:$version"
    fi
  done
}

clean() {
  docker image prune
  del_images_for samouraiwallet/dojo-db "$DOJO_DB_VERSION_TAG"
  del_images_for samouraiwallet/dojo-bitcoind "$DOJO_BITCOIND_VERSION_TAG"
  del_images_for samouraiwallet/dojo-explorer "$DOJO_EXPLORER_VERSION_TAG"
  del_images_for samouraiwallet/dojo-nodejs "$DOJO_NODEJS_VERSION_TAG"
  del_images_for samouraiwallet/dojo-nginx "$DOJO_NGINX_VERSION_TAG"
  del_images_for samouraiwallet/dojo-tor "$DOJO_TOR_VERSION_TAG"
  del_images_for samouraiwallet/dojo-indexer "$DOJO_INDEXER_VERSION_TAG"
}

# Upgrade
upgrade() {
  source "$DIR/install/upgrade-scripts.sh"

  launchUpgrade=1
  auto=1
  noLog=1
  noCache=1

  # Extract upgrade options from arguments
  if [ $# -gt 0 ]; then
    for option in $@
    do
      case "$option" in
        --auto )      auto=0 ;;
        --nolog )     noLog=0 ;;
        --nocache )   noCache=0 ;;
        * )           break ;;
      esac
    done
  fi

  # Confirmation
  if [ $auto -eq 0 ]; then
    launchUpgrade=0
  else
    get_confirmation
    launchUpgrade=$?
  fi

  # Upgrade Dojo
  if [ $launchUpgrade -eq 0 ]; then
    # Select yaml files
    yamlFiles=$(select_yaml_files)
    # Update config files
    update_config_files
    # Cleanup
    cleanup
    # Load env vars for compose files
    source_file "$DIR/conf/docker-bitcoind.conf"
    export BITCOIND_RPC_EXTERNAL_IP
    # Rebuild the images (with or without cache)
    if [ $noCache -eq 0 ]; then
      eval "docker-compose $yamlFiles build --no-cache"
    else
      eval "docker-compose $yamlFiles build"
    fi
    # Start Dojo
    docker_up --remove-orphans
    # Update the database
    update_dojo_db
    # Display the logs
    if [ $noLog -eq 1 ]; then
      logs
    fi
  fi
}

# Display the onion address
onion() {
  if [ "$EXPLORER_INSTALL" == "on" ]; then
    V3_ADDR_EXPLORER=$( docker exec -it tor cat /var/lib/tor/hsv3explorer/hostname )
    echo "Explorer hidden service address (v3) = $V3_ADDR_EXPLORER"
  fi

  V2_ADDR=$( docker exec -it tor cat /var/lib/tor/hsv2dojo/hostname )
  V3_ADDR=$( docker exec -it tor cat /var/lib/tor/hsv3dojo/hostname )
  echo "API hidden service address (v3) = $V3_ADDR"
  echo "API hidden service address (v2) = $V2_ADDR"

  if [ "$BITCOIND_INSTALL" == "on" ]; then
    V2_ADDR_BTCD=$( docker exec -it tor cat /var/lib/tor/hsv2bitcoind/hostname )
    echo "bitcoind hidden service address (v2) = $V2_ADDR_BTCD"
  fi
}

# Display the version of this dojo
version() {
  echo "Dojo v$DOJO_VERSION_TAG"
}

# Display logs
logs_node() {
  if [ $3 -eq 0 ]; then
    docker exec -ti nodejs tail -f /data/logs/$1-$2.log
  else
    docker exec -ti nodejs tail -n $3 /data/logs/$1-$2.log
  fi 
}

logs_explorer() {
  if [ $3 -eq 0 ]; then
    docker exec -ti explorer tail -f /data/logs/$1-$2.log
  else
    docker exec -ti explorer tail -n $3 /data/logs/$1-$2.log
  fi 
}

logs() {
  source_file "$DIR/conf/docker-bitcoind.conf"
  source_file "$DIR/conf/docker-indexer.conf"
  source_file "$DIR/conf/docker-common.conf"

  case $1 in
    db )
      docker-compose logs --tail=50 --follow db
      ;;
    bitcoind )
      if [ "$BITCOIND_INSTALL" == "on" ]; then
        if [ "$COMMON_BTC_NETWORK" == "testnet" ]; then
          bitcoindDataDir="/home/bitcoin/.bitcoin/testnet3"
        else
          bitcoindDataDir="/home/bitcoin/.bitcoin"
        fi
        docker exec -ti bitcoind tail -f "$bitcoindDataDir/debug.log"
      else
        echo -e "Command not supported for your setup.\nCause: Your Dojo is using an external bitcoind"
      fi
      ;;
    indexer )
      if [ "$INDEXER_INSTALL" == "on" ]; then
        yamlFiles=$(select_yaml_files)
        eval "docker-compose $yamlFiles logs --tail=50 --follow indexer"
      else
        echo -e "Command not supported for your setup.\nCause: Your Dojo is not using an internal indexer"
      fi
      ;;
    tor )
      docker-compose logs --tail=50 --follow tor
      ;;
    api | pushtx | pushtx-orchest | tracker )
      logs_node $1 $2 $3
      ;;
    explorer )
      logs_explorer $1 $2 $3
      ;;
    * )
      yamlFiles=$(select_yaml_files)
      services="nginx node tor db" 
      if [ "$BITCOIND_INSTALL" == "on" ]; then
        services="$services bitcoind"
      fi
      if [ "$EXPLORER_INSTALL" == "on" ]; then
        services="$services explorer"
      fi
      if [ "$INDEXER_INSTALL" == "on" ]; then
        services="$services indexer"
      fi
      eval "docker-compose $yamlFiles logs --tail=0 --follow $services"
      ;;
  esac
}

#create_blocksat() {
#  git clone https://github.com/Blockstream/satellite.git
#  cd satellite
#  python3 setup.py sdist
#  cd docker
#  # TODO get config.json into /root/.blocksat/config.json
#  docker build -t blockstream/blocksat-usb -f usb.docker ..
#}

# Display the help
help() {
  echo "Usage: dojo.sh command [module] [options]"
  echo "Interact with your dojo."
  echo " "
  echo "Available commands:"
  echo " "
  echo "  help                          Display this help message."
  echo " "
  echo "  bitcoin-cli                   Launch a bitcoin-cli console allowing to interact with your full node through its RPC API."
  echo " "
  echo "  clean                         Free disk space by deleting docker dangling images and images of previous versions."
  echo " "
  echo "  install                       Install your dojo."
  echo " "
  echo "                                Available options:"
  echo "                                  --nolog     : do not display the logs after Dojo has been laucnhed."
  echo " "
  echo "  logs [module] [options]       Display the logs of your dojo. Use CTRL+C to stop the logs."
  echo " "
  echo "                                Available modules:"
  echo "                                  dojo.sh logs                : display the logs of all the Docker containers"
  echo "                                  dojo.sh logs bitcoind       : display the logs of bitcoind"
  echo "                                  dojo.sh logs db             : display the logs of the MySQL database"
  echo "                                  dojo.sh logs tor            : display the logs of tor"
  echo "                                  dojo.sh logs indexer        : display the logs of the internal indexer"
  echo "                                  dojo.sh logs api            : display the logs of the REST API (nodejs)"
  echo "                                  dojo.sh logs tracker        : display the logs of the Tracker (nodejs)"
  echo "                                  dojo.sh logs pushtx         : display the logs of the pushTx API (nodejs)"
  echo "                                  dojo.sh logs pushtx-orchest : display the logs of the pushTx Orchestrator (nodejs)"
  echo "                                  dojo.sh logs explorer       : display the logs of the Explorer"
  echo " "
  echo "                                Available options (only available for api, tracker, pushtx, pushtx-orchest and explorer modules):"
  echo "                                  -d [VALUE]                  : select the type of log to be displayed."
  echo "                                                                VALUE can be output (default) or error."
  echo "                                  -n [VALUE]                  : display the last VALUE lines"
  echo " "
  echo "  onion                         Display the Tor onion address allowing your wallet to access your dojo."
  echo " "
  echo "  restart                       Restart your dojo."
  echo " "
  echo "  start                         Start your dojo."
  echo " "
  echo "  stop                          Stop your dojo."
  echo " "
  echo "  uninstall                     Delete your dojo. Be careful! This command will also remove all data."
  echo " "
  echo "  upgrade [options]             Upgrade your dojo."
  echo " "
  echo "                                Available options:"
  echo "                                  --nolog     : do not display the logs after Dojo has been restarted."
  echo "                                  --nocache   : rebuild the docker containers without reusing the cached layers."
  echo " "
  echo "  version                       Display the version of dojo"
}


#
# Parse options to the dojo command
#
while getopts ":h" opt; do
  case ${opt} in
    h )
      help
      exit 0
      ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
  esac
done

shift $((OPTIND -1))


subcommand=$1; shift

case "$subcommand" in
  bitcoin-cli )
    if [ "$BITCOIND_INSTALL" == "on" ]; then
      docker exec -it bitcoind bitcoin-cli \
        -rpcconnect=bitcoind \
        --rpcport=28256 \
        --rpcuser="$BITCOIND_RPC_USER" \
        --rpcpassword="$BITCOIND_RPC_PASSWORD" \
        $1 $2 $3 $4 $5
      else
        echo -e "Command not supported for your setup.\nCause: Your Dojo is using an external bitcoind"
      fi
    ;;
  help )
    help
    ;;
  clean )
    clean
    ;;
  install )
    install "$@"
    ;;
  logs )
    module=$1; shift
    display="output"
    numlines=0

    # Process package options
    while getopts ":d:n:" opt; do
      case ${opt} in
        d )
          display=$OPTARG
          ;;
        n )
          numlines=$OPTARG
          ;;
        \? )
          echo "Invalid Option: -$OPTARG" 1>&2
          exit 1
          ;;
        : )
          echo "Invalid Option: -$OPTARG requires an argument" 1>&2
          exit 1
          ;;
      esac
    done
    shift $((OPTIND -1))

    logs $module $display $numlines
    ;;
  onion )
    onion
    ;;
  restart )
    restart
    ;;
  start )
    start
    ;;
  stop )
    stop
    ;;
  uninstall )
    uninstall "$@"
    ;;
  upgrade )
    upgrade "$@"
    ;;
  version )
    version
    ;;
esac
