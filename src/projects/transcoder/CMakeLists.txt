ome_add_static_library(transcoder
    SOURCES_DIRS
        codec
        codec/decoder
        codec/encoder
        filter
    DEPS
        bitstream
        ffmpeg_wrapper
        monitoring
        config
        ovlibrary
)

