# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(rive_native_library VERSION 0.0.1 LANGUAGES C)

find_program(DART_EXECUTABLE dart REQUIRED) 
if(NOT DART_EXECUTABLE)
  message(FATAL_ERROR "rive_native: Dart SDK not found. Please install Dart and ensure it is in your PATH.")
endif()

# Set platform-specific variables
# AAR plugins are built in the .android/plugins_build_output/rive_native directory
# APK builds are in the build/rive_native directory
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
  message(STATUS "rive_native: CMake is running on Windows.")
  set(KEY_APK "\\build\\rive_native")
  set(KEY_AAR "\\.android\\plugins_build_output\\rive_native")
  set(SETUP_COMMAND cmd.exe /C "${DART_EXECUTABLE} run rive_native:setup --verbose -p android")
else()
  message(STATUS "rive_native: CMake is running on a non-Windows host.")
  set(KEY_APK "/build/rive_native")
  set(KEY_AAR "/.android/plugins_build_output/rive_native")
  set(SETUP_COMMAND ${CMAKE_COMMAND} -E env "dart" "run" "rive_native:setup" "--verbose" "-p" "android")
endif()

# Infer app root directory
set(PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
set(INFERRED_APP_DIR "")
string(FIND "${PATH}" "${KEY_AAR}" PLUGIN_INDEX)
string(FIND "${PATH}" "${KEY_APK}" INDEX)
if(PLUGIN_INDEX GREATER -1)
  string(SUBSTRING "${PATH}" 0 ${PLUGIN_INDEX} INFERRED_APP_DIR)
  message(STATUS "rive_native: Detected '${KEY_AAR}'. Inferred app root: ${INFERRED_APP_DIR}")
elseif(INDEX GREATER -1)
  string(SUBSTRING "${PATH}" 0 ${INDEX} INFERRED_APP_DIR)
  message(STATUS "rive_native: Inferred app root: ${INFERRED_APP_DIR}")
else()
  message(FATAL_ERROR "rive_native: Could not infer app root — '${KEY_APK}' or '${KEY_AAR}' not found in: ${PATH}")
endif()

# Run rive_native setup command
execute_process(
  COMMAND ${SETUP_COMMAND}
  WORKING_DIRECTORY "${INFERRED_APP_DIR}"
  RESULT_VARIABLE result
  OUTPUT_VARIABLE output
  ERROR_VARIABLE error
  OUTPUT_STRIP_TRAILING_WHITESPACE
  ERROR_STRIP_TRAILING_WHITESPACE
)

message(STATUS "rive_native setup output: ${output}")
if(NOT "${error}" STREQUAL "")
  message(WARNING "rive_native setup error: ${error}")
endif()

if(NOT result EQUAL 0)
  message(FATAL_ERROR "rive_native: Failed to run setup command. Exit code: ${result}")
endif()

# add_library(rive_native SHARED
#   "rive_native.c"
# )

# set_target_properties(rive_native PROPERTIES
#   PUBLIC_HEADER rive_native.h
#   OUTPUT_NAME "rive_native"
# )

# target_compile_definitions(rive_native PUBLIC DART_SHARED_LIB)
