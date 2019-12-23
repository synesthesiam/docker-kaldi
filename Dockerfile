ARG BUILD_FROM
FROM $BUILD_FROM

ARG MAKE_THREADS=8

COPY etc/qemu-arm-static /usr/bin/
COPY etc/qemu-aarch64-static /usr/bin/

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
        build-essential \
        wget curl ca-certificates \
        libatlas-base-dev libatlas3-base gfortran \
        automake autoconf unzip sox libtool subversion \
        python3 python \
        git zlib1g-dev


COPY download/kaldi-2019.tar.gz /

# Set ATLASLIBDIR
COPY set-atlas-dir.sh /
RUN bash /set-atlas-dir.sh

RUN cd / && tar -xvf /kaldi-2019.tar.gz

# Install tools
RUN cd /kaldi-master/tools && \
    make -j $MAKE_THREADS

# Fix things for aarch64 (arm64v8)
COPY linux_atlas_aarch64.mk /kaldi-master/src/makefiles/

RUN cd /kaldi-master/src && \
    ./configure --shared --mathlib=ATLAS --use-cuda=no

COPY fix-configure.sh /
RUN bash /fix-configure.sh

# Build Kaldi
RUN cd /kaldi-master/src && \
    make depend -j $MAKE_THREADS && \
    make -j $MAKE_THREADS

COPY files-to-keep.txt /