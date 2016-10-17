configure_file(update_db.sh.in "${CMAKE_CURRENT_BINARY_DIR}/update_db.sh" @ONLY)

install_programs (/gcloud/utilities FILES ${CMAKE_CURRENT_BINARY_DIR}/update_db.sh)
