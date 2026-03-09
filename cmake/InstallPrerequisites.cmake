#!/usr/bin/env cmake -P
#
# InstallPrerequisites.cmake
#
# Installs all external libraries required by OvenMediaEngine.
# Mirrors the logic of misc/prerequisites.sh, implemented as CMake script.
#
# Usage:
#   cmake -P cmake/InstallPrerequisites.cmake [options]
#
# Options (set via -D on the command line before -P):
#   -DPREFIX=/opt/ovenmediaengine          Installation prefix (default)
#   -DENABLE_NVIDIA=ON                     Enable NVIDIA nv-codec-headers + CUDA FFmpeg support
#   -DENABLE_QSV=ON                        Enable Intel QSV (libmfx) FFmpeg support
#   -DENABLE_XMA=ON                        Enable Xilinx XMA FFmpeg support
#   -DENABLE_NILOGAN=ON                    Enable Netint NiLogan FFmpeg support
#   -DNILOGAN_PATCH_PATH=<path>            Path to NiLogan FFmpeg patch file (required with ENABLE_NILOGAN)
#   -DNILOGAN_XCODER_COMPILE_PATH=<path>   Path to xcoder_logan source to compile (optional)
#   -DENABLE_X264=ON                       Enable libx264 (default ON)
#   -DOME_USE_CLANG=ON                     Install clang/lld and use as compiler (default ON)
#   -DTARGET=<name>                        Install only this target
#
# Example:
#   cmake -DENABLE_NVIDIA=ON -P cmake/InstallPrerequisites.cmake
#   cmake -DENABLE_XMA=ON -P cmake/InstallPrerequisites.cmake
#

cmake_minimum_required(VERSION 3.16)

# ==============================================================================
# Defaults
# ==============================================================================
if(NOT DEFINED PREFIX)
    set(PREFIX /opt/ovenmediaengine)
endif()
if(NOT DEFINED TEMP_PATH)
    set(TEMP_PATH "/tmp/ome_deps_$ENV{USER}")
endif()
if(NOT DEFINED ENABLE_X264)
    set(ENABLE_X264 ON)
endif()
if(NOT DEFINED ENABLE_NVIDIA)
    set(ENABLE_NVIDIA OFF)
endif()
if(NOT DEFINED ENABLE_QSV)
    set(ENABLE_QSV OFF)
endif()
if(NOT DEFINED ENABLE_XMA)
    set(ENABLE_XMA OFF)
endif()
if(NOT DEFINED ENABLE_NILOGAN)
    set(ENABLE_NILOGAN OFF)
endif()
if(NOT DEFINED NILOGAN_PATCH_PATH)
    set(NILOGAN_PATCH_PATH "")
endif()
if(NOT DEFINED NILOGAN_XCODER_COMPILE_PATH)
    set(NILOGAN_XCODER_COMPILE_PATH "")
endif()
if(NOT DEFINED OME_USE_CLANG)
    set(OME_USE_CLANG ON)
endif()

# Library versions - defined in a shared file so Dependencies.cmake can use the same values.
include("${CMAKE_CURRENT_LIST_DIR}/Versions.cmake")
set(OPENSSL_VERSION     ${OME_VER_OPENSSL})
set(SRTP_VERSION        ${OME_VER_SRTP})
set(SRT_VERSION         ${OME_VER_SRT})
set(OPUS_VERSION        ${OME_VER_OPUS})
set(VPX_VERSION         ${OME_VER_VPX})
set(FDKAAC_VERSION      ${OME_VER_FDKAAC})
set(NASM_VERSION        ${OME_VER_NASM})
set(FFMPEG_VERSION      ${OME_VER_FFMPEG})
set(JEMALLOC_VERSION    ${OME_VER_JEMALLOC})
set(PCRE2_VERSION       ${OME_VER_PCRE2})
set(OPENH264_VERSION    ${OME_VER_OPENH264})
set(HIREDIS_VERSION     ${OME_VER_HIREDIS})
set(NVCC_HDR_VERSION    ${OME_VER_NVCC_HDR})
set(X264_VERSION        ${OME_VER_X264})
set(WEBP_VERSION        ${OME_VER_WEBP})
set(SPDLOG_VERSION      ${OME_VER_SPDLOG})
set(WHISPER_VERSION     ${OME_VER_WHISPER})

# ==============================================================================
# Detect OS
# ==============================================================================
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
    if(EXISTS /etc/os-release)
        file(READ /etc/os-release _os_release)
        string(REGEX MATCH "^NAME=\"?([^\"\n]+)\"?" _m "${_os_release}")
        set(OSNAME "${CMAKE_MATCH_1}")
        string(REGEX MATCH "VERSION=\"?([0-9]+)" _m "${_os_release}")
        set(OSVERSION "${CMAKE_MATCH_1}")
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    set(OSNAME "Mac OS X")
endif()

message(STATUS "[OME Prerequisites] OS: ${OSNAME} ${OSVERSION}")
message(STATUS "[OME Prerequisites] Prefix: ${PREFIX}")

# ==============================================================================
# Helper: run shell command and fail loudly
# ==============================================================================
macro(ome_run cmd label)
    message(STATUS "[OME Prerequisites] Building: ${label}")
    set(_ome_script "${TEMP_PATH}/_ome_${label}.sh")
    file(WRITE "${_ome_script}" "#!/bin/bash\nset -e\n${cmd}\n")
    execute_process(
        COMMAND bash "${_ome_script}"
        RESULT_VARIABLE _ret
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )
    file(REMOVE "${_ome_script}")
    if(NOT _ret EQUAL 0)
        message(FATAL_ERROR "[OME Prerequisites] FAILED: ${label}")
    endif()
endmacro()

# ==============================================================================
# Install base packages
# ==============================================================================
if(OSNAME MATCHES "Ubuntu")
    ome_run("sudo apt-get install -y build-essential autoconf libtool zlib1g-dev \
        tclsh cmake curl pkg-config bc uuid-dev git libgomp1 ninja-build" "apt base packages")
elseif(OSNAME MATCHES "Rocky|AlmaLinux|Red")
    ome_run("sudo dnf install -y bc gcc-c++ autoconf libtool tcl bzip2 zlib-devel \
        cmake libuuid-devel which diffutils perl-IPC-Cmd git libgomp ninja-build" "dnf base packages")
elseif(OSNAME MATCHES "Amazon Linux")
    ome_run("sudo yum install -y bc gcc-c++ autoconf libtool tcl bzip2 zlib-devel \
        cmake libuuid-devel perl-IPC-Cmd git libgomp ninja-build" "yum base packages")
elseif(OSNAME MATCHES "Fedora")
    ome_run("sudo yum install -y gcc-c++ make autoconf libtool zlib-devel tcl cmake \
        bc libuuid-devel perl-IPC-Cmd git libgomp ninja-build" "yum base packages (fedora)")
elseif(OSNAME MATCHES "Mac OS X")
    ome_run("brew install pkg-config nasm automake libtool xz cmake make ninja" "brew base packages")
else()
    message(WARNING "[OME Prerequisites] Unsupported OS: ${OSNAME}. Skipping base package installation.")
endif()

# ==============================================================================
# Install Clang (when OME_USE_CLANG=ON, which is the default)
# ==============================================================================
if(OME_USE_CLANG)
    message(STATUS "[OME Prerequisites] Installing clang/lld (OME_USE_CLANG=ON)")
    if(OSNAME MATCHES "Ubuntu")
        ome_run("sudo apt-get install -y clang lld" "apt clang")
    elseif(OSNAME MATCHES "Rocky|AlmaLinux|Red")
        ome_run("sudo dnf install -y clang lld" "dnf clang")
    elseif(OSNAME MATCHES "Amazon Linux")
        ome_run("sudo yum install -y clang" "yum clang")
    elseif(OSNAME MATCHES "Fedora")
        ome_run("sudo yum install -y clang lld" "yum clang (fedora)")
    elseif(OSNAME MATCHES "Mac OS X")
        # Xcode CLT ships clang; nothing extra needed
        message(STATUS "[OME Prerequisites] macOS: Xcode CLT already provides clang. Skipping.")
    else()
        message(WARNING "[OME Prerequisites] Unsupported OS: ${OSNAME}. Skipping clang installation.")
    endif()
else()
    message(STATUS "[OME Prerequisites] OME_USE_CLANG=OFF - skipping clang installation")
endif()

# ==============================================================================
# Individual install functions (implemented as cmake variables holding shell code)
# ==============================================================================

set(_COMMON_ENV "PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib64/pkgconfig:$PKG_CONFIG_PATH")
set(_J "-j$(nproc)")

# ---- NASM ----
set(_install_nasm "
mkdir -p ${TEMP_PATH}/nasm && cd ${TEMP_PATH}/nasm &&
curl -sSLf https://github.com/netwide-assembler/nasm/archive/refs/tags/nasm-${NASM_VERSION}.tar.gz | tar -xz --strip-components=1 &&
./autogen.sh && ./configure --prefix=${PREFIX} &&
make ${_J} && touch nasm.1 ndisasm.1 && sudo make install && rm -rf ${TEMP_PATH}/nasm
")

# ---- OpenSSL ----
set(_install_openssl "
mkdir -p ${TEMP_PATH}/openssl && cd ${TEMP_PATH}/openssl &&
curl -sSLf https://github.com/openssl/openssl/archive/openssl-${OPENSSL_VERSION}.tar.gz | tar -xz --strip-components=1 &&
./config --prefix=${PREFIX} --openssldir=${PREFIX} --libdir=lib -Wl,-rpath,${PREFIX}/lib shared no-idea no-mdc2 no-rc5 no-ec2m no-ecdh no-ecdsa no-async &&
make ${_J} && sudo make install_sw && rm -rf ${TEMP_PATH}/openssl
")

# ---- libsrtp ----
set(_install_libsrtp "
mkdir -p ${TEMP_PATH}/srtp && cd ${TEMP_PATH}/srtp &&
curl -sSLf https://github.com/cisco/libsrtp/archive/v${SRTP_VERSION}.tar.gz | tar -xz --strip-components=1 &&
${_COMMON_ENV} ./configure --prefix=${PREFIX} --enable-openssl --with-openssl-dir=${PREFIX} &&
make ${_J} shared_library && sudo make install && rm -rf ${TEMP_PATH}/srtp
")

# ---- SRT ----
set(_install_libsrt "
mkdir -p ${TEMP_PATH}/srt && cd ${TEMP_PATH}/srt &&
curl -sSLf https://github.com/Haivision/srt/archive/v${SRT_VERSION}.tar.gz | tar -xz --strip-components=1 &&
${_COMMON_ENV} ./configure --prefix=${PREFIX} --enable-shared --disable-static &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/srt
")

# ---- Opus ----
set(_install_libopus "
mkdir -p ${TEMP_PATH}/opus && cd ${TEMP_PATH}/opus &&
curl -sSLf https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz | tar -xz --strip-components=1 &&
autoreconf -fiv && ./configure --prefix=${PREFIX} --enable-shared --disable-static &&
make ${_J} && sudo make install && sudo rm -rf ${PREFIX}/share && rm -rf ${TEMP_PATH}/opus
")

# ---- libvpx ----
set(_install_libvpx "
mkdir -p ${TEMP_PATH}/vpx && cd ${TEMP_PATH}/vpx &&
curl -sSLf https://codeload.github.com/webmproject/libvpx/tar.gz/v${VPX_VERSION} | tar -xz --strip-components=1 &&
./configure --prefix=${PREFIX} --enable-vp8 --enable-pic --enable-shared --disable-static --disable-vp9 --disable-debug --disable-examples --disable-docs --disable-install-bins &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/vpx
")

# ---- libwebp ----
set(_install_libwebp "
mkdir -p ${TEMP_PATH}/webp && cd ${TEMP_PATH}/webp &&
curl -sSLf https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz | tar -xz --strip-components=1 &&
./configure --prefix=${PREFIX} --enable-shared --disable-static &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/webp
")

# ---- fdk-aac ----
set(_install_fdk_aac "
mkdir -p ${TEMP_PATH}/aac && cd ${TEMP_PATH}/aac &&
curl -sSLf https://github.com/mstorsjo/fdk-aac/archive/v${FDKAAC_VERSION}.tar.gz | tar -xz --strip-components=1 &&
autoreconf -fiv && ./configure --prefix=${PREFIX} --enable-shared --disable-static --datadir=/tmp/aac &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/aac
")

# ---- openh264 ----
set(_install_libopenh264 "
mkdir -p ${TEMP_PATH}/openh264 && cd ${TEMP_PATH}/openh264 &&
curl -sSLf https://github.com/cisco/openh264/archive/refs/tags/v${OPENH264_VERSION}.tar.gz | tar -xz --strip-components=1 &&
sed -i -e 's|PREFIX=/usr/local|PREFIX=${PREFIX}|' Makefile &&
make OS=linux && sudo make install && rm -rf ${TEMP_PATH}/openh264
")

# ---- x264 (optional) ----
set(_install_libx264 "
mkdir -p ${TEMP_PATH}/x264 && cd ${TEMP_PATH}/x264 &&
curl -sLf https://code.videolan.org/videolan/x264/-/archive/master/x264-${X264_VERSION}.tar.bz2 | tar -jx --strip-components=1 &&
./configure --prefix=${PREFIX} --enable-shared --enable-pic --disable-cli &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/x264
")

# ---- nv-codec-headers (optional) ----
set(_install_nvcc_hdr "
mkdir -p ${TEMP_PATH}/nvcc-hdr && cd ${TEMP_PATH}/nvcc-hdr &&
curl -sSLf https://github.com/FFmpeg/nv-codec-headers/releases/download/n${NVCC_HDR_VERSION}/nv-codec-headers-${NVCC_HDR_VERSION}.tar.gz | tar -xz --strip-components=1 &&
sed -i 's|PREFIX.*=\\(.*\\)|PREFIX = ${PREFIX}|g' Makefile && sudo make install
")

# ---- FFmpeg ----
set(_FFMPEG_ADDI_LICENSE      "")
set(_FFMPEG_ADDI_LIBS         "--disable-nvdec --disable-vaapi --disable-vdpau --disable-cuda-llvm --disable-cuvid --disable-ffnvcodec")
set(_FFMPEG_ADDI_ENCODER      "")
set(_FFMPEG_ADDI_DECODER      "")
set(_FFMPEG_ADDI_FILTERS      "")
set(_FFMPEG_ADDI_CFLAGS       "")
set(_FFMPEG_ADDI_LDFLAGS      "")
set(_FFMPEG_ADDI_EXTRA_LIBS   "")
set(_FFMPEG_PATCH_CMDS        "")

# scte35 patch (always applied if patch file exists)
set(_SCTE35_PATCH "${CMAKE_CURRENT_LIST_DIR}/../misc/patches/ffmpeg_n${FFMPEG_VERSION}_scte35.patch")
if(EXISTS "${_SCTE35_PATCH}")
    string(APPEND _FFMPEG_PATCH_CMDS "patch -p1 < ${_SCTE35_PATCH} && \n")
endif()

if(ENABLE_X264)
    string(APPEND _FFMPEG_ADDI_LIBS    " --enable-libx264")
    string(APPEND _FFMPEG_ADDI_ENCODER ",libx264")
    string(APPEND _FFMPEG_ADDI_LICENSE " --enable-gpl --enable-nonfree")
endif()

if(ENABLE_NVIDIA)
    string(APPEND _FFMPEG_ADDI_LIBS    " --enable-cuda-nvcc --enable-cuda-llvm --enable-nvenc --enable-nvdec --enable-ffnvcodec --enable-cuvid")
    string(APPEND _FFMPEG_ADDI_ENCODER ",h264_nvenc,hevc_nvenc")
    string(APPEND _FFMPEG_ADDI_DECODER ",h264_cuvid,hevc_cuvid")
    string(APPEND _FFMPEG_ADDI_FILTERS ",scale_cuda,hwdownload,hwupload,hwupload_cuda")
    string(APPEND _FFMPEG_ADDI_CFLAGS  " -I/usr/local/cuda/include")
    string(APPEND _FFMPEG_ADDI_LDFLAGS " -L/usr/local/cuda/lib64")
    string(APPEND _FFMPEG_ADDI_LICENSE " --enable-nonfree")
endif()

if(ENABLE_QSV)
    string(APPEND _FFMPEG_ADDI_LIBS    " --enable-libmfx")
    string(APPEND _FFMPEG_ADDI_ENCODER ",h264_qsv,hevc_qsv")
    string(APPEND _FFMPEG_ADDI_DECODER ",vp8_qsv,h264_qsv,hevc_qsv")
endif()

if(ENABLE_XMA)
    set(_XMA_PATCH "${CMAKE_CURRENT_LIST_DIR}/../misc/patches/ffmpeg_n${FFMPEG_VERSION}_u30ma.patch")
    if(EXISTS "${_XMA_PATCH}")
        string(APPEND _FFMPEG_PATCH_CMDS "patch -p1 < ${_XMA_PATCH} && \n")
    else()
        message(WARNING "[OME Prerequisites] XMA patch not found: ${_XMA_PATCH}")
    endif()
    string(APPEND _FFMPEG_ADDI_LIBS      " --enable-x86asm --enable-libxma2api --enable-libxvbm --enable-libxrm --enable-cross-compile")
    string(APPEND _FFMPEG_ADDI_ENCODER   ",h264_vcu_mpsoc,hevc_vcu_mpsoc")
    string(APPEND _FFMPEG_ADDI_DECODER   ",h264_vcu_mpsoc,hevc_vcu_mpsoc")
    string(APPEND _FFMPEG_ADDI_FILTERS   ",multiscale_xma,xvbm_convert")
    string(APPEND _FFMPEG_ADDI_CFLAGS    " -I/opt/xilinx/xrt/include/xma2")
    string(APPEND _FFMPEG_ADDI_LDFLAGS   " -L/opt/xilinx/xrt/lib -L/opt/xilinx/xrm/lib -Wl,-rpath,/opt/xilinx/xrt/lib,-rpath,/opt/xilinx/xrm/lib")
    string(APPEND _FFMPEG_ADDI_EXTRA_LIBS " --extra-libs=-lxma2api --extra-libs=-lxrt_core --extra-libs=-lxrm --extra-libs=-lxrt_coreutil --extra-libs=-lpthread --extra-libs=-ldl")
endif()

if(ENABLE_NILOGAN)
    if(NILOGAN_PATCH_PATH AND EXISTS "${NILOGAN_PATCH_PATH}")
        string(APPEND _FFMPEG_PATCH_CMDS "cp ${NILOGAN_PATCH_PATH} . && patch -t -p1 < \$(basename ${NILOGAN_PATCH_PATH}) && \n")
    else()
        message(WARNING "[OME Prerequisites] ENABLE_NILOGAN=ON but NILOGAN_PATCH_PATH not set or not found")
    endif()
    if(NILOGAN_XCODER_COMPILE_PATH AND NOT NILOGAN_XCODER_COMPILE_PATH STREQUAL "")
        string(APPEND _FFMPEG_PATCH_CMDS "(cd ${NILOGAN_XCODER_COMPILE_PATH} && bash build.sh && ldconfig) && \n")
    endif()
    string(APPEND _FFMPEG_ADDI_LIBS    " --enable-libxcoder_logan --enable-ni_logan --enable-avfilter --enable-pthreads")
    string(APPEND _FFMPEG_ADDI_ENCODER ",h264_ni_logan,h265_ni_logan")
    string(APPEND _FFMPEG_ADDI_DECODER ",h264_ni_logan,h265_ni_logan")
    string(APPEND _FFMPEG_ADDI_FILTERS ",hwdownload,hwupload,hwupload_ni_logan")
    string(APPEND _FFMPEG_ADDI_LICENSE " --enable-gpl --enable-nonfree")
    string(APPEND _FFMPEG_ADDI_LDFLAGS " -lm -ldl")
endif()

set(_FFMPEG_CONFIGURE_CMD
    "${_COMMON_ENV} ./configure"
    "--prefix=${PREFIX}"
    "--disable-everything --disable-programs --disable-avdevice --disable-dwt --disable-lsp --disable-faan --disable-pixelutils"
    "--enable-shared --disable-static --enable-pic"
    "--enable-zlib --enable-libopus --enable-libvpx --enable-libfdk_aac --enable-libopenh264 --enable-openssl"
    "--enable-network --enable-libsrt --enable-dct --enable-rdft --enable-libwebp"
    "--extra-cflags=\"-I${PREFIX}/include${_FFMPEG_ADDI_CFLAGS}\""
    "--extra-ldflags=\"-L${PREFIX}/lib -Wl,-rpath,${PREFIX}/lib -Wl,--disable-new-dtags${_FFMPEG_ADDI_LDFLAGS}\""
    "--extra-libs=-ldl"
    "${_FFMPEG_ADDI_EXTRA_LIBS}"
    "${_FFMPEG_ADDI_LICENSE}"
    "${_FFMPEG_ADDI_LIBS}"
    "--enable-encoder=libvpx_vp8,libopus,libfdk_aac,libopenh264,mjpeg,png,libwebp${_FFMPEG_ADDI_ENCODER}"
    "--enable-decoder=aac,aac_latm,aac_fixed,mp3float,mp3,h264,hevc,opus,vp8,mjpeg,png${_FFMPEG_ADDI_DECODER}"
    "--enable-parser=aac,aac_latm,aac_fixed,h264,hevc,opus,vp8,png,jpg"
    "--enable-protocol=tcp,udp,rtp,file,rtmp,tls,rtmps,libsrt"
    "--enable-demuxer=rtsp,flv,live_flv,mp4,mp3,image2"
    "--enable-muxer=mp4,webm,mpegts,flv,mpjpeg"
    "--enable-filter=asetnsamples,aresample,aformat,channelmap,channelsplit,scale,transpose,fps,settb,asettb,crop,format${_FFMPEG_ADDI_FILTERS}"
)
list(JOIN _FFMPEG_CONFIGURE_CMD " " _FFMPEG_CONFIGURE_LINE)

set(_install_ffmpeg "
mkdir -p ${TEMP_PATH}/ffmpeg && cd ${TEMP_PATH}/ffmpeg &&
curl -sSLf https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n${FFMPEG_VERSION}.tar.gz | tar -xz --strip-components=1 &&
${_FFMPEG_PATCH_CMDS}${_FFMPEG_CONFIGURE_LINE} &&
make ${_J} && sudo make install && sudo rm -rf ${PREFIX}/share && rm -rf ${TEMP_PATH}/ffmpeg
")

# ---- stubs ----
# Built via CMake (misc/stubs/CMakeLists.txt) instead of the legacy Makefile.
set(_STUB_DIR "${CMAKE_CURRENT_LIST_DIR}/..")
set(_install_stubs "
cmake -S ${_STUB_DIR} -B ${_STUB_DIR}/build/stubs -DOME_BUILD_STUBS=ON -DCMAKE_INSTALL_PREFIX=${PREFIX} &&
cmake --build ${_STUB_DIR}/build/stubs --target stubs -j$(nproc) &&
sudo cmake --install ${_STUB_DIR}/build/stubs --component stubs
")

# ---- jemalloc ----
set(_install_jemalloc "
mkdir -p ${TEMP_PATH}/jemalloc && cd ${TEMP_PATH}/jemalloc &&
curl -sSLf https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2 | tar -jx --strip-components=1 &&
./configure --prefix=${PREFIX} --enable-shared &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/jemalloc
")

# ---- PCRE2 ----
set(_install_libpcre2 "
mkdir -p ${TEMP_PATH}/pcre2 && cd ${TEMP_PATH}/pcre2 &&
curl -sSLf https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/pcre2-${PCRE2_VERSION}.tar.gz | tar -xz --strip-components=1 &&
./configure --prefix=${PREFIX} --enable-shared --disable-static &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/pcre2
")

# ---- hiredis ----
set(_install_hiredis "
mkdir -p ${TEMP_PATH}/hiredis && cd ${TEMP_PATH}/hiredis &&
curl -sSLf https://github.com/redis/hiredis/archive/refs/tags/v${HIREDIS_VERSION}.tar.gz | tar -xz --strip-components=1 &&
make ${_J} PREFIX=${PREFIX} && sudo make install PREFIX=${PREFIX} && rm -rf ${TEMP_PATH}/hiredis
")

# ---- spdlog ----
set(_install_spdlog "
mkdir -p ${TEMP_PATH}/spdlog && cd ${TEMP_PATH}/spdlog &&
curl -sSLf https://github.com/gabime/spdlog/archive/refs/tags/v${SPDLOG_VERSION}.tar.gz | tar -xz --strip-components=1 &&
mkdir -p build && cd build &&
cmake .. -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib &&
make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/spdlog
")

# ---- whisper.cpp ----
set(_WHISPER_CUDA 0)
if(ENABLE_NVIDIA)
    set(_WHISPER_CUDA 1)
endif()
set(_WHISPER_CMAKE_ARGS
    "cmake -B build -S ."
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=${PREFIX}"
    "-DCMAKE_INSTALL_RPATH=${PREFIX}/lib"
    "-DBUILD_SHARED_LIBS=ON"
    "-DWHISPER_BUILD_EXAMPLES=OFF"
    "-DWHISPER_BUILD_TESTS=OFF"
    "-DWHISPER_BUILD_SERVER=OFF"
    "-DGGML_CUDA=${_WHISPER_CUDA}"
    "-DCMAKE_CUDA_ARCHITECTURES=61;75;86"
)
list(JOIN _WHISPER_CMAKE_ARGS " " _WHISPER_CMAKE_LINE)
set(_install_whisper "
mkdir -p ${TEMP_PATH}/whisper && cd ${TEMP_PATH}/whisper &&
curl -sSLf https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v${WHISPER_VERSION}.tar.gz | tar -xz --strip-components=1 &&
${_WHISPER_CMAKE_LINE} &&
cd build && make ${_J} && sudo make install && rm -rf ${TEMP_PATH}/whisper
")

# ==============================================================================
# Install sequence
# ==============================================================================
set(_targets
    nasm
    openssl
    libsrtp
    libsrt
    libopus
    libopenh264
    libvpx
    libwebp
    fdk_aac
    ffmpeg
    stubs
    jemalloc
    libpcre2
    hiredis
    spdlog
    whisper
)

if(ENABLE_X264)
    list(INSERT _targets 5 libx264)
endif()

if(ENABLE_NVIDIA)
    list(APPEND _targets nvcc_hdr)
endif()

# Override with single target if requested
if(DEFINED TARGET)
    if("${TARGET}" STREQUAL "ffmpeg")
        # ffmpeg depends on codec libs; install them first in case they are missing
        set(_ffmpeg_deps nasm libopus libvpx libwebp libopenh264 fdk_aac)
        if(ENABLE_X264)
            list(APPEND _ffmpeg_deps libx264)
        endif()
        if(ENABLE_NVIDIA)
            list(APPEND _ffmpeg_deps nvcc_hdr)
        endif()
        set(_targets ${_ffmpeg_deps} ffmpeg)
    else()
        set(_targets ${TARGET})
    endif()
endif()

message(STATUS "[OME Prerequisites] Install targets: ${_targets}")
message(STATUS "[OME Prerequisites] This will build and install to: ${PREFIX}")
message(STATUS "[OME Prerequisites] Temp directory: ${TEMP_PATH}")

file(MAKE_DIRECTORY ${TEMP_PATH})

foreach(_t ${_targets})
    if(DEFINED _install_${_t})
        ome_run("${_install_${_t}}" "${_t}")
    else()
        message(WARNING "[OME Prerequisites] No install script for: ${_t}")
    endif()
endforeach()

message(STATUS "[OME Prerequisites] All dependencies installed successfully.")
file(REMOVE_RECURSE "${TEMP_PATH}")
message(STATUS "[OME Prerequisites] Cleaned up temp directory: ${TEMP_PATH}")
message(STATUS "[OME Prerequisites] You can now configure and build OvenMediaEngine:")
message(STATUS "  cmake -Bbuild -DCMAKE_BUILD_TYPE=Release .")
message(STATUS "  cmake --build build -j\$(nproc)")
