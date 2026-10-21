# Inert recipe, NOT an acquired/accepted BYOND image. No network or package RUN.
# toolchain-rootfs must be separately acquired, bounded, reviewed and hash-bound.
# It contains /opt/byond plus explicitly inventoried Linux loader/shared objects.
FROM docker.io/library/python@sha256:57d96f71de145a98e7ceca18ee4ade77bba4103a33a72dfaea026b23625c6bf0
COPY toolchain-rootfs/ /
ENV PATH="/opt/byond/bin:${PATH}" LD_LIBRARY_PATH="/opt/byond/bin:/usr/lib/i386-linux-gnu:/lib/i386-linux-gnu" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER 65534:65534
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/python3.12", "-B"]
