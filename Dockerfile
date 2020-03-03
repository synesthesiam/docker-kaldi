ARG BUILD_FROM
FROM $BUILD_FROM

ARG MAKE_THREADS=8

COPY etc/qemu-arm-static /usr/bin/
COPY etc/qemu-aarch64-static /usr/bin/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget curl ca-certificates \
        libatlas-base-dev libatlas3-base gfortran \
        automake autoconf unzip sox libtool subversion \
        python3 python \
        git zlib1g-dev

COPY download/kaldi-2020.tar.gz /

# Set ATLASLIBDIR
COPY set-atlas-dir.sh /
RUN bash /set-atlas-dir.sh

RUN cd / && tar -xvf /kaldi-2020.tar.gz
COPY download/tools/* /download/
ENV DOWNLOAD_DIR=/download

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

# Fix symbolic links in kaldi/src/lib
COPY fix-links.sh /
RUN bash /fix-links.sh /kaldi-master/src/lib/*.so*

RUN apt-get install patchelf
COPY etc/install-kaldi.sh etc/kaldi_dir_files.txt etc/kaldi_flat_files.txt /
RUN bash /install-kaldi.sh /kaldi-master /kaldi_flat_files.txt /kaldi_dir_files.txt /