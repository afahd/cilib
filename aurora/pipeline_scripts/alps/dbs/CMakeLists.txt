file(COPY alps.smoke.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

install_programs (/gcloud/aurora/pipeline_scripts/alps/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/alps.smoke.db")
