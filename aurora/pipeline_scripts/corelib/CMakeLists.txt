configure_file(base_test.sh.in "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh" @ONLY)
configure_file(corelib_run_pipelines.sh.in "${CMAKE_CURRENT_BINARY_DIR}/corelib_run_pipelines.sh" @ONLY)

install_files (/gcloud/aurora/pipeline_scripts/corelib FILES "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh")
install_programs (/gcloud/aurora/pipeline_scripts/corelib FILES "${CMAKE_CURRENT_BINARY_DIR}/corelib_run_pipelines.sh")

add_subdirectory(dbs)
