FROM ubuntu:22.04

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
  && mkdir -p /etc/sudoers.d \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  software-properties-common \
  apt-transport-https \
  ca-certificates \
  gnupg2 \
  build-essential \
  curl \
  wget \
  lsb-release \
  sudo \
  && rm -rf /var/lib/apt/lists/*

RUN apt-add-repository -y ppa:git-core/ppa \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  python3 \
  git \
  bash \
  jq \
  openvpn \
  unzip \
  vim \
  dnsutils \
  bind9-dnsutils \
  && rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Trivy
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.65.0

# Install terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt-get update && apt-get install -y --no-install-recommends terraform

# Install tflint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Verify tools work as non-root user
RUN az --version && az extension list && trivy --version && terraform -version && tflint --version