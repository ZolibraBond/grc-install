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

WORKDIR /root/install

COPY grc /root/install/grc-install/grc
COPY install_scripts /root/install/grc-install/install_scripts
COPY misc /root/install/grc-install/misc

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

WORKDIR /root/install/src
ARG UHD_38_VERSION="v3.15.0.0"
RUN echo "========== Clone UHD ==========" \
  && git clone --recursive https://github.com/EttusResearch/uhd \
  && cd uhd \
  && git checkout $UHD_38_VERSION \
  && git submodule update

ARG INSTALL_PATH="/root/install"
ARG TARGET_PATH="/root/install/sdr"
ARG SRC_PATH="/root/install/src"
WORKDIR /root/install/src/uhd/host/build

RUN echo "========== Install UHD from source ==========" \
  && mkdir /root/install/sdr
RUN cmake -DCMAKE_INSTALL_PREFIX=/root/install/sdr -DENABLE_PYTHON3=ON -DUHD_RELEASE_MODE=release ../
RUN make -j 2 \
  && make install

COPY udev-rules /etc/udev/rules.d/

RUN groupadd usrp && usermod -aG usrp root \
  && sh -c "echo '@usrp\t-\trtprio\t99' >> /etc/security/limits.conf"


WORKDIR /root/install/src
ARG GRC_38_VERSION="v3.8.2.0"
RUN echo "========== Clone GNURadio ==========" \
  && git clone --recursive https://github.com/gnuradio/gnuradio \
  && cd gnuradio \
  && git checkout $GRC_38_VERSION \
  && git submodule update

WORKDIR /root/install/src/gnuradio/build
RUN echo "========== Install GNURadio from source ==========" \
  && cmake -DCMAKE_INSTALL_PREFIX=$TARGET_PATH \
  -DUHD_DIR=$TARGET_PATH/lib/cmake/uhd/ \
  -DUHD_INCLUDE_DIRS=$TARGET_PATH/include/ \
  -DUHD_LIBRARIES=$TARGET_PATH/lib/libuhd.so \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 \
  ../
RUN make \
  && make install


WORKDIR /root/install/sdr
ARG homedir=/root
RUN echo "========== Setup enviroment variables ==========" \
  && /bin/echo -e "LOCALPREFIX=$TARGET_PATH" >> $homedir/.bashrc \
  && /bin/echo -e "export PATH=\$LOCALPREFIX/bin:\$PATH" >> $homedir/.bashrc \
  && /bin/echo -e "export LD_LOAD_LIBRARY=\$LOCALPREFIX/lib:\$LD_LOAD_LIBRARY" >> $homedir/.bashrc \
  && /bin/echo -e "export LD_LIBRARY_PATH=\$LOCALPREFIX/lib:\$LD_LIBRARY_PATH" >> $homedir/.bashrc \
  && /bin/echo -e "export PYTHONPATH=\$LOCALPREFIX/lib/python3.8/site-packages:\$PYTHONPATH" >> $homedir/.bashrc \
  && /bin/echo -e "export PYTHONPATH=\$LOCALPREFIX/lib/python3/dist-packages:\$PYTHONPATH" >> $homedir/.bashrc \
  && /bin/echo -e "export PKG_CONFIG_PATH=\$LOCALPREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH" >> $homedir/.bashrc \
  && /bin/echo -e "export UHD_RFNOC_DIR=\$LOCALPREFIX/share/uhd/rfnoc/" >> $homedir/.bashrc \
  && /bin/echo -e "export UHD_IMAGES_DIR=\$LOCALPREFIX/share/uhd/images" >> $homedir/.bashrc \
  && /bin/echo -e "" >> $homedir/.bashrc \
  && /bin/echo -e "########## for compiling software that depends on UHD" >> $homedir/.bashrc \
  && /bin/echo -e "export UHD_DIR=\$LOCALPREFIX" >> $homedir/.bashrc \
  && /bin/echo -e "export UHD_LIBRARIES=\$LOCALPREFIX/lib" >> $homedir/.bashrc \
  && /bin/echo -e "export UHD_INCLUDE_DIRS=\$LOCALPREFIX/include" >> $homedir/.bashrc \
  && /bin/echo -e "" >> $homedir/.bashrc \
  && /bin/echo -e "########## these vars assist in follow-on install scripts" >> $homedir/.bashrc \
  && /bin/echo -e "export SDR_TARGET_DIR=\$LOCALPREFIX" >> $homedir/.bashrc \
  && /bin/echo -e "export SDR_SRC_DIR=$SRC_PATH" >> $homedir/.bashrc \
  && /bin/echo -e "export GRC_38=true" >> $homedir/.bashrc

RUN echo "========== Download the UHD images ==========" \
  && $TARGET_PATH/bin/uhd_images_downloader

ARG SDR_TARGET_DIR=/root/install/sdr
ARG SDR_SRC_DIR=/root/install/src
ARG GRC_38=true

WORKDIR /root/install/src
RUN echo "========== Clone gr-reveng ==========" \
  && git clone --recursive https://github.com/paulgclark/gr-reveng \
  && cd gr-reveng \
  && git checkout master \
  && git submodule update

WORKDIR /root/install/src/gr-reveng/build
RUN echo "========== Build gr-reveng ==========" \
  && cmake -DCMAKE_INSTALL_PREFIX=$TARGET_PATH ../\
  && make -j 2 \
  && make install

WORKDIR /root/install/src
RUN echo "========== Clone hackrf ==========" \
  && git clone --recursive https://github.com/mossmann/hackrf.git \
  && cd hackrf \
  && git checkout v2018.01.1 \
  && git submodule update

WORKDIR /root/install/src/hackrf/host/build
RUN echo "========== Install hackrf ==========" \
  && cmake -DCMAKE_INSTALL_PREFIX=$SDR_TARGET_DIR -DINSTALL_UDEV_RULES=OFF ../ \
  && make -j 2 \
  && make install

WORKDIR /root/install/src
RUN echo "========== Clone gr-osmosdr ==========" \
  && git clone --recursive https://github.com/igorauad/gr-osmosdr \
  && cd gr-osmosdr \
  && git checkout f3905d3510dfb3851f946f097a9e2ddaa5fb333b \
  && git submodule update

WORKDIR /root/install/src/gr-osmosdr/build
RUN echo "========== Install gr-osmosdr ==========" \
  && cmake -DCMAKE_INSTALL_PREFIX=$SDR_TARGET_DIR ../ \
  && make -j 2 \
  && make install

WORKDIR /root/install/src
RUN echo "========== Clone additional python classes ==========" \
  && git clone --recursive https://github.com/ZolibraBond/rf_utilities \
  && cd gr-reveng \
  && git checkout master \
  && git submodule update \
  && /bin/echo "" >> ~/.bashrc \
  && /bin/echo "################################" >> ~/.bashrc \
  && /bin/echo "# Custom code for gnuradio class" >> ~/.bashrc \
  && /bin/echo "export PYTHONPATH=\$PYTHONPATH:$SRC_PATH/rf_utilities"  >> ~/.bashrc \
  && /bin/echo "" >> ~/.bashrc

WORKDIR /home/root
ENTRYPOINT ["/bin/bash"]
