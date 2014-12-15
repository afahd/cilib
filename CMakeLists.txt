cmake_minimum_required (VERSION 2.6)
project (gcloud)
# The version number.
set (Tutorial_VERSION_MAJOR 1)
set (Tutorial_VERSION_MINOR 0)

install (DIRECTORY
         ${PROJECT_BINARY_DIR}/aurora/
         DESTINATION /opt/pg/scripts
         USE_SOURCE_PERMISSIONS)
add_subdirectory(aurora)
