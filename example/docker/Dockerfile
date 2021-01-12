FROM ocaml/opam2:4.11 as builder
WORKDIR app
COPY demo.opam .
COPY dune-project .
COPY .env .
COPY app app
COPY web web
COPY run run
COPY database database
COPY public public
COPY resources resources

RUN sudo apt-get update -y && \
  opam remote remove --all default && \
  opam remote add default https://opam.ocaml.org && \
  opam pin add -yn demo . && \
  OPAMSOLVERTIMEOUT=180 opam depext -y demo && \
  opam install --deps-only -y demo && \
  sudo chown -R opam:nogroup .

RUN opam config exec -- dune build

FROM debian:10
WORKDIR /app

COPY --from=builder /home/opam/opam-repository/app/_build/default/run/run.exe run.exe
COPY --from=builder /home/opam/opam-repository/app/public public/
COPY --from=builder /home/opam/opam-repository/app/.env .env
RUN mkdir logs

RUN apt-get update -y && apt-get install -qq -yy sudo && \
    sudo apt-get update -y && \
    sudo apt-get install -qq -yy \
    # Add the run-time dependencies here, as defined by "opam depext -ln"
    libev-dev \
    libgmp-dev \
    libpq-dev \
    libssl-dev \
    m4 \
    perl \
    pkg-config \
    zlib1g-dev \
    libpq-dev

# WTF: https://github.com/mirage/ocaml-cohttp/issues/675
RUN sudo bash -c 'echo "http		80/tcp	www		# WorldWideWeb HTTP" >> /etc/services'
RUN sudo bash -c 'echo "https		443/tcp	www		# WorldWideWeb HTTPS" >> /etc/services'

ENV SIHL_ENV production
ENV ROOT_PATH /app
CMD /app/run.exe start
