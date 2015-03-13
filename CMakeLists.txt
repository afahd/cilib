cmake_minimum_required (VERSION 2.6)
project (gcloud NONE)
# The version number.
set (Tutorial_VERSION_MAJOR 1)
set (Tutorial_VERSION_MINOR 0)
set (CMAKE_INSTALL_PREFIX "/opt/pg/scripts")

add_subdirectory(aurora)
add_subdirectory(cloud-image-builder)
