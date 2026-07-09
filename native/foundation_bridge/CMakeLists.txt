cmake_minimum_required(VERSION 3.25)

# Builds oep_foundation_bridge.dll: a thin Windows shared library that
# wraps OEP Foundation's Public C API (platform/api/oep_api.h) so Dart
# FFI has a dynamic library to open. Foundation's own build only
# produces oep_api as a static library (see
# oep_foundation/platform/api/CMakeLists.txt) — appropriate for a C++
# consumer like the CLI, but unusable by dart:ffi, which requires a
# DLL. This target does not modify, fork, or duplicate any Foundation
# source; it compiles the sibling repository's existing CMake modules
# unmodified and re-exports their linked symbols.
#
# Per Work Package 002's architecture rules, Studio's Dart code
# consumes only oep_api.h. This file is the (necessary) exception:
# CMake plumbing needs to know how to build Foundation's source to
# produce a linkable artifact, but no Foundation header beyond
# oep_api.h is exposed past this DLL boundary — the exported symbols
# are exactly, and only, the functions declared in oep_api.h.

# Overridable so CI or a different checkout layout isn't locked to the
# default sibling-directory assumption.
if(NOT DEFINED OEP_FOUNDATION_SOURCE_DIR)
  set(OEP_FOUNDATION_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../oep_foundation"
      CACHE PATH "Path to the oep_foundation repository checkout")
endif()

get_filename_component(OEP_FOUNDATION_SOURCE_DIR "${OEP_FOUNDATION_SOURCE_DIR}" ABSOLUTE)

if(NOT EXISTS "${OEP_FOUNDATION_SOURCE_DIR}/platform/api/include/oep/api/oep_api.h")
  message(FATAL_ERROR
    "oep_foundation not found at ${OEP_FOUNDATION_SOURCE_DIR}. "
    "Set OEP_FOUNDATION_SOURCE_DIR to the oep_foundation checkout, or "
    "place oep_studio and oep_foundation as sibling directories.")
endif()

# Foundation's own top-level CMakeLists.txt also adds platform/cli and
# tests/ (which pulls in a test framework). Studio needs none of
# that — only the modules oep_api actually depends on — so each
# module is added individually, in dependency order, exactly mirroring
# oep_foundation/CMakeLists.txt minus platform/cli and tests.
set(OEP_BRIDGE_FOUNDATION_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/foundation")
foreach(module IN ITEMS repository search validation packages exchange runtime api)
  add_subdirectory(
    "${OEP_FOUNDATION_SOURCE_DIR}/platform/${module}"
    "${OEP_BRIDGE_FOUNDATION_BINARY_DIR}/${module}"
    EXCLUDE_FROM_ALL
  )
endforeach()

# oep_api (and everything it links) is compiled as a static library.
# This target links it privately into a DLL. The exported symbol list
# comes from oep_foundation_bridge.def rather than
# WINDOWS_EXPORT_ALL_SYMBOLS: that CMake property only scans a
# target's own object files for exportable symbols, not ones pulled in
# transitively from a linked static library, so it produces an empty
# export table here (verified — see native/foundation_bridge's smoke
# test). A .def EXPORTS entry re-exports a symbol already present in
# the link regardless of which object file it came from, which is
# exactly what's needed to expose oep_api's functions.
add_library(oep_foundation_bridge SHARED
  src/bridge_stub.cpp
  oep_foundation_bridge.def
)

target_link_libraries(oep_foundation_bridge PRIVATE oep_api)
target_compile_features(oep_foundation_bridge PUBLIC cxx_std_23)
