FROM ubuntu:bionic

ENV SATELLITE_URL https://github.com/Blockstream/satellite.git

#################################################################
# INSTALL BLOCKSAT
#################################################################

# Dependencies
RUN apt update && apt install -y git make g++ libx11-dev libfftw3-dev \
	python3 rtl-sdr python3-pip

#RUN     set -ex && \
#        apt-get update && \
#        apt-get install -y software-properties-common && \
        #add-apt-repository ppa:blockstream/satellite && \
        #apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y satellite && \
#        apt install python3 python3-pip git
#        rm -rf /var/lib/apt/lists/*

# Leandvb
RUN mkdir -p ~/src/ && cd ~/src/ && \
	git clone --depth 1 --recursive https://github.com/Blockstream/leansdr.git && \
	cd leansdr/src/apps && \
	make && \
	install leandvb /usr/local/bin && \
	cd ../../LDPC/ && \
	make CXX=g++ ldpc_tool && \
	install ldpc_tool /usr/local/bin

# Tsduck
RUN cd ~/src/ && git clone https://github.com/tsduck/tsduck.git && \
	cd tsduck && \
	make NOTELETEXT=1 NOSRT=1 NOPCSC=1 NOCURL=1 NODTAPI=1 && \
	echo \
	"\n# TSDuck\nsource ~/src/tsduck/src/tstools/release-x86_64/setenv.sh" \
	>> ~/.bashrc

# Copy USB rules for RTL-SDR
COPY    ./rtl-sdr.rules /etc/udev/rules.d/rtl-sdr.rules

# Copy blocksat config
COPY ./config.json /root/.blocksat/config.json

ENTRYPOINT ["blocksat-cli"]