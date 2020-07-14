ARG distro=ubuntu:bionic
FROM $distro
ARG distro
MAINTAINER Blockstream Satellite

SHELL ["/bin/bash", "-c"]
RUN if [[ $distro == *"ubuntu"* ]]; then \
	apt update && DEBIAN_FRONTEND=noninteractive apt install -y python3-pip git; \
	elif [[ $distro == *"fedora"* ]]; then \
	dnf update -y && dnf install -y python3-pip; \
	else \
	yum update -y && yum install -y python3-pip; \
	fi

# Install the local distribution of the CLI
RUN git clone https://github.com/Blockstream/satellite.git /tmp/satellite
RUN cd /tmp/satellite && python3 setup.py sdist && cd
RUN pip3 install /tmp/satellite/dist/blocksat-cli-*.tar.gz


# Copy blocksat config - do this last to avoid having to rebuild if we need to change it :)
COPY ./config.json /root/.blocksat/config.json

# Install SDR software dependencies via the CLI
RUN blocksat-cli --debug deps -y install

# Install USB software dependencies via the CLI
#RUN blocksat-cli --debug deps -y --target usb install
