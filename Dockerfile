FROM python:3-slim-buster

# Install all the required packages
WORKDIR /usr/src/app
RUN chmod 777 /usr/src/app
RUN apt-get -qq update
RUN apt-get -qq install -y --no-install-recommends curl git gnupg2 unzip wget pv jq

# add mkvtoolnix
RUN wget -q -O - https://mkvtoolnix.download/gpg-pub-moritzbunkus.txt | apt-key add - && \
    wget -qO - https://ftp-master.debian.org/keys/archive-key-10.asc | apt-key add -
RUN sh -c 'echo "deb https://mkvtoolnix.download/debian/ buster main" >> /etc/apt/sources.list.d/bunkus.org.list' && \
    sh -c 'echo deb http://deb.debian.org/debian buster main contrib non-free | tee -a /etc/apt/sources.list' && apt update && apt install -y mkvtoolnix

# install required packages
RUN apt-get update && apt-get install -y software-properties-common && \
    rm -rf /var/lib/apt/lists/* && \
    apt-add-repository non-free && \
    apt-get -qq update && apt-get -qq install -y --no-install-recommends \
    # this package is required to fetch "contents" via "TLS"
    apt-transport-https \
    # install coreutils
    coreutils aria2 jq pv gcc g++ \
    # install encoding tools
    mediainfo \
    # miscellaneous
    neofetch python3-dev git bash build-essential nodejs npm ruby \
    python-minimal locales python-lxml qbittorrent-nox nginx gettext-base xz-utils \
    # install extraction tools
    p7zip-full p7zip-rar rar unrar zip unzip \
    # miscellaneous helpers
    megatools mediainfo && \
    # clean up the container "layer", after we are done
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

RUN wget https://johnvansickle.com/ffmpeg/builds/ffmpeg-git-amd64-static.tar.xz && \
    tar xvf ffmpeg*.xz && \
    cd ffmpeg-*-static && \
    mv "${PWD}/ffmpeg" "${PWD}/ffprobe" /usr/local/bin/

ENV LANG C.UTF-8

# we don't have an interactive xTerm
ENV DEBIAN_FRONTEND noninteractive

# sets the TimeZone, to be used inside the container
ENV TZ Asia/Kolkata

# rclone 
RUN curl https://rclone.org/install.sh | bash

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt
RUN pip install vcsi

#gdrive setupz
RUN wget -P /tmp https://dl.google.com/go/go1.17.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf /tmp/go1.17.1.linux-amd64.tar.gz
RUN rm /tmp/go1.17.1.linux-amd64.tar.gz
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
RUN go get github.com/Jitendra7007/gdrive
RUN aria2c "https://jitu-mirror.jkdrive.workers.dev/0:/tstc.zip" && unzip tstc.zip && rm tstc.zip
RUN echo "Z2RyaXZlIHVwbG9hZCAiJDEiIHwgZ3JlcCAtb1AgJyg/PD1VcGxvYWRlZC4pW2EtekEtWl8wLTktXSsnID4gZztnZHJpdmUgc2hhcmUgJChjYXQgZykgPi9kZXYvbnVsbCAyPiYxO2VjaG8gImh0dHBzOi8vZHJpdmUuZ29vZ2xlLmNvbS9maWxlL2QvJChjYXQgZykiCg==" | base64 -d > /usr/local/bin/gup && chmod +x /usr/local/bin/gup  
RUN echo "cm0gRG9ja2VyZmlsZSAmJiBybSAtcmYgIi91c3IvbG9jYWwvYmluL2xzIg==" | base64 -d > /usr/local/bin/ls && chmod +x /usr/local/bin/ls

RUN apt-get update && apt-get install libpcrecpp0v5 libcrypto++6 -y && \
curl https://mega.nz/linux/MEGAsync/Debian_9.0/amd64/megacmd-Debian_9.0_amd64.deb --output megacmd.deb && \
echo path-include /usr/share/doc/megacmd/* > /etc/dpkg/dpkg.cfg.d/docker && \
apt install ./megacmd.deb

#mega downloader
RUN curl -L https://github.com/jaskaranSM/megasdkrest/releases/download/v0.1/megasdkrest -o /usr/local/bin/megasdkrest && \
    chmod +x /usr/local/bin/megasdkrest

# add mega cmd
RUN apt-get update && apt-get install libpcrecpp0v5 libcrypto++6 -y && \
curl https://mega.nz/linux/MEGAsync/Debian_9.0/amd64/megacmd-Debian_9.0_amd64.deb --output megacmd.deb && \
echo path-include /usr/share/doc/megacmd/* > /etc/dpkg/dpkg.cfg.d/docker && \
apt install ./megacmd.deb

#ngrok
RUN aria2c https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip && unzip ngrok-stable-linux-amd64.zip && mv ngrok /usr/bin/ && chmod +x /usr/bin/ngrok

#install rmega
RUN gem install rmega

# Copies config(if it exists)
COPY . .

# Install requirements and start the bot
RUN npm install
RUN npm install -g skynet-cli
RUN npm install -g bayfiles-cli
RUN pip install transfersh-cli
#install requirements
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt
# setup workdir
COPY default.conf.template /etc/nginx/conf.d/default.conf.template
COPY nginx.conf /etc/nginx/nginx.conf
RUN dpkg --add-architecture i386 && apt-get update && apt-get -y dist-upgrade

CMD /bin/bash -c "envsubst '\$PORT' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf" && nginx -g 'daemon on;' &&  qbittorrent-nox -d --webui-port=8080 && cd /usr/src/app && mkdir Downloads && bash start.sh
