configure_file(aurora_cost.sh.in "${CMAKE_CURRENT_BINARY_DIR}/aurora_cost.sh" @ONLY)
configure_file(cost_utils.sh.in "${CMAKE_CURRENT_BINARY_DIR}/cost_utils.sh" @ONLY)

install_programs (/gcloud/aurora/cost_calculation FILES ${CMAKE_CURRENT_BINARY_DIR}/aurora_cost.sh)
install_programs (/gcloud/aurora/cost_calculation FILES ${CMAKE_CURRENT_BINARY_DIR}/cost_utils.sh)