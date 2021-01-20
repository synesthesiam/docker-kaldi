FROM ubuntu:eoan

ARG MAKE_THREADS=8

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        wget curl ca-certificates \
        libatlas-base-dev libatlas3-base gfortran \
        automake autoconf unzip sox libtool subversion \
        python3 python \
        git zlib1g-dev patchelf rsync

COPY download/kaldi-2021.tar.gz /

# Set ATLASLIBDIR
COPY set-atlas-dir.sh /
RUN bash /set-atlas-dir.sh

RUN cd / && tar -xvf /kaldi-2021.tar.gz
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

# Create dist
RUN mkdir -p /dist/kaldi/egs && \
    cp -R /kaldi-master/egs/wsj /dist/kaldi/egs/ && \
    rsync -av --exclude='*.o' --exclude='*.cc' /kaldi-master/src/bin/ /dist/kaldi/ && \
    cp /kaldi-master/src/lib/*.so* /dist/kaldi/ && \
    rsync -av --include='*.so*' --include='fst' --exclude='*' /kaldi-master/tools/openfst/lib/ /dist/kaldi/ && \
    cp /kaldi-master/tools/openfst/bin/ /dist/kaldi/

# Fix rpaths
RUN find /dist/kaldi/ -type f -exec patchelf --set-rpath '$ORIGIN' {} \;

# Compress
RUN tar -C /dist -czvf /kaldi.tar.gz .
