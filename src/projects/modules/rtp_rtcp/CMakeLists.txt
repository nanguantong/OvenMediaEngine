ome_add_static_library(rtp_rtcp
    SOURCES_DIRS rtcp_info
    DEPS
        bitstream
        rtsp_module
        ovlibrary
)
