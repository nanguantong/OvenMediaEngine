#
# src/projects/CMakeLists.txt
# Top-level of all OME libraries.
# Mirrors the role of projects/AMS.mk: sets global project flags and
# recurses into every sub-project.
#

# ==============================================================================
# Global project-level compile definitions
# ==============================================================================
add_compile_definitions(
    __STDC_CONSTANT_MACROS
    SPDLOG_COMPILED_LIB
)

# ==============================================================================
# External pkg-config modules pre-imported here so every sub-directory can
# reference them via PkgConfig::<VAR>.  The canonical variable names follow
# the pattern established in cmake/Dependencies.cmake.
# ==============================================================================
# (All pkg_check_modules calls live in cmake/Dependencies.cmake which is
#  included from the root CMakeLists.txt before this file is processed.)

# ==============================================================================
# Subdirectories (order follows the static library dependency graph)
# ==============================================================================

# --- Third-party bundled libraries (no OME dependencies) ---
add_subdirectory(third_party)

# --- Base libraries (leaf nodes) ---
add_subdirectory(base)

# --- Infrastructure modules ---
add_subdirectory(monitoring)
add_subdirectory(config)

# --- Networking / codec modules ---
add_subdirectory(modules)

# --- Orchestration and routing ---
add_subdirectory(orchestrator)
add_subdirectory(mediarouter)

# --- Transcoder ---
add_subdirectory(transcoder)

# --- Input providers ---
add_subdirectory(providers)

# --- Output publishers ---
add_subdirectory(publishers)

# --- Management APIs ---
add_subdirectory(api_server)
add_subdirectory(web_console)

# --- Main executable (links everything together) ---
add_subdirectory(main)
