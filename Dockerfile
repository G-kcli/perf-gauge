FROM docker:20.10.12 AS static-docker-source

FROM debian:buster AS base
ARG CLOUD_SDK_VERSION=403.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ENV PATH "$PATH:/opt/google-cloud-sdk/bin/"
COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
RUN groupadd -r -g 1000 cloudsdk && \
    useradd -r -u 1000 -m -s /bin/bash -g cloudsdk cloudsdk
RUN apt-get -qqy update && apt-get install -qqy \
        curl \
        python3-dev \
        python3-crcmod \
        apt-transport-https \
        lsb-release \
        openssh-client \
        git \
        make \
        gnupg && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-app-engine-python=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-app-engine-python-extras=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-app-engine-java=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-app-engine-go=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-datalab=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-datastore-emulator=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-pubsub-emulator=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-bigtable-emulator=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-firestore-emulator=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-spanner-emulator=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-cbt=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-kpt=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-local-extract=${CLOUD_SDK_VERSION}-0 \
        google-cloud-sdk-gke-gcloud-auth-plugin=${CLOUD_SDK_VERSION}-0 \
        kubectl && \
    gcloud --version && \
    docker --version && kubectl version --client
RUN apt-get install -qqy \
        gcc \
        python3-pip
RUN pip3 install --upgrade pip
RUN pip3 install pyopenssl
RUN git config --system credential.'https://source.developers.google.com'.helper gcloud.sh
VOLUME ["/root/.config", "/root/.kube"]

FROM base

WORKDIR /perf-gauge
ENV PATH="/root/.cargo/bin:${PATH}"
COPY . .

RUN rm /bin/sh && ln -s /bin/bash /bin/sh
RUN apt-get update && apt-get install -y \
curl
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable
RUN apt-get install build-essential -y
RUN apt-get install pkg-config libssl-dev -y
RUN cargo install perf-gauge --features full
RUN chmod +x ./us-east1-read-100k.sh

ENTRYPOINT ["./us-east1-read-100k.sh"]