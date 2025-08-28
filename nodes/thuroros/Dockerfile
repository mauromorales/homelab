FROM quay.io/mauromorales/ubuntu:24.04

RUN apt-get update && apt-get install -y \
    # doorbell dependencies
    gcc \
    python3-dev \
    python3-lgpio \
    python3-requests \
    python3-pytzdata \
    && rm -rf /var/lib/apt/lists/*