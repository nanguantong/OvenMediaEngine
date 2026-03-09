ome_add_static_library(bitstream
    SOURCES_DIRS
        aac
        opus
        vp8
        nalu
        h264
        h265
        mp3
    DEPS ovlibrary
)
