FROM ubuntu:bionic

#################################################################
# INSTALL BLOCKSAT
#################################################################

RUN     set -ex && \
        apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository ppa:blockstream/satellite && \
        apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y satellite && \
        rm -rf /var/lib/apt/lists/*

# Copy restart script
COPY    ./restart.sh /restart.sh
RUN     chmod 777 /restart.sh

# Copy wait-for-it script
COPY    ./wait-for-it.sh /wait-for-it.sh

RUN        chmod u+x /wait-for-it.sh && \
           chmod g+x /wait-for-it.sh

# Copy USB rules for RTL-SDR
COPY    ./rtl-sdr.rules /etc/udev/rules.d/rtl-sdr.rules
