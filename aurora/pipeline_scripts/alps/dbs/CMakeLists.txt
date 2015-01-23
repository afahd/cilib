configure_file(alps.smoke.db "${CMAKE_CURRENT_BINARY_DIR}/alps.smoke.db" @ONLY)

install_programs (/gcloud/aurora/pipeline_scripts/alps/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/alps.smoke.db")
