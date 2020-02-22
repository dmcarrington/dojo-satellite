FROM    ubuntu:bionic


#################################################################
# INSTALL BLOCKSAT
#################################################################

RUN     set -ex && \
        apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository ppa:blockstream/satellite && \
        apt-get update && \
        apt-get install -y satellite && \
        rm -rf /var/lib/apt/lists/*

# Create groups bitcoin & tor
# Create user bitcoin and add it to groups
RUN     addgroup --system -gid 1108 bitcoin && \
        addgroup --system -gid 1107 tor && \
        adduser --system --ingroup bitcoin -uid 1105 bitcoin && \
        usermod -a -G tor bitcoin

# Copy restart script
COPY    ./restart.sh /restart.sh
RUN     chown bitcoin:bitcoin /restart.sh && \
        chmod 777 /restart.sh

# Copy wait-for-it script
COPY    ./wait-for-it.sh /wait-for-it.sh

RUN     chown bitcoin:bitcoin /wait-for-it.sh && \
        chmod u+x /wait-for-it.sh && \
        chmod g+x /wait-for-it.sh

USER    bitcoin