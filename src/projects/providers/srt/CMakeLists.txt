ome_add_static_library(srt_provider
    SOURCES_DIRS chunk
    DEPS
        base_provider
        mpegts_provider
        physical_port
        srt
        ovlibrary
)
