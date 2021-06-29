FROM node:14 AS node_base
FROM hadolint/hadolint:latest-alpine AS hadolint
FROM ocaml/opam:debian-ocaml-4.12

# copy node from node_base container and link commands
USER root
COPY --from=node_base /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node_base /usr/local/bin/node /usr/local/bin/node
COPY --from=node_base /opt /opt
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  && ln -s /opt/yarn-v*/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v*/bin/yarnpkg /usr/local/bin/yarnpkg
# copy hadolint
COPY --from=hadolint /bin/hadolint /bin/hadolint

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND noninteractive
ENV SIHL_ENV development

RUN apt-get update -q && apt-get install -yqq \
  default-jre \
  # emacs-nox for emacs, but sihl cannot be installed without
  emacs-nox \
  git \
  inotify-tools \
  libev-dev \
  libffi-dev \
  libfontconfig \
  libgmp-dev \
  libmariadb-dev \
  libpq-dev \
  libqt5gui5 \
  libssl-dev \
  lsof \
  m4 \
  pdftk-java \
  perl \
  pkg-config \
  utop \
  wget \
  wkhtmltopdf \
  xvfb \
  zip \
  zlib1g-dev \
  zsh \
  #
  # cleanup installations
  && apt-get autoremove -y \
  && apt-get clean all \
  #
  # add timezone
  && ln -fs /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# WTF: https://github.com/mirage/ocaml-cohttp/issues/675
RUN bash -c 'echo "http		80/tcp	www		# WorldWideWeb HTTP" >> /etc/services' \
  bash -c 'echo "https		443/tcp	www		# WorldWideWeb HTTPS" >> /etc/services'

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
USER opam

# install oh-my-zsh
RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -q -O - | zsh \
  && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
