#!/bin/bash

# install system dependencies
#
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
apt-get update -y --allow-unauthenticated
apt-get upgrade -y
apt-get install build-essential pkg-config apt-utils gnupg2 curl wget -y

# for R cran-40
#
bash -c "apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' 1>/key.out 2> /key.err"


# add cran backports repo and required deps
#
echo "deb https://cloud.r-project.org/bin/linux/debian/ bullseye-cran40/" >> /etc/apt/sources.list

echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc |  apt-key add -

apt-get update --fix-missing -y
#apt-get update -y;

apt-get install -y aptitude

aptitude install -y npm libimage-magick-perl libimage-exiftool-perl libterm-readline-zoid-perl nginx starman emacs gedit vim less sudo htop git dkms linux-headers-generic perl-doc ack make xutils-dev nfs-common lynx xvfb ncbi-blast+ primer3 libmunge-dev libmunge2 munge slurm-wlm slurmctld slurmd libslurm-perl libssl-dev graphviz lsof imagemagick mrbayes muscle clustalw bowtie bowtie2 postfix mailutils libcupsimage2 postgresql-client-12 libglib2.0-dev libglib2.0-bin screen apt-transport-https libgdal-dev libproj-dev libudunits2-dev locales locales-all rsyslog cron libnlopt0 plink

# Set the locale correclty to UTF-8
locale-gen en_US.UTF-8

curl -L https://cpanmin.us | perl - --sudo App::cpanminus

rm /etc/munge/munge.key

chmod 777 /var/spool/ \
    && mkdir /var/spool/slurmstate \
    && chown slurm:slurm /var/spool/slurmstate/ \
    && /usr/sbin/mungekey \
    && ln -s /var/lib/slurm-llnl /var/lib/slurm \
    && mkdir -p /var/log/slurm

apt-get install r-base r-base-dev -y --allow-unauthenticated

# required for R-package spdep, and other dependencies of agricolae
#
apt-get install libudunits2-dev libproj-dev libgdal-dev -y

# XML::Simple dependency
#
apt-get install libexpat1-dev -y

# HTML::FormFu
#
apt-get install libcatalyst-controller-html-formfu-perl -y

# Cairo Perl module needs this:
#
apt-get install libcairo2-dev -y

# GD Perl module needs this:
#
apt-get install libgd-dev -y

# postgres driver DBD::Pg needs this:
#
apt-get install libpq-dev -y

# MooseX::Runnable Perl module needs this:
#
apt-get install libmoosex-runnable-perl -y

apt-get install libgdbm6 libgdm-dev -y
apt-get install nodejs -y

# Manually install nodejs to get a more recent version
apt remove -y nodejs \
  && wget https://nodejs.org/dist/v25.6.0/node-v25.6.0-linux-x64.tar.xz \
  && tar -xvf node-v25.6.0-linux-x64.tar.xz \
  && rm -f node-v25.6.0-linux-x64.tar.xz \
  && mkdir -p /opt/node \
  && mv node-v25.6.0-linux-x64 /opt/node/25.6.0 \
  && ln -f -s /opt/node/25.6.0/bin/node /usr/bin/node \
  && ln -f -s /opt/node/25.6.0/bin/npm /usr/bin/npm \
  && ln -f -s /opt/node/25.6.0/bin/npx /usr/bin/npx \
  && ln -f -s /opt/node/25.6.0/bin/corepack /usr/bin/corepack \
  && mkdir -p /home/production/.npm /home/production/.config \
  && touch /home/production/.npmrc

# Install gosu to help with custom users in the entrypoint
wget https://github.com/tianon/gosu/releases/download/1.19/gosu-amd64 \
  && chmod +x gosu-amd64 \
  && mv gosu-amd64 /usr/local/bin/gosu

cpanm Selenium::Remote::Driver@1.49

#INSTALL OPENCV IMAGING LIBRARY

apt-get install -y python3-dev  python3-pip python3-numpy libgtk2.0-dev libgtk-3-0 libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libhdf5-serial-dev libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libxvidcore-dev libatlas-base-dev gfortran libgdal-dev exiftool libzbar-dev zbar-tools cmake

pip3 install --upgrade pip
pip3 install grpcio==1.40.0 imutils numpy matplotlib pillow statistics PyExifTool pytz pysolar scikit-image packaging pyzbar pandas opencv-python \
    && pip3 install -U keras-tuner
