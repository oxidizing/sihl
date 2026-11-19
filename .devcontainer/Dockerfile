# Same base image as the pool tool's devcontainer (RHEL 9 UBI, OCaml 5.5.2, opam 2.6),
# see https://github.com/uzh/z-pool-tool/blob/main/docker/Dockerfile.build
FROM ghcr.io/uzh/z-pool-tool/ocaml:9-5.5-2.6
COPY --from=hadolint/hadolint:latest-alpine /bin/hadolint /bin/hadolint

# hadolint ignore=DL3066
USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV SIHL_ENV=development

# The base image only ships the MariaDB client library; caqti-driver-postgresql needs libpq.
# hadolint ignore=DL3041
RUN dnf install -y libpq-devel && dnf clean all

# NOTE: Pre-create volume folders for the correct ownership.
RUN mkdir -p /workspace/_build /home/opam/.cache \
  && chown -R opam:opam /workspace/_build /home/opam/.cache

# add timezone
RUN ln -fs /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# WTF: https://github.com/mirage/ocaml-cohttp/issues/675
# (only needed if the image's /etc/services lacks the http entries)
RUN grep -qw http /etc/services \
  || printf 'http\t\t80/tcp\twww\t\t# WorldWideWeb HTTP\nhttps\t\t443/tcp\t\t\t# http protocol over TLS/SSL\n' >> /etc/services

# hadolint ignore=DL3066
USER opam

# GitButler CLI (`but`), installed to ~/.local/bin (the installer verifies the binary's signature)
RUN curl -fsSL https://gitbutler.com/install.sh | sh > /dev/null
