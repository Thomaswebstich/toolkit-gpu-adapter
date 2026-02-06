# ========== STAGE 1: Builder ==========
FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common wget curl git nasm ninja-build build-essential yasm cmake meson \
    libssl-dev libvpx-dev libx264-dev libx265-dev libnuma-dev libmp3lame-dev libopus-dev \
    libvorbis-dev libtheora-dev libspeex-dev libfreetype6-dev libfontconfig1-dev libgnutls28-dev \
    libaom-dev libdav1d-dev libzimg-dev libwebp-dev pkg-config autoconf automake libtool \
    libfribidi-dev libharfbuzz-dev libunibreak-dev libfluidsynth-dev \
    && rm -rf /var/lib/apt/lists/*

# Install SRT from source
RUN git clone https://github.com/Haivision/srt.git && \
    cd srt && mkdir build && cd build && cmake .. && make -j$(nproc) && make install && \
    cd ../.. && rm -rf srt

# Install SVT-AV1 from source
RUN git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    cd SVT-AV1 && git checkout v0.9.0 && cd Build && cmake .. && make -j$(nproc) && make install && \
    cd ../.. && rm -rf SVT-AV1

# Install libvmaf from source 
RUN git clone https://github.com/Netflix/vmaf.git && \
    cd vmaf && git checkout v3.0.0 && cd libvmaf && meson setup build --buildtype release && \
    ninja -C build && ninja -C build install && \
    cd ../.. && rm -rf vmaf

# Install fdk-aac
RUN git clone https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && autoreconf -fiv && ./configure && make -j$(nproc) && make install && \
    cd .. && rm -rf fdk-aac

# Install libunibreak
RUN git clone https://github.com/adah1972/libunibreak.git && \
    cd libunibreak && ./autogen.sh && ./configure && make -j$(nproc) && make install && \
    cd .. && rm -rf libunibreak

# Build libass
RUN git clone https://github.com/libass/libass.git && \
    cd libass && autoreconf -i && ./configure --enable-libunibreak && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf libass

# Build FFmpeg
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && \
    cd ffmpeg && git checkout n7.0.2 && \
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" \
    ./configure --prefix=/usr/local --enable-gpl --enable-nonfree --enable-pthreads --enable-libaom \
    --enable-libdav1d --enable-libsvtav1 --enable-libvmaf --enable-libzimg --enable-libx264 \
    --enable-libx265 --enable-libvpx --enable-libwebp --enable-libmp3lame --enable-libopus \
    --enable-libvorbis --enable-libtheora --enable-libspeex --enable-libass --enable-libfreetype \
    --enable-libharfbuzz --enable-fontconfig --enable-libsrt --enable-gnutls \
    && make -j$(nproc) && make install && \
    cd .. && rm -rf ffmpeg

# ========== STAGE 2: Final ==========
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV WHISPER_CACHE_DIR="/app/whisper_cache"
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /app

# Copy compiled binaries and libraries from builder
COPY --from=builder /usr/local /usr/local
RUN ldconfig

# Install runtime dependencies and Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev libssl3 wget curl git fonts-liberation fontconfig \
    libvpx7 libx264-163 libx265-199 libnuma1 libmp3lame0 libopus0 libvorbis0a libvorbisenc2 \
    libtheora0 libspeex1 libfreetype6 libfontconfig1 libgnutls30 libaom3 libdav1d5 \
    libwebpmux3 libwebp7 libfribidi0 libharfbuzz0b fluidsynth fluid-soundfont-gm \
    libgdal-dev libsndfile1 libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libxcomposite1 libxrandr2 libxdamage1 libgbm1 libasound2 libpangocairo-1.0-0 \
    libpangoft2-1.0-0 libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Symlink python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Rebuild font cache
COPY ./fonts /usr/share/fonts/custom
RUN fc-cache -f -v && ln -sf /usr/share/sounds/sf2/FluidR3_GM.sf2 /usr/share/sounds/sf2/default.sf2

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip3 install --no-cache-dir -r requirements.txt && \
    rm -rf /root/.cache/pip

# Set up user
RUN useradd -m appuser && mkdir -p ${WHISPER_CACHE_DIR} && chown -R appuser:appuser /app
USER appuser

# Pre-load model and install playwright
RUN python3 -c "import whisper; whisper.load_model('base')" && \
    playwright install chromium

# Copy application
COPY . .

EXPOSE 8080

RUN echo '#!/bin/bash\n\
    gunicorn --bind 0.0.0.0:8080 \
    --workers ${GUNICORN_WORKERS:-2} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --worker-class sync \
    --keep-alive 80 \
    --config gunicorn.conf.py \
    app:app' > /app/run_gunicorn.sh && \
    chmod +x /app/run_gunicorn.sh

CMD ["/app/run_gunicorn.sh"]
