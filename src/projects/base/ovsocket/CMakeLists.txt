# target: ovsocket
ome_add_static_library(ovsocket
    SOURCES_DIRS socket_pool
    DEPS
        ovcrypto
        ovlibrary
)
