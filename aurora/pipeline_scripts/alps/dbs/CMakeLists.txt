file(COPY alps.smoke.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
file(COPY alps.extended.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
file(COPY alps.unstable.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

install_programs (/gcloud/aurora/pipeline_scripts/alps/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/alps.smoke.db")
install_programs (/gcloud/aurora/pipeline_scripts/alps/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/alps.extended.db")
install_programs (/gcloud/aurora/pipeline_scripts/alps/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/alps.unstable.db")
