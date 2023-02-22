FROM          alpine:3.14
MAINTAINER    Laur Aliste

ENV LANG=C.UTF-8

ADD scripts/* /usr/local/sbin/
ADD files/*   /

RUN apk update && \
    apk add --no-cache \
        rclone \
        unrar \
        unzip \
        grep \
        file \
        coreutils \
        findutils \
        iputils \
        curl \
        bash \
        ca-certificates \
        shadow \
        tzdata \
        msmtp \
        logrotate && \
    useradd -u 1000 -U -G users -d /config -s /bin/false abc && \
    mkdir /config/ && \
    chmod -R 777 /config/ && \
    chown -R root:root /usr/local/sbin/ && \
    chmod -R 755 /usr/local/sbin/ && \
    ln -s /usr/local/sbin/setup.sh /setup.sh && \
    ln -s /usr/local/sbin/sync.sh /sync.sh && \
    ln -s /usr/local/sbin/common.sh /common.sh && \
    rm -rf /var/cache/apk/* /tmp/* /root/.cache

#USER abc  # continue as root, as we need to set UID & GID in entrypoint!
ENTRYPOINT ["/usr/local/sbin/entry.sh"]

