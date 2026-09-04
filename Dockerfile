#syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# A temporary build stage for copying over files and compiling programs.
# Only the essential directories will be copied over to the final image

FROM debian:bullseye AS build

# Debian bullseye end of life
RUN <<EOF cat >> /etc/apt/sources.list
deb http://security.debian.org/debian-security bullseye-security main
deb http://archive.debian.org/debian bullseye main
deb http://archive.debian.org/debian bullseye-updates main
EOF

RUN apt-get update --fix-missing -y

# install system dependencies
RUN apt update && apt install binutils gcc libgd-dev make -y

# Copy code source
COPY cxgn /cxgn

# Shrink cxgn R_libs from 2.2 GB -> 0.84 GB
# Strip unneeded symbols: https://dirk.eddelbuettel.com/blog/2017/08/20/#010_stripping_shared_libraries
# Could be --strip-debug instead of strip-unneeded, to be more conservative
RUN find cxgn/R_libs -type f -regex  '.*\(\.so\|\.so\..*\)$' | xargs strip --strip-unneeded

# Compile gtsimsrch
RUN cd /cxgn/gtsimsrch/src && make

# Compile contigalign (tiny, no need for aggresive cleaning)
RUN cd /cxgn/sgn/programs/ && make

# [RECOMMENDED] CLEANUPS
# Clean gtsimsrch testing and example data (~100MB)
RUN cd /cxgn/gtsimsrch/ && rm -rf data/ example/ testing/
# Clean R package docs (doc, help, html) (~100MB)
RUN rm -rf /cxgn/R_libs/*/doc /cxgn/R_libs/*/help /cxgn/R_libs/*/html

# [OPTIONAL] CLEANUPS
# Clean sgn non-html docs (~100MB)
# RUN rm -rf /cxgn/sgn/docs/BreedbaseManual.pdf /cxgn/sgn/docs/r_markdown_docs

# -----------------------------------------------------------------------------
# Final Image

FROM debian:bullseye AS final

# Debian bullseye end of life
RUN <<EOF cat >> /etc/apt/sources.list
deb http://security.debian.org/debian-security bullseye-security main
deb http://archive.debian.org/debian bullseye main
deb http://archive.debian.org/debian bullseye-updates main
EOF

RUN apt-get update --fix-missing -y

ENV CPANMIRROR=http://cpan.cpantesters.org
# based on the vagrant provision.sh script by Nick Morales <nm529@cornell.edu>

# open port 8080
#
EXPOSE 8080

# install system dependencies
#
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update -y --allow-unauthenticated
RUN apt-get upgrade -y
RUN apt-get install build-essential pkg-config apt-utils gnupg2 curl wget -y

# for R cran-40
#
RUN bash -c "apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' 1>/key.out 2> /key.err"


# add cran backports repo and required deps
#
RUN echo "deb https://cloud.r-project.org/bin/linux/debian/ bullseye-cran40/" >> /etc/apt/sources.list

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc |  apt-key add -

RUN apt-get update --fix-missing -y
#RUN apt-get update -y;

RUN apt-get install -y libimage-magick-perl libimage-exiftool-perl libterm-readline-zoid-perl nginx starman emacs gedit vim less sudo htop git dkms linux-headers-generic perl-doc ack make xutils-dev nfs-common lynx xvfb ncbi-blast+ primer3 libmunge-dev libmunge2 munge slurm-wlm slurmctld slurmd libslurm-perl libssl-dev graphviz lsof imagemagick mrbayes muscle clustalw bowtie bowtie2 postfix mailutils libcupsimage2 postgresql-client-18 libglib2.0-dev libglib2.0-bin screen apt-transport-https libgdal-dev libproj-dev libudunits2-dev locales locales-all rsyslog cron libnlopt0 plink rsync

# Set the locale correclty to UTF-8
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

RUN curl -L https://cpanmin.us | perl - --sudo App::cpanminus

RUN rm /etc/munge/munge.key

RUN chmod 777 /var/spool/ \
    && mkdir /var/spool/slurmstate \
    && chown slurm:slurm /var/spool/slurmstate/ \
    && /usr/sbin/mungekey \
    && ln -s /var/lib/slurm-llnl /var/lib/slurm \
    && mkdir -p /var/log/slurm

RUN apt-get install r-base r-base-dev -y --allow-unauthenticated

# required for R-package spdep, and other dependencies of agricolae
#
RUN apt-get install libudunits2-dev libproj-dev libgdal-dev -y

# XML::Simple dependency
#
RUN apt-get install libexpat1-dev -y

# HTML::FormFu
#
RUN apt-get install libcatalyst-controller-html-formfu-perl -y

# Cairo Perl module needs this:
#
RUN apt-get install libcairo2-dev -y

# GD Perl module needs this:
#
RUN apt-get install libgd-dev -y

# postgres driver DBD::Pg needs this:
#
RUN apt-get install libpq-dev -y

# MooseX::Runnable Perl module needs this:
#
RUN apt-get install libmoosex-runnable-perl -y

RUN apt-get install libgdbm6 libgdm-dev -y

RUN cpanm Selenium::Remote::Driver@1.49

#INSTALL OPENCV IMAGING LIBRARY

RUN apt-get install -y python3-dev  python3-pip python3-numpy libgtk2.0-dev libgtk-3-0 libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libhdf5-serial-dev libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libxvidcore-dev libatlas-base-dev gfortran cmake libgdal-dev exiftool libzbar-dev zbar-tools libbarcode-zbar-perl libtext-multimarkdown-perl

# Install python packages, strip unneeded symbols, clear cache
RUN pip3 install --upgrade pip \
    && pip3 install grpcio==1.40.0 imutils numpy matplotlib pillow statistics PyExifTool pytz pysolar scikit-image packaging pyzbar pandas opencv-python==4.13.0.92 \
    && pip3 install -U keras-tuner \
    && rm -rf /root/.cache/pip

# Install node
RUN apt remove -y nodejs \
  && wget https://nodejs.org/dist/v25.6.1/node-v25.6.1-linux-x64.tar.xz \
  && tar -xvf node-v25.6.1-linux-x64.tar.xz \
  && rm -f node-v25.6.1-linux-x64.tar.xz \
  && mkdir -p /opt/node \
  && mv node-v25.6.1-linux-x64 /opt/node/25.6.1 \
  && ln -f -s /opt/node/25.6.1/bin/node /usr/bin/node \
  && ln -f -s /opt/node/25.6.1/bin/npm /usr/bin/npm \
  && ln -f -s /opt/node/25.6.1/bin/npx /usr/bin/npx \
  && ln -f -s /opt/node/25.6.1/bin/corepack /usr/bin/corepack \
  && mkdir -p /home/production/.npm /home/production/.config \
  && touch /home/production/.npmrc

# Install gosu
RUN wget https://github.com/tianon/gosu/releases/download/1.19/gosu-amd64 \
  && chmod +x gosu-amd64 \
  && mv gosu-amd64 /usr/local/bin/gosu

# npm install needs a non-root user (new in latest version)
#
RUN adduser --disabled-password --gecos "" -u 1250 production \
  && mkdir -p /home/production/public/sgn_static_content \
  && chown -R production:production /home/production

# copy some tools that don't have a Debian package
#
COPY docker/breedbase/tools/gcta/gcta64  /usr/local/bin/
COPY docker/breedbase/tools/quicktree /usr/local/bin/
COPY docker/breedbase/tools/sreformat /usr/local/bin/



# copy code repos.
# This also adds the Mason website skins
#
COPY --chown=production:production --from=build /cxgn /home/production/cxgn
RUN git config --global --add safe.directory /home/production/cxgn/sgn
WORKDIR /home/production/cxgn

# System patches for postgres >= 17 and running as non-root user
RUN mkdir -p /etc/breedbase/system_patches \
  && chown production:production /etc/breedbase/system_patches

COPY --chown=production:production docker/breedbase/patches/cxgn_fixture.sql /etc/breedbase/patches/
COPY --chown=production:production docker/breedbase/patches/UpdatePhenotypeJsonbTableMaterializedViewIntercrop.pm /etc/breedbase/patches/
COPY --chown=production:production docker/breedbase/patches/ExternalReferences.pm /etc/breedbase/patches/
COPY --chown=production:production docker/breedbase/patches/Contact.pm /etc/breedbase/patches/
COPY --chown=production:production docker/breedbase/patches/Files.pm /etc/breedbase/patches/

COPY docker/breedbase/interactive.t /usr/local/bin/interactive.t
# Set npm cache to the volume mount location
RUN npm config set cache /home/production/npm --global


# create directory layout
#
RUN mkdir /etc/starmachine
RUN mkdir /var/log/sgn

# move this here so it is not clobbered by the cxgn move
#
COPY docker/breedbase/slurm.conf /etc/slurm/slurm.conf
COPY docker/breedbase/starmachine.conf /etc/starmachine/

COPY docker/breedbase/web_entrypoint.sh /entrypoint.sh
COPY docker/breedbase/web_setup /usr/local/bin/web_setup

COPY db_dumps /db_dumps

WORKDIR /home/production/cxgn/sgn

ENV PERL5LIB=/home/production/cxgn/bio-chado-schema/lib:/home/production/cxgn/local-lib/:/home/production/cxgn/local-lib/lib/perl5:/home/production/cxgn/sgn/lib:/home/production/cxgn/cxgn-corelibs/lib:/home/production/cxgn/Phenome/lib:/home/production/cxgn/Cview/lib:/home/production/cxgn/ITAG/lib:/home/production/cxgn/biosource/lib:/home/production/cxgn/tomato_genome/lib:/home/production/cxgn/chado_tools/chado/lib:.

ENV HOME=/home/production
ENV PGPASSFILE=/home/production/.pgpass
RUN echo "R_LIBS_USER=/home/production/cxgn/R_libs" >> /etc/R/Renviron
ENV R_LIBS_USER=/home/production/cxgn/R_libs

RUN ln -s /home/production/cxgn/starmachine/bin/starmachine_init.d /etc/init.d/sgn

ARG CREATED
ARG REVISION
ARG BUILD_VERSION

ENV VERSION=${BUILD_VERSION}
ENV BUILD_DATE=${CREATED}

LABEL maintainer="kmeaton1@ualberta.ca"
LABEL org.opencontainers.image.created=$CREATED
#LABEL org.opencontainers.image.url="https://breedbase.org/"
LABEL org.opencontainers.image.source="https://github.com/bff-afirms/breedbase_dockerfile"
LABEL org.opencontainers.image.version=$BUILD_VERSION
LABEL org.opencontainers.image.revision=$REVISION
LABEL org.opencontainers.image.vendor="University of Alberta"
LABEL org.opencontainers.image.title="bffafirms/breedbase"
LABEL org.opencontainers.image.description="BFF-AFIRMS Breedbase web server"
LABEL org.opencontainers.image.documentation="https://github.com/bff-afirms/breedbase_dockerfile/"



# start services when running container...
#
ENTRYPOINT ["/entrypoint.sh"]

# With docker compose, we will run as the host user instead
USER production
