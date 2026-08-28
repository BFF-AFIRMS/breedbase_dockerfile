FROM mathesar/mathesar:0.12.0

RUN apt update \
  && apt install -y vim \
  && pip install passlib==1.7.4

COPY local.py /code/config/settings/local.py
COPY mathesar.sh /code/bin/mathesar

RUN useradd -ms /bin/bash mathesar
USER mathesar

CMD ["bash", "./bin/mathesar", "run", "-fnsec"]
