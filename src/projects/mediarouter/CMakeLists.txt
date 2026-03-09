ome_add_static_library(mediarouter
    SOURCES_DIRS events
    DEPS
        transcoder
        base_info
        base_amf_event
        managed_queue
        config
        monitoring
        ovlibrary
)
