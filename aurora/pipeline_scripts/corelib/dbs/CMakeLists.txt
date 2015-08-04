file(COPY corelib-smoke-master.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

install_programs (/gcloud/aurora/pipeline_scripts/corelib/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/corelib-smoke-master.db")

