file(COPY nirvana-master.db DESTINATION ${CMAKE_CURRENT_BINARY_DIR})
install_programs (/gcloud/aurora/pipeline_scripts/nirvana/dbs FILES "${CMAKE_CURRENT_SOURCE_DIR}/nirvana-master.db")
