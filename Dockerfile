FROM ubuntu:22.04

ARG DXC_VERSION=1.8.2502

RUN apt-get update && apt-get install -y \
    bash \
    curl \
    tar \
    ca-certificates \
    libstdc++6 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/dxc/bin /opt/dxc/lib /opt/dxc/include /opt/dxc/cache

COPY src/entrypoint.sh /opt/dxc/entrypoint.sh
RUN chmod +x /opt/dxc/entrypoint.sh

ENV PATH="/opt/dxc/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/dxc/lib"
ENV DXC_VERSION=${DXC_VERSION}

RUN /opt/dxc/entrypoint.sh --v=${DXC_VERSION}

ENTRYPOINT ["/opt/dxc/entrypoint.sh"]

CMD ["--help"]
