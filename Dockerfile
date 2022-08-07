# For more information, please refer to https://aka.ms/vscode-docker-python
FROM ubuntu:20.04

ENV container docker
ENV TZ=Etc/UTC

USER root

RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

ARG DEBIAN_FRONTEND=noninteractive
RUN echo ========== Install dependencies ========== \
  && apt-get update && apt-get install -y \
  autoconf \
  automake \
  build-essential \
  ccache \
  cmake \
  cpufrequtils \
  doxygen \
  fort77 \
  g++ \
  git \
  gpsd \
  gpsd-clients \
  libasound2-dev \
  libboost-all-dev \
  libcanberra-gtk-module \
  libcomedi-dev \
  libcppunit-dev \
  libcppunit-doc \
  libfftw3-bin \
  libfftw3-dev \
  libfftw3-doc \
  libfontconfig1-dev \
  libgps-dev \
  libgsl-dev \
  liborc-0.4-0 \
  liborc-0.4-dev \
  libpulse-dev \
  libsdl1.2-dev \
  libtool \
  libudev-dev \
  libusb-1.0-0 \
  libusb-1.0-0-dev \
  libusb-dev \
  libxi-dev \
  libxrender-dev \
  libzmq3-dev \
  libzmq5 \
  ncurses-bin \
  python-setuptools \
  r-base-dev \
  sudo \
  supervisor \
  wget \
  xterm \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /home/root/install

COPY grc /home/root/install/grc-install/grc
COPY install_scripts /home/root/install/grc-install/install_scripts
COPY misc /home/root/install/grc-install/misc

RUN echo "========== Install dependencies for GNU Radio 3.8 & UHD  ==========" \
  && apt-get update && apt-get install -y \
  libgmp-dev swig python3-numpy python3-mako \
  python3-sphinx python3-lxml libqwt-qt5-dev \
  libqt5opengl5-dev python3-pyqt5 liblog4cpp5-dev \
  python3-yaml python3-click python3-click-plugins python3-zmq \
  python3-setuptools python3-opengl python3-pip \
  libwxgtk3.0-gtk3-dev \
  gnuplot \
  libfltk1.3-dev \
  python3-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /home/root/install/src
ARG UHD_38_VERSION="v3.15.0.0"
RUN echo "========== Clone UHD ==========" \
  && git clone --recursive https://github.com/EttusResearch/uhd \
  && cd uhd \
  && git checkout $UHD_38_VERSION \
  && git submodule update

ARG TARGET_PATH="/home/root/install/sdr"
WORKDIR /home/root/install/src/uhd/host/build

RUN echo "========== Install UHD from source ==========" \
  && mkdir /home/root/install/sdr
RUN cmake -DCMAKE_INSTALL_PREFIX=/home/root/install/sdr -DENABLE_PYTHON3=ON -DUHD_RELEASE_MODE=release ../
RUN make -j 2 \
  && make install

COPY udev-rules /etc/udev/rules.d/

RUN groupadd usrp && usermod -aG usrp root \
  && sh -c "echo '@usrp\t-\trtprio\t99' >> /etc/security/limits.conf"


WORKDIR /home/root/install/src
ARG GRC_38_VERSION="v3.8.2.0"
RUN echo "========== Clone GNURadio ==========" \
  && git clone --recursive https://github.com/gnuradio/gnuradio \
  && cd gnuradio \
  && git checkout $GRC_38_VERSION \
  && git submodule update

WORKDIR /home/root/install/src/gnuradio/build
RUN echo "========== Install GNURadio from source ==========" \
  && cmake -DCMAKE_INSTALL_PREFIX=$TARGET_PATH \
  -DUHD_DIR=$TARGET_PATH/lib/cmake/uhd/ \
  -DUHD_INCLUDE_DIRS=$TARGET_PATH/include/ \
  -DUHD_LIBRARIES=$TARGET_PATH/lib/libuhd.so \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  ../
RUN make \
  && make install


WORKDIR /home/root/install/sdr
ARG homedir=/home/root
RUN echo "========== Setup enviroment variables ==========" \
  && touch setup_env.sh \
  && echo -e "LOCALPREFIX=$TARGET_PATH" >> setup_env.sh \
  && echo -e "export PATH=\$LOCALPREFIX/bin:\$PATH" >> setup_env.sh \
  && echo -e "export LD_LOAD_LIBRARY=\$LOCALPREFIX/lib:\$LD_LOAD_LIBRARY" >> setup_env.sh \
  && echo -e "export LD_LIBRARY_PATH=\$LOCALPREFIX/lib:\$LD_LIBRARY_PATH" >> setup_env.sh \
  && echo -e "export PYTHONPATH=\$LOCALPREFIX/lib/python3.8/site-packages:\$PYTHONPATH" >> setup_env.sh \
  && echo -e "export PYTHONPATH=\$LOCALPREFIX/lib/python3/dist-packages:\$PYTHONPATH" >> setup_env.sh \
  && echo -e "export PKG_CONFIG_PATH=\$LOCALPREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH" >> setup_env.sh \
  && echo -e "export UHD_RFNOC_DIR=\$LOCALPREFIX/share/uhd/rfnoc/" >> setup_env.sh \
  && echo -e "export UHD_IMAGES_DIR=\$LOCALPREFIX/share/uhd/images" >> setup_env.sh \
  && echo -e "" >> setup_env.sh \
  && echo -e "########## for compiling software that depends on UHD" >> setup_env.sh \
  && echo -e "export UHD_DIR=\$LOCALPREFIX" >> setup_env.sh \
  && echo -e "export UHD_LIBRARIES=\$LOCALPREFIX/lib" >> setup_env.sh \
  && echo -e "export UHD_INCLUDE_DIRS=\$LOCALPREFIX/include" >> setup_env.sh \
  && echo -e "" >> setup_env.sh \
  && echo -e "########## these vars assist in follow-on install scripts" >> setup_env.sh \
  && echo -e "export SDR_TARGET_DIR=\$LOCALPREFIX" >> setup_env.sh \
  && echo -e "export SDR_SRC_DIR=$SRC_PATH" >> setup_env.sh \
  && echo -e "export GRC_38=$GRC_38" >> setup_env.sh \
  && echo -e "" >> $homedir/.bashrc \
  && echo -e "########## points to local install of gnuradio and uhd" >> $homedir/.bashrc \
  && echo -e "source $TARGET_PATH/setup_env.sh" >> $homedir/.bashrc

RUN echo "========== Download the UHD images ==========" \
  && $TARGET_PATH/bin/uhd_images_downloader

WORKDIR /home/root/install/grc-install/install_scripts
RUN ./install_scripts/grc_install_flabs_class.sh

WORKDIR /home/root
ENTRYPOINT ["/bin/bash"]

LABEL Name=grc-install Version=0.0.1