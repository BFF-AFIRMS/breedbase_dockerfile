#syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Multi-stage build to optimize final image size

FROM debian:bullseye AS build

# install system dependencies
RUN apt update && apt install binutils gcc libgd-dev make -y

# Copy code source
COPY cxgn /cxgn

# Shrink cxgn R_libs from 2.2 GB -> 0.84 GB
# Strip debug symbols: https://dirk.eddelbuettel.com/blog/2017/08/20/#010_stripping_shared_libraries
# Remove documentation (doc, help, html)
RUN strip --strip-debug /cxgn/R_libs/*/libs/*.so \
  && rm -rf /cxgn/R_libs/*/doc /cxgn/R_libs/*/help /cxgn/R_libs/*/html

# Compile and clean gtsimsrch: 126 MB -> 1.2 MB
RUN cd /cxgn/gtsimsrch/src \
  && make \
  && cd .. \
  && rm -rf data/ testing/

# Compile contigalign (tiny, no need for aggresive cleaning)
RUN cd /cxgn/sgn/programs/ && make

# -----------------------------------------------------------------------------
# Actual final build

FROM debian:bullseye

ENV CPANMIRROR=http://cpan.cpantesters.org
# based on the vagrant provision.sh script by Nick Morales <nm529@cornell.edu>

# open port 8080
#
EXPOSE 8080

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install dependencies
COPY build/install_system_packages.sh /tmp/install_system_packages.sh
COPY build/install_perl_packages.sh /tmp/install_perl_packages.sh
COPY build/install_python_packages.sh /tmp/install_python_packages.sh

RUN /tmp/install_system_packages.sh
RUN /tmp/install_perl_packages.sh
RUN /tmp/install_python_packages.sh

# create a non-root user
RUN adduser --disabled-password --gecos "" -u 1250 production && chown -R production:production /home/production

# copy code repos.
# This also adds the Mason website skins
COPY --chown=production:production --from=build /cxgn /home/production/cxgn

# copy some tools that don't have a Debian package
# stripping debug from these binaries has minimal improvement
COPY tools/gcta/gcta64  /usr/local/bin/
COPY tools/quicktree /usr/local/bin/
COPY tools/sreformat /usr/local/bin/

# Custom run_all_patches.pl script that doesn't leak credentials to log
COPY build/run_all_patches.pl /usr/local/bin/run_all_patches.pl

# move this here so it is not clobbered by the cxgn move
COPY slurm.conf /etc/slurm/slurm.conf
COPY starmachine.conf /etc/starmachine/
COPY entrypoint.sh /entrypoint.sh
COPY sgn_local.conf /home/production/cxgn/sgn/sgn_local.conf
RUN ln -s /home/production/cxgn/starmachine/bin/starmachine_init.d /etc/init.d/sgn

# configure R lib directory
RUN echo "R_LIBS_USER=/home/production/cxgn/R_libs" >> /etc/R/Renviron

WORKDIR /home/production/cxgn/sgn

ARG CREATED
ARG REVISION
ARG BUILD_VERSION

ENV PERL5LIB=/home/production/cxgn/bio-chado-schema/lib:/home/production/cxgn/local-lib/:/home/production/cxgn/local-lib/lib/perl5:/home/production/cxgn/sgn/lib:/home/production/cxgn/cxgn-corelibs/lib:/home/production/cxgn/Phenome/lib:/home/production/cxgn/Cview/lib:/home/production/cxgn/ITAG/lib:/home/production/cxgn/biosource/lib:/home/production/cxgn/tomato_genome/lib:/home/production/cxgn/chado_tools/chado/lib:.
ENV HOME=/home/production
ENV PGPASSFILE=/home/production/.pgpass
ENV R_LIBS_USER=/home/production/cxgn/R_libs
ENV VERSION=${BUILD_VERSION}
ENV BUILD_DATE=${CREATED}

LABEL maintainer="lam87@cornell.edu"
LABEL org.opencontainers.image.created=$CREATED
LABEL org.opencontainers.image.url="https://breedbase.org/"
LABEL org.opencontainers.image.source="https://github.com/solgenomics/breedbase_dockerfile"
LABEL org.opencontainers.image.version=$BUILD_VERSION
LABEL org.opencontainers.image.revision=$REVISION
LABEL org.opencontainers.image.vendor="Boyce Thompson Institute"
LABEL org.opencontainers.image.title="breedbase/breedbase"
LABEL org.opencontainers.image.description="Breedbase web server"
LABEL org.opencontainers.image.documentation="https://solgenomics.github.io/sgn/"

# start services when running container...
ENTRYPOINT ["/entrypoint.sh"]
