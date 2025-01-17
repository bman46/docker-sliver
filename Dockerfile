FROM golang:1.19.1

ARG BUILD_RFC3339="1970-01-01T00:00:00Z"
ARG COMMIT="local"
ARG VERSION="v1.5.29"

ENV PROTOC_VER 3.19.4
ENV PROTOC_GEN_GO_VER v1.27.1
ENV GRPC_GO v1.2.0

# Base packages
RUN apt-get update --fix-missing && apt-get -y install \
    git build-essential zlib1g zlib1g-dev \
    libxml2 libxml2-dev libxslt-dev locate curl \
    libreadline6-dev libcurl4-openssl-dev git-core \
    libssl-dev libyaml-dev openssl autoconf libtool \
    ncurses-dev bison curl wget xsel postgresql \
    postgresql-contrib postgresql-client libpq-dev \
    libapr1 libaprutil1 libsvn1 \
    libpcap-dev libsqlite3-dev libgmp3-dev \
    zip unzip mingw-w64 binutils-mingw-w64 g++-mingw-w64 \
    nasm gcc-multilib

#
# > User
#
RUN groupadd -g 999 sliver && useradd -r -u 999 -g sliver sliver
RUN mkdir -p /home/sliver/ && chown -R sliver:sliver /home/sliver

#
# > Metasploit
#
RUN curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall \
    && chmod 755 msfinstall \
    && ./msfinstall
RUN mkdir -p ~/.msf4/ && touch ~/.msf4/initial_setup_complete \
    &&  su -l sliver -c 'mkdir -p ~/.msf4/ && touch ~/.msf4/initial_setup_complete'

#
# > Sliver
#

# Protoc
WORKDIR /tmp
RUN wget -O protoc-${PROTOC_VER}-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VER}/protoc-${PROTOC_VER}-linux-x86_64.zip \
    && unzip protoc-${PROTOC_VER}-linux-x86_64.zip \
    && cp -vv ./bin/protoc /usr/local/bin
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@${PROTOC_GEN_GO_VER} \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@${GRPC_GO}

# assets
RUN git clone https://github.com/bishopfox/sliver /go/src/github.com/bishopfox/sliver
WORKDIR /go/src/github.com/bishopfox/sliver
RUN ./go-assets.sh
# Hack for error:
RUN go get github.com/yiya1989/sshkrb5/krb5forssh 
# Compile sliver:
RUN go mod vendor && make linux && cp -vv sliver-server /opt/sliver-server

RUN ls -lah \
    && /opt/sliver-server unpack --force 
#    && /go/src/github.com/bishopfox/sliver/go-tests.sh
RUN make clean 
    # && rm -rf /go/src/* \
    # && rm -rf /home/sliver/.sliver

COPY ./docker-entrypoint.sh /opt/docker-entrypoint.sh
RUN chmod +x /opt/docker-entrypoint.sh
RUN chown sliver. /opt/docker-entrypoint.sh

USER sliver
WORKDIR /home/sliver/
ENTRYPOINT [ "/opt/docker-entrypoint.sh" ]
EXPOSE 80 443 31337

STOPSIGNAL SIGKILL

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
