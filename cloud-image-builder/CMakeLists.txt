configure_file(build_primary_vm_snapshot.sh.in "${CMAKE_CURRENT_BINARY_DIR}/aurora_build_primary_vm_snapshot.sh" @ONLY)
install_programs (/ FILES ${CMAKE_CURRENT_BINARY_DIR}/aurora_build_primary_vm_snapshot.sh)

file(COPY vm_files DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

