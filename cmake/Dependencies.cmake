#
# Dependencies.cmake
# Locate all external libraries used by OvenMediaEngine via pkg-config.
# The custom search path ${OME_DEP_PREFIX}/lib/pkgconfig is set by
# CompilerOptions.cmake via ENV{PKG_CONFIG_PATH}.
# Exact version matching (=) is required — higher versions also trigger reinstall.
#

include(Versions)   # OME_VER_* constants shared with InstallPrerequisites.cmake
find_package(PkgConfig REQUIRED)

# ------------------------------------------------------------------------------
# Helper: import a pkg-config package and create a canonical CMake imported
# target called PkgConfig::<PKG_VAR> (same as ome_target_pkg_config uses).
#
# Usage: ome_find_pkg(<variable-prefix> <pkg-config-name> [REQUIRED|OPTIONAL])
# ------------------------------------------------------------------------------
# ome_find_pkg(VAR "pkg=VERSION" [OPTIONAL] [REINSTALL_TARGET target])
#
# Finds a pkg-config package with an exact version constraint.
# If not found or version differs, re-runs InstallPrerequisites for the
# specific REINSTALL_TARGET only (or the full prerequisites if not specified).
macro(ome_find_pkg var pkg)
    cmake_parse_arguments(_FP "OPTIONAL" "REINSTALL_TARGET" "EXTRA_ARGS" ${ARGN})

    # Always clear cached result so pkg-config re-runs every configure.
    # This ensures a deleted/changed OME_DEP_PREFIX is detected immediately
    # instead of silently using stale cached paths.
    unset(${var}_FOUND CACHE)
    unset(${var}_INCLUDE_DIRS CACHE)
    unset(${var}_LIBRARY_DIRS CACHE)
    unset(${var}_LIBRARIES CACHE)
    unset(${var}_VERSION CACHE)

    pkg_check_modules(${var} IMPORTED_TARGET ${pkg})

    if(NOT ${var}_FOUND)
        # Build hwaccel forwarding args for InstallPrerequisites.cmake
        set(_FP_HWACCEL_ARGS)
        if(OME_HWACCEL_NVIDIA)
            list(APPEND _FP_HWACCEL_ARGS -DENABLE_NVIDIA=ON)
        endif()
        if(OME_HWACCEL_QSV)
            list(APPEND _FP_HWACCEL_ARGS -DENABLE_QSV=ON)
        endif()
        if(OME_HWACCEL_XMA)
            list(APPEND _FP_HWACCEL_ARGS -DENABLE_XMA=ON)
        endif()
        if(OME_HWACCEL_NILOGAN)
            list(APPEND _FP_HWACCEL_ARGS -DENABLE_NILOGAN=ON)
            if(OME_NILOGAN_PATCH_PATH AND NOT OME_NILOGAN_PATCH_PATH STREQUAL "")
                list(APPEND _FP_HWACCEL_ARGS "-DNILOGAN_PATCH_PATH=${OME_NILOGAN_PATCH_PATH}")
            endif()
            if(OME_NILOGAN_XCODER_COMPILE_PATH AND NOT OME_NILOGAN_XCODER_COMPILE_PATH STREQUAL "")
                list(APPEND _FP_HWACCEL_ARGS "-DNILOGAN_XCODER_COMPILE_PATH=${OME_NILOGAN_XCODER_COMPILE_PATH}")
            endif()
        endif()
        if(OME_SKIP_DEPENDENCY_CHECK)
            # Auto-install suppressed - report only
        elseif(_FP_REINSTALL_TARGET)
            message(STATUS "[OME] '${pkg}' not found or wrong version - reinstalling '${_FP_REINSTALL_TARGET}' ...")
            execute_process(
                COMMAND ${CMAKE_COMMAND}
                    -DPREFIX=${OME_DEP_PREFIX}
                    -DTARGET=${_FP_REINSTALL_TARGET}
                    ${_FP_HWACCEL_ARGS}
                    ${_FP_EXTRA_ARGS}
                    -P "${CMAKE_SOURCE_DIR}/cmake/InstallPrerequisites.cmake"
                RESULT_VARIABLE _install_result
            )
        elseif(NOT _FP_OPTIONAL)
            message(STATUS "[OME] '${pkg}' not found - running InstallPrerequisites.cmake ...")
            execute_process(
                COMMAND ${CMAKE_COMMAND}
                    -DPREFIX=${OME_DEP_PREFIX}
                    ${_FP_HWACCEL_ARGS}
                    ${_FP_EXTRA_ARGS}
                    -P "${CMAKE_SOURCE_DIR}/cmake/InstallPrerequisites.cmake"
                RESULT_VARIABLE _install_result
            )
        endif()
        if(DEFINED _install_result AND NOT _install_result EQUAL 0)
            message(FATAL_ERROR "[OME] Install failed for '${pkg}' (exit ${_install_result}).\n"
                "  Run manually: cmake -P cmake/InstallPrerequisites.cmake")
        endif()
        if(NOT OME_SKIP_DEPENDENCY_CHECK)
            pkg_check_modules(${var} IMPORTED_TARGET ${pkg})
        endif()
    endif()

    if(${var}_FOUND)
        message(STATUS "[OME] Found ${pkg}: ${${var}_VERSION}")
    elseif(NOT _FP_OPTIONAL)
        message(FATAL_ERROR "[OME] Required package '${pkg}' still not found after install.\n"
            "  Run manually: cmake -P cmake/InstallPrerequisites.cmake")
    else()
        message(STATUS "[OME] Optional package '${pkg}' NOT found - disabling")
    endif()

    unset(_FP_OPTIONAL)
    unset(_FP_REINSTALL_TARGET)
    unset(_install_result)
endmacro()

# ==============================================================================
# Required dependencies  (exact version required; wrong/newer version → targeted reinstall)
# ==============================================================================
ome_find_pkg(PKG_OPENSSL       "openssl=${OME_VER_OPENSSL}"               REINSTALL_TARGET openssl)
ome_find_pkg(PKG_SRT           "srt=${OME_VER_SRT}"                       REINSTALL_TARGET libsrt)
ome_find_pkg(PKG_LIBSRTP2      "libsrtp2=${OME_VER_SRTP}"                 REINSTALL_TARGET libsrtp)
ome_find_pkg(PKG_LIBAVFORMAT   "libavformat=${OME_VER_LIBAVFORMAT}"       REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_LIBAVFILTER   "libavfilter=${OME_VER_LIBAVFILTER}"       REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_LIBAVCODEC    "libavcodec=${OME_VER_LIBAVCODEC}"         REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_LIBSWRESAMPLE "libswresample=${OME_VER_LIBSWRESAMPLE}"   REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_LIBSWSCALE    "libswscale=${OME_VER_LIBSWSCALE}"         REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_LIBAVUTIL     "libavutil=${OME_VER_LIBAVUTIL}"           REINSTALL_TARGET ffmpeg)
ome_find_pkg(PKG_VPX           "vpx=${OME_VER_VPX}"                       REINSTALL_TARGET libvpx)
ome_find_pkg(PKG_OPUS          "opus=${OME_VER_OPUS}"                     REINSTALL_TARGET libopus)
ome_find_pkg(PKG_LIBPCRE2_8    "libpcre2-8=${OME_VER_PCRE2}"              REINSTALL_TARGET libpcre2)
ome_find_pkg(PKG_HIREDIS       "hiredis=${OME_VER_HIREDIS}"               REINSTALL_TARGET hiredis)
ome_find_pkg(PKG_SPDLOG        "spdlog=${OME_VER_SPDLOG}"                 REINSTALL_TARGET spdlog)
ome_find_pkg(PKG_WHISPER       "whisper=${OME_VER_WHISPER}"               REINSTALL_TARGET whisper)

# ==============================================================================
# Optional / hardware-accelerated dependencies
# ==============================================================================

# NVIDIA NVENC/NVDEC
if(OME_HWACCEL_NVIDIA)
    ome_find_pkg(PKG_FFNVCODEC ffnvcodec OPTIONAL)
    if(NOT PKG_FFNVCODEC_FOUND)
        # Auto-install nv-codec-headers with NVIDIA flag forwarded
        message(STATUS "[OME] ffnvcodec not found - installing nv-codec-headers ...")
        execute_process(
            COMMAND ${CMAKE_COMMAND}
                -DPREFIX=${OME_DEP_PREFIX}
                -DENABLE_NVIDIA=ON
                -DTARGET=nvcc_hdr
                -P "${CMAKE_SOURCE_DIR}/cmake/InstallPrerequisites.cmake"
            RESULT_VARIABLE _ret
        )
        if(_ret EQUAL 0)
            pkg_check_modules(PKG_FFNVCODEC IMPORTED_TARGET ffnvcodec)
        endif()
    endif()
    if(PKG_FFNVCODEC_FOUND)
        message(STATUS "[OME] NVIDIA hardware acceleration: ENABLED")
        add_compile_definitions(HWACCELS_NVIDIA_ENABLED)
        include_directories(/usr/local/cuda/include)
        link_directories(/usr/local/cuda/lib64 /usr/local/cuda/lib64/stubs)
        set(OME_NVIDIA_LIBS cuda cudart nvidia-ml)
    else()
        message(WARNING "[OME] OME_HWACCEL_NVIDIA=ON but ffnvcodec still not found - disabling")
        set(OME_HWACCEL_NVIDIA OFF)
    endif()
endif()

# Intel QSV
if(OME_HWACCEL_QSV)
    pkg_check_modules(PKG_LIBMFX IMPORTED_TARGET libmfx)
    if(PKG_LIBMFX_FOUND)
        message(STATUS "[OME] Intel QSV hardware acceleration: ENABLED")
        add_compile_definitions(HWACCELS_QSV_ENABLED)
    else()
        message(WARNING "[OME] OME_HWACCEL_QSV=ON but libmfx not found")
        set(OME_HWACCEL_QSV OFF)
    endif()
endif()

# Xilinx XMA
if(OME_HWACCEL_XMA)
    ome_find_pkg(PKG_LIBXMA2API libxma2api OPTIONAL)
    ome_find_pkg(PKG_XVBM       xvbm       OPTIONAL)
    ome_find_pkg(PKG_LIBXRM     libxrm     OPTIONAL)
    if(PKG_LIBXMA2API_FOUND AND PKG_LIBXRM_FOUND)
        message(STATUS "[OME] Xilinx XMA hardware acceleration: ENABLED")
        add_compile_definitions(HWACCELS_XMA_ENABLED)
    else()
        message(WARNING "[OME] OME_HWACCEL_XMA=ON but libxma2api/libxrm not found")
        set(OME_HWACCEL_XMA OFF)
    endif()
endif()

# Netint NiLogan
if(OME_HWACCEL_NILOGAN)
    find_library(XCODER_LOGAN_LIB xcoder_logan)
    if(XCODER_LOGAN_LIB)
        message(STATUS "[OME] Netint NiLogan hardware acceleration: ENABLED")
        add_compile_definitions(HWACCELS_NILOGAN_ENABLED)
    else()
        message(WARNING "[OME] OME_HWACCEL_NILOGAN=ON but libxcoder_logan.so not found")
        set(OME_HWACCEL_NILOGAN OFF)
    endif()
endif()

# jemalloc - required for Release builds, optional for Debug (can be forced with OME_ENABLE_JEMALLOC=ON)
# Note: when built with --enable-prof, jemalloc reports its pkg-config version as "<ver>_0"
# (e.g. "5.3.0_0"), so we use >= instead of = to avoid a false version mismatch.
if(OME_ENABLE_JEMALLOC OR (CMAKE_BUILD_TYPE STREQUAL "Release" AND NOT DEFINED OME_ENABLE_JEMALLOC))
    ome_find_pkg(PKG_JEMALLOC "jemalloc>=${OME_VER_JEMALLOC}" REINSTALL_TARGET jemalloc EXTRA_ARGS -DENABLE_JEMALLOC_PROF=${OME_USE_JEMALLOC_PROFILE})
    if(PKG_JEMALLOC_FOUND)
        message(STATUS "[OME] jemalloc: ENABLED")
        add_compile_definitions(OME_USE_JEMALLOC)

        # Profiling support - only meaningful when jemalloc is active
        if(OME_USE_JEMALLOC_PROFILE)
            add_compile_definitions(OME_USE_JEMALLOC_PROFILE)
            message(STATUS "[OME] jemalloc profiling: ENABLED")
        endif()
    endif()
else()
    if(OME_USE_JEMALLOC_PROFILE)
        message(FATAL_ERROR "[OME] OME_USE_JEMALLOC_PROFILE=ON requires OME_ENABLE_JEMALLOC=ON")
    endif()
endif()

# libx264 - auto-detected by checking libx264.so presence alongside libavcodec.so
# (mirrors the chk_dd_exist logic in main/AMS.mk; x264 is not directly linked -
#  FFmpeg's libavcodec uses it internally when compiled with --enable-libx264)
find_library(X264_LIB x264 HINTS ${OME_DEP_PREFIX}/lib)
if(X264_LIB)
    message(STATUS "[OME] libx264: found (${X264_LIB}) - enabling THIRDP_LIBX264_ENABLED")
    add_compile_definitions(THIRDP_LIBX264_ENABLED)
else()
    message(STATUS "[OME] libx264: not found - x264 encoder disabled")
endif()

# uuid (system library, not pkg-config)
find_library(UUID_LIB uuid REQUIRED)
