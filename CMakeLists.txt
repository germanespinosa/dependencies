cmake_minimum_required(VERSION 3.10)

project(module
        VERSION 2019.1.0
        DESCRIPTION "Compact test framework"
        LANGUAGES CXX)

include(GNUInstallDirs)

install(FILES
        DependenciesConfig.cmake
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/Dependencies)

function(get_directory_full_path dir_rel_path dir_full_path)
    execute_process(COMMAND bash -c "cd ${dir_rel_path}; pwd"
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            OUTPUT_VARIABLE full_path
            ERROR_QUIET)
    string(STRIP "${full_path}" full_path)
    set(${dir_full_path} "${full_path}" PARENT_SCOPE)
endfunction()

get_directory_full_path(DEBIAN f)

message("-${f}-")