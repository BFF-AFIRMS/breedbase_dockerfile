#syntax=docker/dockerfile:1

FROM debian:trixie-20260824 AS final

# -----------------------------------------------------------------------------
# Install system packages and tools

# Perform initial upgrade of system packages
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && apt update -y \
  && apt upgrade -y \
  && rm -rf /var/lib/apt/lists/*

# Install system development libraries
RUN apt update -y \
  && apt install -y \
    libavcodec-dev libavformat-dev libbarcode-zbar-perl libcairo2-dev \
    libcatalyst-controller-html-formfu-perl libcupsimage2 libexpat1-dev \
    libgd-dev libgdal-dev libgdbm6 libgdm-dev libglib2.0-bin libglib2.0-dev \
    libhdf5-serial-dev libgtk2.0-dev libgtk-3-0 libgtk-3-dev \
    libimage-exiftool-perl libimage-magick-perl libjpeg-dev \
    libmoosex-runnable-perl libmunge-dev libmunge2 libnlopt0 libopenblas-dev \
    libpng-dev libpq-dev libproj-dev libslurm-perl libssl-dev \
    libswscale-dev libtbb-dev libtbbmalloc2 libterm-readline-zoid-perl \
    libtext-multimarkdown-perl libtiff-dev libudunits2-dev libuv1-dev \
    libxvidcore-dev libzbar-dev \
  && rm -rf /var/lib/apt/lists/*

# Install system tools
RUN apt update -y \
  && apt install -y \
    ack apt-transport-https apt-utils binutils bowtie bowtie2 build-essential \
    clustalw cmake cron curl dkms emacs exiftool gcc gedit gfortran git \
    gnupg2 graphviz htop imagemagick less linux-headers-generic locales \
    locales-all lsof lynx mailutils make mrbayes munge muscle ncbi-blast+ \
    nfs-common nginx perl-doc pkg-config plink postfix primer3 r-base \
    r-base-dev rsync rsyslog screen slurm-wlm-basic-plugins starman \
    sudo vim xutils-dev wget xvfb zbar-tools \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install tools that need special configuration (ex. postgres)
RUN apt update -y \
  && apt install -y postgresql-common \
  && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
  && apt install -y postgresql-client-18 \
  && rm -rf /var/lib/apt/lists/*

# Install python packages
RUN apt update -y \
  && apt-get install -y \
    python3-dev python3-grpcio python3-matplotlib python3-numpy python3-opencv \
    python3-packaging python3-pandas python3-pillow python3-pip python3-pysolar \
    python3-pytz python3-setuptools python3-skimage python3-zbar \
  && pip3 install --break-system-packages PyExifTool keras-tuner imutils \
  && rm -rf /root/.cache/pip \
  && rm -rf /var/lib/apt/lists/*

# Install and configure nodejs, npm install needs a non-root user
ENV NODE_VERSION="25.6.1"
RUN wget https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz \
  && tar -xvf node-v${NODE_VERSION}-linux-x64.tar.xz \
  && rm -f node-v${NODE_VERSION}-linux-x64.tar.xz \
  && mkdir -p /opt/node \
  && mv node-v${NODE_VERSION}-linux-x64 /opt/node/${NODE_VERSION} \
  && ln -f -s /opt/node/${NODE_VERSION}/bin/node /usr/bin/node \
  && ln -f -s /opt/node/${NODE_VERSION}/bin/npm /usr/bin/npm \
  && ln -f -s /opt/node/${NODE_VERSION}/bin/npx /usr/bin/npx \
  && ln -f -s /opt/node/${NODE_VERSION}/bin/corepack /usr/bin/corepack \
  && mkdir -p /home/production/.npm /home/production/.config \
  && touch /home/production/.npmrc \
  && adduser --disabled-password --gecos "" -u 1250 production \
  && mkdir -p /home/production/public/sgn_static_content \
  && chown -R production:production /home/production \
  && npm config set cache /home/production/npm --global

# Install and configure slurm
# 20-11-4-1, 21-08-7-1
# 20.11.9:   https://download.schedmd.com/slurm/slurm-20.11.9.tar.bz2
# 21.08.8-2: https://download.schedmd.com/slurm/slurm-21.08.8-2.tar.bz2
# 22.05.11:  https://download.schedmd.com/slurm/slurm-22.05.11.tar.bz2
# 23.11.11:  https://download.schedmd.com/slurm/slurm-23.11.11.tar.bz2
# 24.11.7:   https://download.schedmd.com/slurm/slurm-24.11.7.tar.bz2
# 25.11.8:   https://download.schedmd.com/slurm/slurm-25.11.8.tar.bz2
# 26.05.4:   https://download.schedmd.com/slurm/slurm-26.05.4.tar.bz2
# ENV SLURM_VERSION="20-11-4-1"
#RUN wget https://github.com/SchedMD/slurm/archive/refs/tags/slurm-${SLURM_VERSION}.tar.gz \
#  && tar -xvf slurm-${SLURM_VERSION}.tar.gz \

ENV SLURM_VERSION="24.11.7"
RUN wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 \
  && tar -xvf slurm-${SLURM_VERSION}.tar.bz2 \
  && rm -f slurm-${SLURM_VERSION}.tar.gz \
  && mkdir -p /opt/slurm \
  && mv slurm-${SLURM_VERSION} /opt/slurm/${SLURM_VERSION} \
  && cd /opt/slurm/${SLURM_VERSION} \
  && ./configure \
  && make \
  && make install \
  && cd contribs \
  && make \
  && make install \
  && cd /opt \
  && rm -rf /opt/slurm

# Configure munge
RUN rm /etc/munge/munge.key \
  && /usr/sbin/mungekey \
  && chown munge:munge /etc/munge/munge.key

# Configure slurm directories and permissions
ENV SLURM_CONF=/usr/local/etc/slurm.conf
COPY docker/breedbase/slurm.conf ${SLURM_CONF}
#COPY docker/breedbase/cgroup.conf /etc/slurm/cgroup.conf
COPY docker/breedbase/cgroup.conf /usr/local/etc/cgroup.conf
RUN  chmod 777 /var/spool/ \
  && mkdir -p /var/spool/slurmstate && chown -R slurm:slurm /var/spool/slurmstate/ \
  && mkdir -p /var/spool/slurmd     && chown -R slurm:slurm /var/spool/slurmd/ \
  && mkdir -p /var/lib/slurm-llnl   && chown -R slurm:slurm /var/lib/slurm-llnl \
  && ln -s /var/lib/slurm-llnl /var/lib/slurm \
  && mkdir -p /var/log/slurm \
  && chown -R slurm:slurm /var/log/slurm \
  && mkdir -p /etc/slurm \
  && chown -R slurm:slurm /etc/slurm \
  && ln -s $SLURM_CONF /etc/slurm/slurm.conf \
  && ln -s /usr/local/etc/cgroup.conf /etc/slurm/cgroup.conf

# TBD, put slurm config in /etc/slurm/slurm.conf rather than symlink
# `./configure --sysconfdir=/etc/slurm` when compiling

# -----------------------------------------------------------------------------
# Install local application code, libraries, and dependencies

# Copy website repos and libraries
COPY --chown=production:production cxgn /home/production/cxgn
RUN git config --global --add safe.directory /home/production/cxgn/sgn

# Install tools that don't have a Debian package
COPY docker/breedbase/tools/gcta/gcta64  /usr/local/bin/
COPY docker/breedbase/tools/quicktree /usr/local/bin/
COPY docker/breedbase/tools/sreformat /usr/local/bin/

# System patches for postgres >= 17 and running as non-root user
COPY --chown=production:production docker/breedbase/patches /etc/breedbase/patches/
COPY docker/breedbase/interactive.t /usr/local/bin/interactive.t

# Link sgn server to starmachine
RUN ln -s /home/production/cxgn/starmachine/bin/starmachine_init.d /etc/init.d/sgn

# Compile gtsimsrch
RUN cd /home/production/cxgn/gtsimsrch/src \
  && make \
  && rm -rf ../data/ ../example/ ../testing/

# Compile contigalign, small program, no cleanup needed
RUN cd /home/production/cxgn/sgn/programs/ \
  && make

# Copy over config files, entrypoint scripts, database dumps
RUN mkdir /etc/starmachine
RUN mkdir /var/log/sgn
COPY docker/breedbase/starmachine.conf /etc/starmachine/
COPY docker/breedbase/web_entrypoint.sh /entrypoint.sh
COPY docker/breedbase/web_setup /usr/local/bin/web_setup
COPY db_dumps /db_dumps

# -----------------------------------------------------------------------------
# Install perl dependencies

ENV PERL5_LOCAL_LIB=/home/production/cxgn/local-lib
ENV PERL5LIB=/home/production/cxgn/bio-chado-schema/lib:${PERL5_LOCAL_LIB}/lib/perl5/:/home/production/cxgn/sgn/lib:/home/production/cxgn/cxgn-corelibs/lib:/home/production/cxgn/Phenome/lib:/home/production/cxgn/Cview/lib:/home/production/cxgn/ITAG/lib:/home/production/cxgn/biosource/lib:/home/production/cxgn/tomato_genome/lib:/home/production/cxgn/chado_tools/chado/lib:.

RUN curl -L https://cpanmin.us | perl - --sudo App::cpanminus \
  && cpanm --notest -L ${PERL5_LOCAL_LIB} Parse::Deb::Control \
  && rm -rf /root/.cpanm/work

# Takes a long time (~10 minutes), only uncomment the following RUN command
# when building fully from scratch (ex. operating system upgrade)
# Otherwise, pre-compiled ones are pulled from the github repo:
#   https://github.com/BFF-AFIRMS/perl-local-lib
# To extract libs after building:
#   docker run --rm -it -v $(pwd)/cxgn:/data/extract --entrypoint bash bffafirms/breedbase:<TAG> -c 'cp -r /home/production/cxgn/local-lib /data/extract'

# RUN for build_file in $(ls /home/production/cxgn/*/Build.PL); do \
#     cd $(dirname $build_file); \
#     perl Build.PL; \
#     cpanm --notest --installdeps -L ${PERL5_LOCAL_LIB} . ; \
#     cd -; \
#     done \
#   && rm -rf /root/.cpanm/work

# RUN chown -R production:production /home/production/cxgn/local-lib

# -----------------------------------------------------------------------------
# Install R dependencies

ENV HOME=/home/production
ENV R_LIBS_USER=/home/production/cxgn/R_libs
RUN echo "R_LIBS_USER=$R_LIBS_USER" >> /etc/R/Renviron

# Takes a long time (~? minutes), only uncomment the following RUN command
# when building fully from scratch (ex. operating system upgrade)
# Otherwise, pre-compiled ones are pulled from the github repo:
#   https://github.com/BFF-AFIRMS/R_libs
# To extract libs after building:
#   docker run --rm -it -v $(pwd)/cxgn:/data/extract --entrypoint bash bffafirms/breedbase:<TAG> -c 'cp -r /home/production/cxgn/R_libs /data/extract'

# # At the end, shrink R_libs from 2.2 GB -> 0.84 GB
# # by stripping unneeded symbols: https://dirk.eddelbuettel.com/blog/2017/08/20/#010_stripping_shared_libraries
# # # Could be --strip-debug instead of strip-unneeded, to be more conservative
# RUN perl /home/production/cxgn/sgn/Build installdeps \
#   && find /home/production/cxgn/R_libs -type f -regex  '.*\(\.so\|\.so\..*\)$' | xargs strip --strip-unneeded

# RUN chown -R production:production /home/production/cxgn/R_libs

# -----------------------------------------------------------------------------
# Final environment definitions

ARG CREATED
ARG REVISION
ARG BUILD_VERSION

ENV VERSION=${BUILD_VERSION}
ENV BUILD_DATE=${CREATED}
ENV PGPASSFILE=/home/production/.pgpass

LABEL maintainer="bffafirm@ualberta.ca"
LABEL org.opencontainers.image.created=$CREATED
LABEL org.opencontainers.image.url="https://sites.google.com/ualberta.ca/bff-afirms"
LABEL org.opencontainers.image.source="https://github.com/bff-afirms/breedbase_dockerfile"
LABEL org.opencontainers.image.version=$BUILD_VERSION
LABEL org.opencontainers.image.revision=$REVISION
LABEL org.opencontainers.image.vendor="University of Alberta"
LABEL org.opencontainers.image.title="bffafirms/breedbase"
LABEL org.opencontainers.image.description="BFF-AFIRMS Breedbase web server"
LABEL org.opencontainers.image.documentation="https://github.com/bff-afirms/breedbase_dockerfile/"

# start services when running container
ENTRYPOINT ["/entrypoint.sh"]

WORKDIR /home/production/cxgn/sgn

# With docker compose, we will run as the host user instead
USER production
