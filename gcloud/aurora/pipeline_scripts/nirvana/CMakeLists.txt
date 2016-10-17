configure_file(base_test.sh.in "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh" @ONLY)
configure_file(nirvana_run_pipelines.sh.in "${CMAKE_CURRENT_BINARY_DIR}/nirvana_run_pipelines.sh" @ONLY)

install_programs (/gcloud/aurora/pipeline_scripts/nirvana FILES "${CMAKE_CURRENT_BINARY_DIR}/base_test.sh")
install_programs (/gcloud/aurora/pipeline_scripts/nirvana FILES "${CMAKE_CURRENT_BINARY_DIR}/nirvana_run_pipelines.sh")

add_subdirectory(dbs)
