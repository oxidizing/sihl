FROM node:lts AS node
FROM ocaml/opam:debian-10-ocaml-4.14

USER root

# copy node from node container and link commands
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /opt /opt
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && ln -s /opt/yarn-v*/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v*/bin/yarnpkg /usr/local/bin/yarnpkg

# copy hadolint
COPY --from=hadolint/hadolint:latest-alpine /bin/hadolint /bin/hadolint

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND noninteractive
ENV SIHL_ENV development

# install packages
# hadolint ignore=DL3008
RUN apt-get update -q && apt-get install -yqq --no-install-recommends \
  # development dependencies
  inotify-tools \
  zsh \
  m4 \
  wget \
  #
  # build dependencies (would also be installed by opam depext)
  gcc \
  libev-dev \
  libgmp-dev \
  libmariadb-dev \
  libpq-dev \
  libssl-dev \
  pkg-config \
  #
  # cleanup installations
  && apt-get autoremove -y \
  && apt-get clean all \
  && rm -rf /var/lib/apt/lists/*

# add timezone
RUN ln -fs /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# WTF: https://github.com/mirage/ocaml-cohttp/issues/675
RUN bash -c 'echo "http		80/tcp	www		# WorldWideWeb HTTP" >> /etc/services' \
  && bash -c 'echo "https		443/tcp	www		# WorldWideWeb HTTPS" >> /etc/services'

# link opam version
RUN ln -fs /usr/bin/opam-2.2 /usr/bin/opam

USER opam

# install oh-my-zsh
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -q -O - | zsh \
  && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc \
  && sed -i "/^plugins=/c\plugins=(git dotenv)" ~/.zshrc \
  #
  # link make to devcontainer makefile
  && echo 'alias make="make -f /workspace/.devcontainer/Makefile"' >> ~/.zshrc

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
