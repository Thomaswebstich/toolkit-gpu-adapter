# Base image with CUDA support (Trigger build: clean disk space)
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# Avoid interaction during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies, build tools, and libraries
# Python 3.10 is the default in Ubuntu 22.04
# Install basic build tools and software properties first
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    wget \
    curl \
    git \
    python3-pip \
    python3-dev \
    nasm \
    ninja-build \
    && add-apt-repository universe \
    && apt-get update && rm -rf /var/lib/apt/lists/*

# Install multimedia libraries and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tar \
    xz-utils \
    fonts-liberation \
    fontconfig \
    build-essential \
    yasm \
    cmake \
    meson \
    ninja-build \
    nasm \
    libssl-dev \
    libvpx-dev \
    libx264-dev \
    libx265-dev \
    libnuma-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    libtheora-dev \
    libspeex-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libgnutls28-dev \
    libaom-dev \
    libdav1d-dev \
    libzimg-dev \
    libwebp-dev \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libfribidi-dev \
    libharfbuzz-dev \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxcomposite1 \
    libxrandr2 \
    libxdamage1 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libpangoft2-1.0-0 \
    libgtk-3-0 \
    libgdal-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Install fluidsynth and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    fluidsynth \
    libfluidsynth-dev \
    && rm -rf /var/lib/apt/lists/*

# Install SoundFont via apt-get (more reliable than wget)
RUN apt-get update && apt-get install -y --no-install-recommends \
    fluid-soundfont-gm \
    && rm -rf /var/lib/apt/lists/*

# Symlink for standard location if needed, though fluid-soundfont-gm usually places it correctly
RUN ln -sf /usr/share/sounds/sf2/FluidR3_GM.sf2 /usr/share/sounds/sf2/default.sf2

# Create symlinks for python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Install SRT from source (latest version using cmake)
RUN git clone https://github.com/Haivision/srt.git && \
    cd srt && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && rm -rf srt

# Install SVT-AV1 from source
RUN git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
    cd SVT-AV1 && \
    git checkout v0.9.0 && \
    cd Build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    cd ../.. && rm -rf SVT-AV1

# Install libvmaf from source (reverting to manual build as apt package is missing)
RUN git clone https://github.com/Netflix/vmaf.git && \
    cd vmaf && \
    git checkout v3.0.0 && \
    cd libvmaf && \
    meson setup build --buildtype release && \
    ninja -C build && \
    ninja -C build install && \
    cd ../.. && rm -rf vmaf && \
    ldconfig

# Manually build and install fdk-aac (since it is not available via apt-get)
RUN git clone https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd .. && rm -rf fdk-aac

# Install libunibreak (required for ASS_FEATURE_WRAP_UNICODE)
RUN git clone https://github.com/adah1972/libunibreak.git && \
    cd libunibreak && \
    ./autogen.sh && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cd .. && rm -rf libunibreak

# Build and install libass with libunibreak support and ASS_FEATURE_WRAP_UNICODE enabled
RUN git clone https://github.com/libass/libass.git && \
    cd libass && \
    autoreconf -i && \
    ./configure --enable-libunibreak || { cat config.log; exit 1; } && \
    mkdir -p /app && echo "Config log located at: /app/config.log" && cp config.log /app/config.log && \
    make -j$(nproc) || { echo "Libass build failed"; exit 1; } && \
    make install && \
    ldconfig && \
    cd .. && rm -rf libass

# Build and install FFmpeg with all required features
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg && \
    cd ffmpeg && \
    git checkout n7.0.2 && \
    PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/local/lib/pkgconfig" \
    CFLAGS="-I/usr/include/freetype2" \
    LDFLAGS="-L/usr/lib/x86_64-linux-gnu" \
    ./configure --prefix=/usr/local \
    --enable-gpl \
    --enable-pthreads \
    --enable-neon \
    --enable-libaom \
    --enable-libdav1d \
    --enable-libsvtav1 \
    --enable-libvmaf \
    --enable-libzimg \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libtheora \
    --enable-libspeex \
    --enable-libass \
    --enable-libfreetype \
    --enable-libharfbuzz \
    --enable-fontconfig \
    --enable-libsrt \
    --enable-filter=drawtext \
    --extra-cflags="-I/usr/include/freetype2 -I/usr/include/libpng16 -I/usr/include" \
    --extra-ldflags="-L/usr/lib/x86_64-linux-gnu -lfreetype -lfontconfig" \
    --enable-gnutls \
    && make -j$(nproc) && \
    make install && \
    cd .. && rm -rf ffmpeg

# Add /usr/local/bin to PATH (if not already included)
ENV PATH="/usr/local/bin:${PATH}"

# Copy fonts into the custom fonts directory
COPY ./fonts /usr/share/fonts/custom

# Rebuild the font cache so that fontconfig can see the custom fonts
RUN fc-cache -f -v

# Set work directory
WORKDIR /app

# Set environment variable for Whisper cache
ENV WHISPER_CACHE_DIR="/app/whisper_cache"

# Create cache directory (no need for chown here yet)
RUN mkdir -p ${WHISPER_CACHE_DIR} 

# Copy the requirements file first to optimize caching
COPY requirements.txt .

# Install Python dependencies, upgrade pip 
# Explicitly install torch with CUDA support
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install Core Python Dependencies (Build tools)
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel

# Install Base Libraries (often dependencies for others)
RUN pip3 install --no-cache-dir numpy cryptography cffi certifi six

# Install Web Frameworks
RUN pip3 install --no-cache-dir Flask Werkzeug gunicorn requests

# Install Google Cloud SDKs
RUN pip3 install --no-cache-dir google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client google-api-core google-cloud-storage google-cloud-run

# Install Utilities
RUN pip3 install --no-cache-dir APScheduler srt psutil boto3 yt-dlp

# Install Image/Video Libraries
RUN pip3 install --no-cache-dir Pillow matplotlib ffmpeg-python

# Install audio/music libraries
RUN pip3 install --no-cache-dir pyFluidSynth mido pychord pydub

# Install visualization libraries
RUN pip3 install --no-cache-dir matplotlib morethemes==0.1.0 mplcyberpunk==0.3.1

# Install heavy dependencies individually to handle complex build requirements
# Install opencv-headless first to avoid X11 dependency issues for PySceneDetect
RUN pip3 install --no-cache-dir opencv-python-headless
RUN pip3 install --no-cache-dir PySceneDetect
RUN pip3 install --no-cache-dir librosa
RUN pip3 install --no-cache-dir geopandas contextily

# Install OpenAI Whisper
RUN pip3 install openai-whisper && \
    pip3 install playwright && \
    pip3 install jsonschema 

# Create the appuser 
RUN useradd -m appuser 

# Give appuser ownership of the /app directory (including whisper_cache)
RUN chown appuser:appuser /app 

# Important: Switch to the appuser before downloading the model
USER appuser

# Pre-load the base model to populate cache
RUN python3 -c "import os; print(os.environ.get('WHISPER_CACHE_DIR')); import whisper; whisper.load_model('base')"

# Install Playwright Chromium browser as appuser
RUN playwright install chromium

# Copy the rest of the application code
COPY . .

# Expose the port the app runs on
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1

RUN echo '#!/bin/bash\n\
    gunicorn --bind 0.0.0.0:8080 \
    --workers ${GUNICORN_WORKERS:-2} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --worker-class sync \
    --keep-alive 80 \
    --config gunicorn.conf.py \
    app:app' > /app/run_gunicorn.sh && \
    chmod +x /app/run_gunicorn.sh

# Run the shell script
CMD ["/app/run_gunicorn.sh"]
