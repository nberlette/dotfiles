ARG VARIANT=ubuntu-21.04
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

ARG CURRENT_USER="$USER"
USER codespace

# update apt cache, upgrade existing packages, install some essentials
RUN sudo apt-get update && sudo apt-get upgrade && \
    sudo apt-get install -y --no-install-recommends \
      curl \
      gcc \
      gnupg2 \
      build-essential \
      ca-certificates \
      software-properties-common ;

# clean up after ourselves
RUN sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo rm -rf /tmp/* && \
    sudo rm -rf /var/tmp/* && \
    sudo rm -rf /usr/share/doc/* && \
    sudo rm -rf /usr/share/ ;

USER $CURRENT_USER
