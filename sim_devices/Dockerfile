FROM python:3.12-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk add --no-cache openssh bash tzdata && \
    pip install --no-cache-dir pyyaml && \
    mkdir -p /var/run/sshd /data

COPY cli_server.py /usr/local/bin/cli-server
COPY commands /opt/cisco-sim/commands
COPY entrypoint.sh /entrypoint.sh

# SECURITY NOTE: PasswordAuthentication stays enabled here so the simulator is easy to
# exercise in dev/test. Do not reuse this container configuration in production.
RUN chmod +x /usr/local/bin/cli-server /entrypoint.sh && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo 'ClientAliveInterval 60' >> /etc/ssh/sshd_config && \
    echo 'ClientAliveCountMax 5' >> /etc/ssh/sshd_config

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
