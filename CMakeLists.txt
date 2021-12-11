cmake_minimum_required(VERSION 3.10)

project(dependencies
        VERSION 2019.1.0
        DESCRIPTION "Compact test framework"
        LANGUAGES CXX)

include(GNUInstallDirs)

install(FILES
        DependenciesConfig.cmake
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/Dependencies)

