# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
FROM jupyterhub/jupyterhub:5.5.1

# System packages
RUN apt update -y \
  && apt install -y build-essential libpq-dev python3-dev postgresql-client

# Install dockerspawner, nativeauthenticator
# hadolint ignore=DL3013
RUN python3 -m pip install --no-cache-dir \
    dockerspawner==14.0.0 \
    jupyterhub-nativeauthenticator==1.3.0 \
    jupyterhub-idle-culler==1.4.0 \
    oauthenticator==17.3.0 \
    psycopg2==2.9.10

RUN \
  --mount=type=secret,id=docker_id,env=DOCKER_ID \
  groupadd -g $DOCKER_ID docker \
  && useradd jupyterhub -g $DOCKER_ID -m -s /bin/bash

COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py
COPY condarc /tmp/condarc
COPY conda_envs.json /tmp/conda_envs.json

USER jupyterhub

CMD ["jupyterhub", "-f", "/srv/jupyterhub/jupyterhub_config.py"]
