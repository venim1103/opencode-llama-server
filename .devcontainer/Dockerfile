FROM docker.io/nvidia/cuda:12.8.1-devel-ubuntu24.04

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash-completion \
    binutils \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    libgomp1 \
    libssl-dev \
    libxml2 \
    libxml2-dev \
    ninja-build \
    pkg-config \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-venv \
    ripgrep \
    libsdl2-dev \
    sudo \
    vim \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
        USER_GROUP="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
        USER_GROUP="${USERNAME}"; \
    fi; \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
        usermod --uid "${USER_UID}" --gid "${USER_GROUP}" "${USERNAME}"; \
    elif getent passwd "${USER_UID}" >/dev/null; then \
        EXISTING_USER="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home "${EXISTING_USER}"; \
        usermod --gid "${USER_GROUP}" "${USERNAME}"; \
    else \
        useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}"; \
    fi; \
    mkdir -p "/home/${USERNAME}"; \
    chown -R "${USER_UID}:${USER_GID}" "/home/${USERNAME}"; \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

ENV PATH=/home/${USERNAME}/.local/bin:${PATH}

USER ${USERNAME}
WORKDIR /workspaces/llm-server
