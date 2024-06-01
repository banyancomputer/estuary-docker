# syntax=docker/dockerfile:1

# ## Build
FROM golang:1.18-bullseye

# Create build directory
WORKDIR /app

# Install and Configure External Dependencies
RUN apt-get update && \
    apt-get install -y wget jq hwloc ocl-icd-opencl-dev git libhwloc-dev pkg-config make  && \
    apt-get install -y cargo
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo --help

# Copy our Source Code from the Git Repository, Download Dependencies, and Compile
RUN git clone https://github.com/banyancomputer/estuary . && \
    RUSTFLAGS="-C target-cpu=native -g" FFI_BUILD_FROM_SOURCE=1 make all

# Initialize our Statup Script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Expose the Container on port 3004
EXPOSE 3004