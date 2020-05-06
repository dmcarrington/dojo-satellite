FROM ubuntu:bionic

ENV SATELLITE_URL https://github.com/Blockstream/satellite.git

#################################################################
# INSTALL BLOCKSAT
#################################################################

# Dependencies
RUN apt-get update && apt install -y git make g++ libx11-dev libfftw3-dev \
	python3 rtl-sdr python3-pip

# Install blocksat-cli
RUN pip3 install blocksat-cli

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
RUN cd ~/src/ && git clone https://github.com/tsduck/tsduck.git

# reset to the last working commit (5/5/20)
RUN cd ~/src/tsduck && git reset --hard 9562c26b8525b6c508f881d1547067c89f3012bf && \
        make install CXX=g++ NOTELETEXT=1 NOSRT=1 NOPCSC=1 NOCURL=1 NODTAPI=1 && \
	echo \
	"\n# TSDuck\nsource ~/src/tsduck/src/tstools/release-x86_64/setenv.sh" \
	>> ~/.bashrc

# Copy USB rules for RTL-SDR
COPY    ./rtl-sdr.rules /etc/udev/rules.d/rtl-sdr.rules

# Copy blocksat config - do this last to avoid having to rebuild if we need to change it :)
COPY ./config.json /root/.blocksat/config.json

ENTRYPOINT ["blocksat-cli"]