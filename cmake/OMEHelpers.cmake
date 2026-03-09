#
# OMEHelpers.cmake
# Helper macros and functions for building OvenMediaEngine static libraries.
#

include(CMakeParseArguments)

# ------------------------------------------------------------------------------
# ome_add_static_library(target_name
#     [SOURCES_DIRS  dir1 dir2 ...]   - non-recursive glob in subdirs
#     [SOURCES_DIRS_R dir1 dir2 ...]  - recursive glob in subdirs
#     [EXCLUDE  pat1 pat2 ...]        - filename patterns to exclude from globbed
#                                       sources (e.g. "*_test.cpp" "test_*.cpp")
#                                       Useful to keep unit-test files out of the
#                                       production library while living in the
#                                       same directory.
#     [DEPS  dep1 dep2 ...]           - Declared link dependencies (OME targets,
#                                       imported targets, or plain lib names).
#                                       NOTE: OvenMediaEngine is a monolithic binary
#                                       linked via $<LINK_GROUP:RESCAN,...>, so all
#                                       OME static libs are always linked regardless
#                                       of what is listed here.  DEPS does NOT
#                                       enforce actual linkage — it serves as
#                                       documentation of intentional dependencies
#                                       and provides CMake build-order hints.
#     [PUBLIC_DEPS dep1 dep2 ...]     - Same as DEPS but propagates to consumers
#                                       via target_link_libraries PUBLIC scope.
# )
#
# Globs all *.cpp / *.c from CMAKE_CURRENT_SOURCE_DIR (non-recursive) plus any
# listed subdirectories, applies EXCLUDE filters, creates a STATIC library,
# and wires up global includes, compile options, and link dependencies.
# ------------------------------------------------------------------------------
function(ome_add_static_library target_name)
    cmake_parse_arguments(ARG
        ""
        ""
        "SOURCES_DIRS;SOURCES_DIRS_R;EXCLUDE;DEPS;PUBLIC_DEPS"
        ${ARGN}
    )

    # ── Source collection ─────────────────────────────────────────────────────

    # Root directory (non-recursive)
    file(GLOB SELF_SRCS
        "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/*.c"
    )
    set(SRCS ${SELF_SRCS})

    # Named subdirectories - non-recursive glob
    foreach(dir ${ARG_SOURCES_DIRS})
        file(GLOB dir_srcs
            "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.cpp"
            "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.c"
        )
        list(APPEND SRCS ${dir_srcs})
    endforeach()

    # Named subdirectories - recursive glob
    foreach(dir ${ARG_SOURCES_DIRS_R})
        file(GLOB_RECURSE dir_srcs
            "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.cpp"
            "${CMAKE_CURRENT_SOURCE_DIR}/${dir}/*.c"
        )
        list(APPEND SRCS ${dir_srcs})
    endforeach()

    # ── Exclusion filter ──────────────────────────────────────────────────────
    # Convert each glob-style pattern (filename only) to a regex and remove
    # matching files from the list.  Patterns are matched against the filename
    # component only (not the full path), so "test_*.cpp" or "*_test.cpp" work
    # as expected without needing to know the full path.
    foreach(pat ${ARG_EXCLUDE})
        # Escape regex metacharacters, then turn glob wildcards into .*
        string(REGEX REPLACE "([][+.^${}()|\\\\])" "\\\\\\1" pat_re "${pat}")
        string(REPLACE "*" ".*" pat_re "${pat_re}")
        string(REPLACE "?" "." pat_re "${pat_re}")
        # Match against the filename part only
        list(FILTER SRCS EXCLUDE REGEX "/${pat_re}$")
    endforeach()

    # ── Library creation ──────────────────────────────────────────────────────

    if(NOT SRCS)
        message(STATUS "[OME] No source files found for '${target_name}' in ${CMAKE_CURRENT_SOURCE_DIR} - creating INTERFACE library")
        add_library(${target_name} INTERFACE)
        target_include_directories(${target_name} INTERFACE
            ${OME_GLOBAL_INCLUDE_DIRS}
        )
        set_target_properties(${target_name} PROPERTIES OME_HEADER_ONLY TRUE)
        # Link INTERFACE deps (PUBLIC_DEPS propagate; DEPS become INTERFACE here)
        if(ARG_DEPS OR ARG_PUBLIC_DEPS)
            target_link_libraries(${target_name} INTERFACE
                ${ARG_DEPS} ${ARG_PUBLIC_DEPS}
            )
        endif()
        return()
    endif()

    add_library(${target_name} STATIC ${SRCS})

    target_include_directories(${target_name} PUBLIC
        ${OME_GLOBAL_INCLUDE_DIRS}
    )

    target_compile_options(${target_name} PRIVATE
        ${OME_GLOBAL_CFLAGS}
    )

    target_compile_features(${target_name} PUBLIC cxx_std_17)

    # ── Link dependencies ─────────────────────────────────────────────────────
    if(ARG_DEPS)
        target_link_libraries(${target_name} PRIVATE ${ARG_DEPS})
    endif()
    if(ARG_PUBLIC_DEPS)
        target_link_libraries(${target_name} PUBLIC ${ARG_PUBLIC_DEPS})
    endif()

    # Auto-register so main collects all OME static libs automatically.
    set_property(GLOBAL APPEND PROPERTY OME_STATIC_LIBS ${target_name})
endfunction()


# ------------------------------------------------------------------------------
# ome_target_pkg_config(target scope pkg1 pkg2 ...)
# Links pkg-config modules to a target.
# scope: PRIVATE | PUBLIC | INTERFACE
# Handles INTERFACE (header-only) targets transparently.
# ------------------------------------------------------------------------------
function(ome_target_pkg_config target scope)
    # Determine effective scope for INTERFACE libraries
    get_target_property(_is_iface ${target} OME_HEADER_ONLY)
    if(_is_iface)
        set(scope INTERFACE)
    endif()

    foreach(pkg ${ARGN})
        string(MAKE_C_IDENTIFIER "${pkg}" pkg_id)
        string(TOUPPER "${pkg_id}" pkg_var)
        set(var "PKG_${pkg_var}")

        if(NOT TARGET PkgConfig::${var})
            pkg_check_modules(${var} REQUIRED IMPORTED_TARGET ${pkg})
        endif()

        target_link_libraries(${target} ${scope} PkgConfig::${var})
    endforeach()
endfunction()
