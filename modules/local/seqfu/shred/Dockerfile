# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Build stage: compile SeqFu from the local repository checkout.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
ENV CHOOSENIM_NO_ANALYTICS=1
ENV PATH="/root/.nimble/bin:${PATH}"

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        build-essential \
        xz-utils \
        zlib1g-dev \
        libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Nim 2.2.0
RUN curl -fsSL https://nim-lang.org/choosenim/init.sh | sh -s -- -y && \
    choosenim 2.2.0

# Set working directory
WORKDIR /opt/seqfu2

# Copy only required source files
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY seqfu.nimble ./seqfu.nimble

# Compile SeqFu
RUN nimble build -y --warning[Effect]:off

# Install compiled binaries and Python helper scripts
RUN find bin -maxdepth 1 -type f -perm -111 \
        -exec install -m 0755 {} /usr/local/bin/ \; && \
    install -m 0755 scripts/fu-split scripts/fu-pecheck /usr/local/bin/

# Verify expected executables
RUN set -eux; \
    for tool in \
        seqfu dadaist2-mergeseqs fu-16Sregion fu-cov fu-index fu-msa \
        fu-multirelabel fu-nanotags fu-orf fu-primers fu-shred fu-sw \
        fu-tabcheck fu-virfilter fu-split fu-pecheck; do \
        test -x "/usr/local/bin/$tool"; \
    done


# ---------------------------------------------------------------------------
# Runtime stage: minimal image containing compiled tools and dependencies.
# ---------------------------------------------------------------------------
FROM debian:bookworm-slim AS final

LABEL org.opencontainers.image.authors="Andrea Telatin" \
      org.opencontainers.image.description="SeqFu latest build from local repository sources" \
      org.opencontainers.image.title="seqfu" \
      org.opencontainers.image.version="1.30.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/bin:${PATH}"
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        zlib1g \
        python3-minimal \
        python-is-python3 \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy compiled binaries and helper scripts from build stage
COPY --from=build /usr/local/bin/ /usr/local/bin/

# ---------------------------------------------------------------------------
# Smoke tests
# Run during image build to verify the compiled tools.
# ---------------------------------------------------------------------------

# Verify SeqFu version
RUN seqfu version

# Test FASTQ and FASTA parsing
RUN set -eu; \
    printf '@r1\nACGTACGT\n+\nIIIIIIII\n' > /tmp/seqfu-test.fq; \
    printf '>s1\nACGTACGT\n' > /tmp/seqfu-test.fa; \
    seqfu count /tmp/seqfu-test.fq | grep -qw 1; \
    seqfu count /tmp/seqfu-test.fa | grep -qw 1; \
    seqfu stats /tmp/seqfu-test.fq > /dev/null

# Test gzipped FASTQ input
RUN set -eu; \
    echo 'H4sIAAAAAAACA3MoMuRydHYPAWEubS5PKOACAMYTXxsYAAAA' \
        | base64 -d > /tmp/seqfu-test.fq.gz; \
    seqfu count /tmp/seqfu-test.fq.gz | grep -qw 1

# Verify Python helper scripts
RUN test -x /usr/local/bin/fu-split && \
    test -x /usr/local/bin/fu-pecheck

# Remove test fixtures
RUN rm -f /tmp/seqfu-test.fq \
          /tmp/seqfu-test.fa \
          /tmp/seqfu-test.fq.gz