FROM pytorch/pytorch:2.6.0-cuda12.4-cudnn9-devel
ENV DEBIAN_FRONTEND=noninteractive
#ENV PYTHONPATH=/workspace:${PYTHONPATH}

# System dependencies
RUN apt update && \
  apt install -y tzdata && \
  ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
  apt install -y netcat dnsutils && \
  apt-get update && \
  apt-get install -y libgl1-mesa-glx git libvulkan-dev \
  zip unzip wget curl git git-lfs build-essential cmake \
  vim less sudo htop ca-certificates man tmux tensorrt \
  # Add OpenCV system dependencies
  libglib2.0-0 libsm6 libxext6 libxrender-dev

RUN pip install --upgrade pip setuptools
RUN pip install gpustat wandb==0.19.0
# Create and set working directory
WORKDIR /workspace
# Copy pyproject.toml for dependencies
COPY pyproject.toml .
# Install dependencies from pyproject.toml
RUN pip install -e .[base]
# There's a conflict in the native python, so we have to resolve it by
RUN pip uninstall -y transformer-engine
RUN pip install flash_attn==2.7.1.post4 -U --force-reinstall
# Build ffmpeg
RUN sudo apt-get update -qq && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libgnutls28-dev \
  libmp3lame-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  meson \
  ninja-build \
  pkg-config \
  texinfo \
  wget \
  yasm \
  zlib1g-dev
RUN mkdir -p ~/ffmpeg_sources ~/bin
RUN cd ~/ffmpeg_sources && \
  wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-5.1.7.tar.bz2 && \
  tar xjvf ffmpeg-snapshot.tar.bz2
RUN sudo apt-get install -y nasm libx264-dev libx265-dev libnuma-dev libvpx-dev libfdk-aac-dev libopus-dev libunistring-dev
RUN cd ~/ffmpeg_sources && \
  git -C dav1d pull 2> /dev/null || git clone --depth 1 https://code.videolan.org/videolan/dav1d.git && \
  mkdir -p dav1d/build && \
  cd dav1d/build && \
  meson setup -Denable_tools=false -Denable_tests=false --default-library=static .. --prefix "$HOME/ffmpeg_build" --libdir="$HOME/ffmpeg_build/lib" && \
  ninja && \
  ninja install
RUN git clone --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
  cd SVT-AV1 && \
  cd Build && \
  cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release  && \
  make -j $(nproc)  && \
  sudo make install
RUN echo export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/x86_64-linux-gnu/pkgconfig:/root/ffmpeg_build/lib/pkgconfig >> $HOME/.bashrc && \ 
  cd ~/ffmpeg_sources/ffmpeg-5.1.7 && PATH="$HOME/bin:$PATH" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-gnutls \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libdav1d \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx264 \
  --enable-libx265 \
  --enable-nonfree \
  --enable-libdav1d \
  --enable-shared \
  --disable-static \
  --disable-vaapi && \
  echo export PATH=$HOME/bin:$PATH >> $HOME/.bashrc && \
  echo export PKG_CONFIG_LIBDIR=$PKG_CONFIG_LIBDIR:/root/ffmpeg_build/lib >> $HOME/.bashrc && \
  echo export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/lib/x86_64-linux-gnu/pkgconfig:/root/ffmpeg_build/lib/pkgconfig >> $HOME/.bashrc && \
  echo export LD_LIBRARY_PATH=/root/ffmpeg_build/lib >> $HOME/.bashrc && \
  PATH="$HOME/bin:$PATH" make && \
  make install && \
  hash -r
RUN pip install --force-reinstall torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 numpy==1.26.4
COPY getting_started /workspace/getting_started
COPY scripts /workspace/scripts
COPY demo_data /workspace/demo_data
RUN pip install -e . --no-deps
# need to install accelerate explicitly to avoid version conflicts
RUN pip install accelerate>=0.26.0
COPY gr00t /workspace/gr00t
COPY Makefile /workspace/Makefile
RUN pip3 install -e .
# Clean any existing OpenCV installations
RUN pip uninstall -y opencv-python opencv-python-headless || true
RUN rm -rf /usr/local/lib/python3.10/dist-packages/cv2 || true
# Install OpenCV 4.12
RUN sudo apt update && sudo apt install -y cmake g++ wget unzip
RUN wget -O ~/opencv.zip https://github.com/opencv/opencv/archive/refs/tags/4.11.0.zip
RUN unzip ~/opencv.zip
RUN mkdir -p build
WORKDIR /workspace/build
RUN cmake  ../opencv-4.11.0 \
  -D WITH_FFMPEG=ON \
  -D BUILD_opencv_python3=ON \
  -D PYTHON3_EXECUTABLE=$(which python) \
  -D PYTHON_INCLUDE_DIR=$(python3 -c "from sysconfig import get_paths; print(get_paths()['include'])") \
  -D PYTHON_LIBRARY=/opt/conda/lib/libpython3.11.so \
  -D PYTHON_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
RUN cmake --build .
RUN cp lib/python3/cv2.cpython-311-x86_64-linux-gnu.so /opt/conda/lib/python3.11/site-packages/
WORKDIR /workspace