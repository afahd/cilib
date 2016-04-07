configure_file(base_test.sh.in "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh" @ONLY)
configure_file(pgui_base_test.sh.in "${CMAKE_CURRENT_BINARY_DIR}/pgui_base_test.sh" @ONLY)
configure_file(alps_run_pipelines.sh.in "${CMAKE_CURRENT_BINARY_DIR}/alps_run_pipelines.sh" @ONLY)

install_files (/gcloud/aurora/pipeline_scripts/alps FILES "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh")
install_programs (/gcloud/aurora/pipeline_scripts/alps FILES "${CMAKE_CURRENT_BINARY_DIR}/alps_run_pipelines.sh")

add_subdirectory(dbs)
