FROM ocaml/opam2:4.11

ENV DEBIAN_FRONTEND=noninteractive
ENV SIHL_ENV development

RUN sudo apt-get update -q && sudo apt-get install -yqq \
  default-jre \
    # emacs-nox for emacs, but sihl cannot be installed without
  emacs-nox \
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
  wget \
  wkhtmltopdf \
  xvfb \
  zip \
  zlib1g-dev \
  zsh \
  # cleanup installations
  && sudo apt-get clean all \
  # install oh-my-zsh
  && wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh \
  && cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc \
  # add timezone
  && sudo ln -fs /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# WTF: https://github.com/mirage/ocaml-cohttp/issues/675
RUN sudo bash -c 'echo "http		80/tcp	www		# WorldWideWeb HTTP" >> /etc/services' \
  sudo bash -c 'echo "https		443/tcp	www		# WorldWideWeb HTTPS" >> /etc/services'
