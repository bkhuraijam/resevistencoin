# ---- Stage 1: Build ----
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update -y && \
    apt-get install -y \
      build-essential \
      autoconf \
      automake \
      libtool \
      pkg-config \
      git \
      curl \
      python3 \
      libevent-dev \
      libboost-system-dev \
      libboost-filesystem-dev \
      libboost-chrono-dev \
      libboost-test-dev \
      libboost-thread-dev \
      libssl-dev \
      libminiupnpc-dev \
      qtbase5-dev \
      qttools5-dev-tools \
      ca-certificates \
      bison \
      flex && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone https://github.com/reservistencoin/reservistencoin.git .
WORKDIR /app

# Step 1: Build depends system
WORKDIR /app/depends
RUN chmod +x config.guess config.sub gen_id && make -j$(nproc)

# Step 2: Create stub Makefiles to satisfy autotools
WORKDIR /app/src
RUN mkdir -p qt/test test && \
    touch qt/Makefile qt/test/Makefile test/Makefile

# Step 3: Build only daemon + CLI
WORKDIR /app
RUN chmod +x autogen.sh share/genbuild.sh && ./autogen.sh && \
    ./configure --prefix=/app/depends/x86_64-pc-linux-gnu --without-gui --disable-tests && \
    make -j$(nproc) -C src reservistencoind reservistencoin-cli

# ---- Stage 2: Runtime ----
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime libraries (no dev toolchain)
RUN apt-get update -y && \
    apt-get install -y \
      libboost-system-dev \
      libboost-filesystem-dev \
      libboost-chrono-dev \
      libboost-thread-dev \
      libevent-dev \
      libssl-dev \
      libminiupnpc-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/reservistencoin

# Copy built binaries from builder
COPY --from=builder /app/src/reservistencoind ./reservistencoind
COPY --from=builder /app/src/reservistencoin-cli ./reservistencoin-cli

# Create mount point for blockchain data/config
RUN mkdir -p /data/.rvc

# Expose RPC and P2P ports
EXPOSE 24877 24878

# Run node in foreground with console logging
ENTRYPOINT ["./reservistencoind", "-datadir=/data/.rvc", "-conf=/data/.rvc/reservistencoin.conf", "-printtoconsole"]
