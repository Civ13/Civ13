# Review-only proposed container. System packages follow current Civ13 CI;
# the base tag and apt packages are not an immutable system-toolchain pin.
FROM ubuntu:22.04
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       git python3 libc6:i386 libstdc++6:i386 libgcc-s1:i386 lib32z1 \
       libncurses6:i386 libcurl4:i386 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /output
