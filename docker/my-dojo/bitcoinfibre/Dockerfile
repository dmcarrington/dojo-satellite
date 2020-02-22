FROM    ubuntu:bionic


#################################################################
# INSTALL BITCOIN
#################################################################
ENV     BITCOIN_HOME        /home/bitcoin
ENV     BITCOIN_VERSION     0.19.0.1
ENV     BITCOIN_URL         https://github.com/bitcoinfibre/bitcoinfibre/archive/master.zip
#ENV     BITCOIN_SHA256      732cc96ae2e5e25603edf76b8c8af976fe518dd925f7e674710c6c8ee5189204
#ENV     BITCOIN_ASC_URL     https://bitcoincore.org/bin/bitcoin-core-0.19.0.1/SHA256SUMS.asc
#ENV     BITCOIN_PGP_KS_URI  hkp://keyserver.ubuntu.com:80
#ENV     BITCOIN_PGP_KEY     01EA5486DE18A882D4C2684590C8019E36C2E964

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
        #echo "$BITCOIN_SHA256 bitcoin.tar.gz" | sha256sum -c - && \
        #gpg --batch --keyserver "$BITCOIN_PGP_KS_URI" --recv-keys "$BITCOIN_PGP_KEY" && \
        #wget -qO bitcoin.asc "$BITCOIN_ASC_URL" && \
        #gpg --batch --verify bitcoin.asc && \
        #tar -xzvf bitcoin.tar.gz -C /usr/local --strip-components=1 --exclude=*-qt && \
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