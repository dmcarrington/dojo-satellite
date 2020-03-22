FROM    ubuntu:bionic


#################################################################
# INSTALL BITCOINFIBRE
#################################################################
ENV     BITCOIN_HOME        /home/bitcoin
ENV     BITCOIN_VERSION     0.19.0.1
ENV     BITCOIN_URL         https://github.com/bitcoinfibre/bitcoinfibre/archive/master.zip

RUN     set -ex && \
        apt-get update && \
        apt-get install -qq software-properties-common && \
        add-apt-repository ppa:bitcoin/bitcoin && \
        apt-get update && \
        apt-get install -qq --no-install-recommends ca-certificates dirmngr gosu gpg wget && \
        apt-get install -qq libevent-dev libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev && \
        apt-get install -qq libdb4.8-dev libdb4.8++-dev libzmq3-dev libminiupnpc-dev && \
        apt-get install -qq unzip make curl gcc g++ automake libtool patch pkg-config bsdmainutils libssl-dev && \
        rm -rf /var/lib/apt/lists/*

# Build and install bitcoin binaries
RUN     set -ex && \
        cd /tmp && \
        wget -qO bitcoin.zip "$BITCOIN_URL" && \
        unzip bitcoin.zip && \
        cd bitcoinfibre-master/depends && make NO_QT=1 && \
        cd .. && ./autogen.sh && \
        ./configure --without-gui && \
        make install && \
        rm -rf /tmp/*

# Create groups bitcoin & tor
# Create user bitcoin and add it to groups
RUN     addgroup --system -gid 1108 bitcoin && \
        addgroup --system -gid 1107 tor && \
        adduser --system --ingroup bitcoin -uid 1105 bitcoin && \
        usermod -a -G tor bitcoin

# Create data directory
RUN     mkdir "$BITCOIN_HOME/.bitcoin" && \
        chown -h bitcoin:bitcoin "$BITCOIN_HOME/.bitcoin"

# Copy restart script
COPY    ./restart.sh /restart.sh
RUN     chown bitcoin:bitcoin /restart.sh && \
        chmod 777 /restart.sh

# Copy wait-for-it script
COPY    ./wait-for-it.sh /wait-for-it.sh

RUN     chown bitcoin:bitcoin /wait-for-it.sh && \
        chmod u+x /wait-for-it.sh && \
        chmod g+x /wait-for-it.sh

EXPOSE  8333 9501 9502 28256

USER    bitcoin