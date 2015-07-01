configure_file(test_aurora_build.sh.in "${CMAKE_CURRENT_BINARY_DIR}/test_aurora_build.sh" @ONLY)
configure_file(test_aurora_run.sh.in "${CMAKE_CURRENT_BINARY_DIR}/test_aurora_run.sh" @ONLY)
configure_file(test_aurora_debugtest.sh.in "${CMAKE_CURRENT_BINARY_DIR}/test_aurora_debugtest.sh" @ONLY)
configure_file(test_aurora_pipeline.sh.in "${CMAKE_CURRENT_BINARY_DIR}/test_aurora_pipeline.sh" @ONLY)

add_test(NAME test_aurora_build COMMAND ${CMAKE_CURRENT_BINARY_DIR}/test_aurora_build.sh)
add_test(NAME test_aurora_run COMMAND ${CMAKE_CURRENT_BINARY_DIR}/test_aurora_run.sh)
add_test(NAME test_aurora_debugtest COMMAND ${CMAKE_CURRENT_BINARY_DIR}/test_aurora_debugtest.sh BridgeTest01)
add_test(NAME test_aurora_pipeline COMMAND ${CMAKE_CURRENT_BINARY_DIR}/test_aurora_pipeline.sh smoke)
