# OvenMediaEngine CMake Build System

> **Note**: OvenMediaEngine is currently migrating from the legacy `make` build system to CMake.
> The CMake build is under active development and may not yet cover all edge cases.
> The legacy `make` build (`src/Makefile`) remains available during the transition period.

---

## Quick Start

### Debug Build (default)

```bash
cmake -B build/debug -G Ninja -DOME_DEP_PREFIX=/opt/ovenmediaengine_getroot
cmake --build build/debug
```

> External libraries are automatically installed if missing or incorrect version —
> no need to run `InstallPrerequisites.cmake` manually before building.

### Release Build

```bash
cmake -B build/release -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/release
```

---

## Build Options

| Option | Default | Description |
|---|---|---|
| `CMAKE_BUILD_TYPE` | `Debug` | `Debug` / `Release` |
| `OME_USE_CLANG` | ON | Use Clang/Clang++ compiler. Set to OFF to use the system default (GCC) |
| `OME_DEP_PREFIX` | `/opt/ovenmediaengine` | Installation prefix for external dependencies |
| `OME_SANITIZE_THREAD` | OFF | Enable ThreadSanitizer (TSan). Debug builds only |
| `OME_SKIP_DEPENDENCY_CHECK` | OFF | Skip auto-install of missing/wrong-version packages. Useful for CI or offline builds |
| `OME_HWACCEL_NVIDIA` | OFF | Enable NVIDIA GPU acceleration. Enables `OME_BUILD_STUBS` automatically |
| `OME_HWACCEL_QSV` | OFF | Enable Intel QSV acceleration. Requires Intel driver (`libmfx`) installed separately |
| `OME_HWACCEL_XMA` | OFF | Enable Xilinx XMA acceleration. Enables `OME_BUILD_STUBS` automatically |
| `OME_HWACCEL_NILOGAN` | OFF | Enable Netint NiLogan acceleration. Requires `OME_NILOGAN_PATCH_PATH` |
| `OME_NILOGAN_PATCH_PATH` | `""` | Path to the NiLogan FFmpeg patch file. Required when `OME_HWACCEL_NILOGAN=ON` |
| `OME_NILOGAN_XCODER_COMPILE_PATH` | `""` | Path to `xcoder_logan` source directory to compile (optional) |
| `OME_ENABLE_JEMALLOC` | OFF/ON | Enable jemalloc allocator. Always ON in Release, OFF by default in Debug |
| `OME_BUILD_STUBS` | OFF | Build GPU stub `.so` libraries. Auto-enabled when NVIDIA or XMA is ON |

---

## Install

```bash
# Install to system (requires sudo)
sudo cmake --install build/release
```

| Path | Description |
|---|---|
| `/usr/share/ovenmediaengine/OvenMediaEngine` | Binary (symbols stripped for Release) |
| `/usr/bin/OvenMediaEngine` | Symlink |
| `/usr/share/ovenmediaengine/conf/` | Config files (not overwritten if already present) |
| `/lib/systemd/system/ovenmediaengine.service` | systemd service |

```bash
sudo systemctl daemon-reload
sudo systemctl enable ovenmediaengine
sudo systemctl start ovenmediaengine
```

---

## Prerequisites Manual Install

Normally not needed — the configure step handles this automatically.

```bash
# Install all
cmake -P cmake/InstallPrerequisites.cmake

# Install a specific library only
cmake -DTARGET=<name> -P cmake/InstallPrerequisites.cmake
```

Available targets:

```
nasm        openssl     libsrtp     libsrt      libopus     libopenh264
libvpx      libwebp     fdk_aac     libx264     ffmpeg      stubs
jemalloc    libpcre2    hiredis     spdlog      whisper     nvcc_hdr
```

Available `-D` options:

| Option | Default | Description |
|---|---|---|
| `PREFIX` | `/opt/ovenmediaengine` | Installation prefix |
| `TARGET` | *(all)* | Install a single target only (e.g. `ffmpeg`, `openssl`) |
| `ENABLE_X264` | `ON` | Include libx264 |
| `ENABLE_NVIDIA` | `OFF` | Include NVIDIA codec headers, build FFmpeg with CUDA/NVENC/NVDEC |
| `ENABLE_QSV` | `OFF` | Build FFmpeg with Intel QSV support (`libmfx` must be pre-installed) |
| `ENABLE_XMA` | `OFF` | Build FFmpeg with Xilinx XMA support (Xilinx XRT must be pre-installed) |
| `ENABLE_NILOGAN` | `OFF` | Build FFmpeg with Netint NiLogan support. Requires `NILOGAN_PATCH_PATH` |
| `NILOGAN_PATCH_PATH` | `""` | Path to the NiLogan FFmpeg patch file |
| `NILOGAN_XCODER_COMPILE_PATH` | `""` | Path to `xcoder_logan` source directory to compile (optional) |
| `OME_USE_CLANG` | `ON` | Install `clang`/`lld` OS packages and use Clang as the compiler. Set `OFF` to skip and keep GCC |

---

## Library Version Management

All external library versions are defined in [`cmake/Versions.cmake`](Versions.cmake).
To upgrade a dependency, update the version there and re-run `cmake -B ...` —
only the changed package will be reinstalled automatically.
