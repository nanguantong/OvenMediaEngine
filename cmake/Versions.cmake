#
# Versions.cmake
# Single source of truth for all external dependency versions.
# Included by both InstallPrerequisites.cmake and Dependencies.cmake.
#

# These versions must stay in sync with what InstallPrerequisites.cmake builds.
# When upgrading a dependency, change the version here only.
set(OME_VER_OPENSSL     3.0.7)
set(OME_VER_SRTP        2.4.2)
set(OME_VER_SRT         1.5.2)
set(OME_VER_OPUS        1.3.1)
set(OME_VER_VPX         1.11.0)
set(OME_VER_FDKAAC      2.0.2)
set(OME_VER_NASM        2.15.05)
set(OME_VER_FFMPEG      5.1.4)
set(OME_VER_JEMALLOC    5.3.0)
set(OME_VER_PCRE2       10.39)
set(OME_VER_OPENH264    2.4.0)
set(OME_VER_HIREDIS     1.0.2)
set(OME_VER_NVCC_HDR    11.1.5.2)
set(OME_VER_X264        31e19f92)
set(OME_VER_WEBP        1.5.0)
set(OME_VER_SPDLOG      1.15.1)
set(OME_VER_WHISPER     1.8.2)

# FFmpeg sub-library versions (from FFmpeg ${OME_VER_FFMPEG})
# These differ from the release version — obtained via pkg-config --modversion.
set(OME_VER_LIBAVFORMAT     59.27.100)
set(OME_VER_LIBAVFILTER     8.44.100)
set(OME_VER_LIBAVCODEC      59.37.100)
set(OME_VER_LIBSWRESAMPLE   4.7.100)
set(OME_VER_LIBSWSCALE      6.7.100)
set(OME_VER_LIBAVUTIL       57.28.100)
