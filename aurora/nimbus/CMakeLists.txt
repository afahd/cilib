configure_file(nimbus.in "${CMAKE_CURRENT_BINARY_DIR}/nimbus" @ONLY)
configure_file(nimbus_remote_conf.in "${CMAKE_CURRENT_BINARY_DIR}/nimbus_remote_conf" @ONLY)
INSTALL_PROGRAMS(/ FILES nimbus_remote_conf)
INSTALL_PROGRAMS(/ FILES nimbus)
