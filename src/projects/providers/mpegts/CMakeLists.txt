ome_add_static_library(mpegts_provider
    SOURCES_DIRS chunk
    DEPS
        base_provider
        bitstream
        mpegts_container
        physical_port
        base_scte35_event
        orchestrator
        ovlibrary
)
