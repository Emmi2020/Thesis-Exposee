FROM debian:13-slim

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        biber \
        latexmk \
        texlive-full \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work