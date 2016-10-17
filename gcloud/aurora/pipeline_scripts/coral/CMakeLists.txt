configure_file(base_test.sh.in "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh" @ONLY)
configure_file(coral_run_pipelines.sh.in "${CMAKE_CURRENT_BINARY_DIR}/coral_run_pipelines.sh" @ONLY)

install_programs (/gcloud/aurora/pipeline_scripts/coral FILES "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh")
install_programs (/gcloud/aurora/pipeline_scripts/coral FILES "${CMAKE_CURRENT_BINARY_DIR}/coral_run_pipelines.sh")

