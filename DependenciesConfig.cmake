set(DEPENDENCIES_IGNORE "${CMAKE_C_COMPILER}")
set(DEPENDENCIES_IGNORE "${CMAKE_C_COMPILER}")


set_property(GLOBAL PROPERTY source_list_property "${source_list}")


if ("${CONNECT_ALL_DEPENDENCIES}" STREQUAL "")
    set(CONNECT_ALL_DEPENDENCIES "FALSE" CACHE STRING "Leave all dependencies connected to their repositories")
endif()


if ("${BUILD_AS_DEPENDENCY}" STREQUAL "")
    set(BUILD_AS_DEPENDENCY "FALSE" CACHE STRING "Build this project as a dependency")
endif()


if (NOT "${DEPENDENCIES_FOLDER}" STREQUAL "")
    set(DEPENDENCIES_FOLDER "${DEPENDENCIES_FOLDER}" CACHE STRING "Dependencies folder")
else()
    set(DEPENDENCIES_FOLDER "${CMAKE_CURRENT_SOURCE_DIR}/git-dependencies" CACHE STRING "Dependencies folder")
endif()

make_directory(${DEPENDENCIES_FOLDER})

if (NOT EXISTS ${DEPENDENCIES_FOLDER}/CMakeLists.txt)
    file(DOWNLOAD https://raw.githubusercontent.com/germanespinosa/dependencies/main/cmake-dependencies.cmake ${DEPENDENCIES_FOLDER}/CMakeLists.txt)
endif()

set(DEPENDENCIES_DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/git-dependencies")
make_directory(${DEPENDENCIES_DESTINATION})
#${CMAKE_COMMAND}
set(DEPENDENCY_CMAKE "${CMAKE_COMMAND} '-DBUILD_AS_DEPENDENCY=TRUE' '-DDEPENDENCIES_FOLDER=${DEPENDENCIES_FOLDER}' --no-warn-unused-cli -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} '-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}' -Wno-dev -DCATCH_TESTS=DISABLED -DCONNECT_ALL_DEPENDENCIES=${CONNECT_ALL_DEPENDENCIES} ${DEPENDENCIES_FOLDER}")

if(EXISTS "${DEPENDENCY_TARGETS_FOLDER}/dependency-imported_targets.txt")
    FILE(REMOVE "${DEPENDENCY_TARGETS_FOLDER}/dependency-imported_targets.txt")
endif()

set(ADDITIONAL_CLEAN_FILES "")
list(APPEND ADDITIONAL_CLEAN_FILES ${DEPENDENCIES_FOLDER})
set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${ADDITIONAL_CLEAN_FILES}")

macro (get_git_dependency_folder DEPENDENCY_REPOSITORY DEPENDENCY_FOLDER_NAME)
    cmake_parse_arguments(DEPENDENCY "" "BRANCH;TAG" "" ${ARGN} )
    get_filename_component(DEPENDENCY_REPOSITORY_NAME ${DEPENDENCY_REPOSITORY} NAME)

    if(NOT "${DEPENDENCY_BRANCH}${DEPENDENCY_TAG}" STREQUAL "")
        STRING(REGEX REPLACE "[^a-zA-Z0-9]" "_" DEPENDENCY_BRANCH_FOLDER "${DEPENDENCY_BRANCH}")
        STRING(REGEX REPLACE "[^a-zA-Z0-9]" "_" DEPENDENCY_TAG_FOLDER "${DEPENDENCY_TAG}")
        set(${DEPENDENCY_FOLDER_NAME} "${DEPENDENCY_REPOSITORY_NAME}_${DEPENDENCY_BRANCH_FOLDER}${DEPENDENCY_TAG_FOLDER}")
    else()
        set(${DEPENDENCY_FOLDER_NAME} "${DEPENDENCY_REPOSITORY_NAME}")
    endif()
endmacro()

macro (update_git_dependency DEPENDENCY_REPOSITORY DEPENDENCY_FOLDER_NAME DEPENDENCY_HAS_UPDATES)
    cmake_parse_arguments(DEPENDENCY "AUTO_UPDATE;CONNECTED;VERBOSE" "BRANCH;TAG" "" ${ARGN} )

    if("${DEPENDENCY_BRANCH}" STREQUAL "")
        set(DEPENDENCY_HAS_BRANCH FALSE)
    else()
        set(DEPENDENCY_HAS_BRANCH TRUE)
    endif()

    if("${DEPENDENCY_TAG}" STREQUAL "")
        set(DEPENDENCY_HAS_TAG FALSE)
    else()
        set(DEPENDENCY_HAS_TAG TRUE)
    endif()

    if (${DEPENDENCY_HAS_TAG} AND ${DEPENDENCY_HAS_BRANCH})
        message(FATAL_ERROR "BRANCH and TAG cannot be uses simultaneously" )
    endif()

    set(${DEPENDENCY_HAS_UPDATES} FALSE)

    get_git_dependency_folder(${DEPENDENCY_REPOSITORY} UPDATE_DEPENDENCY_FOLDER_NAME ${ARGN})

    set(${DEPENDENCY_FOLDER_NAME} ${UPDATE_DEPENDENCY_FOLDER_NAME})

    set(DEPENDENCY_FOLDER "${DEPENDENCIES_FOLDER}/${UPDATE_DEPENDENCY_FOLDER_NAME}")

    #locks the dependency for concurrent cmakes running
    set(DEPENDENCY_LOCK "${DEPENDENCIES_FOLDER}/${DEPENDENCY_REPOSITORY_NAME}.lock")
    file(LOCK ${DEPENDENCY_LOCK})

    # if folder doesn't exists does the cloning
    if (NOT EXISTS "${DEPENDENCY_FOLDER}")
        if (${DEPENDENCY_HAS_BRANCH} OR ${DEPENDENCY_HAS_TAG})
            execute_process(COMMAND git clone --branch "${DEPENDENCY_BRANCH}${DEPENDENCY_TAG}" ${DEPENDENCY_REPOSITORY} ${DEPENDENCY_FOLDER}
                    WORKING_DIRECTORY ${DEPENDENCIES_FOLDER})
        else()
            execute_process(COMMAND git clone ${DEPENDENCY_REPOSITORY} ${DEPENDENCY_FOLDER}
                    WORKING_DIRECTORY ${DEPENDENCIES_FOLDER})
        endif()
        set(${DEPENDENCY_HAS_UPDATES} TRUE)
        #if it is a disconnected dependency, remove git link
        if (NOT ${DEPENDENCY_CONNECTED})
            file(REMOVE_RECURSE ${DEPENDENCY_FOLDER}/.git)
            file(REMOVE ${DEPENDENCY_FOLDER}/.gitmodules)
        endif()
    endif()

    #if it is a connected dependency and auto-update is set, check for changes
    if (${DEPENDENCY_CONNECTED})
        if (${DEPENDENCY_AUTO_UPDATE})
            execute_process(COMMAND git pull
                    WORKING_DIRECTORY ${DEPENDENCY_FOLDER}
                    OUTPUT_VARIABLE DEPENDENCY_PULL_OUTPUT
                    ERROR_QUIET)

            if ( NOT "${DEPENDENCY_PULL_OUTPUT}" MATCHES "Already up to date.")
                set(${DEPENDENCY_HAS_UPDATES} TRUE)
            endif()
        endif()
    endif()
    file(LOCK ${DEPENDENCY_LOCK} RELEASE)
    file(REMOVE ${DEPENDENCY_LOCK})
endmacro()

macro (install_git_dependency DEPENDENCY_NAME DEPENDENCY_REPOSITORY)
    cmake_parse_arguments(${DEPENDENCY_NAME}
            "AUTO_UPDATE;CONNECTED;NO_BUILD;VERBOSE;ADD_SUBDIRECTORY;DOWNLOAD_ONLY;CMAKE_PROJECT;PUBLIC;PRIVATE"
            "BRANCH;TAG;TARGET"
            "PACKAGES;CMAKE_OPTIONS;IMPORT_TARGETS;INCLUDE_DIRECTORIES"
            ${ARGN} )

    set(${DEPENDENCY_NAME}_INCLUDE_SCOPE "PRIVATE")
    if (${${DEPENDENCY_NAME}_PUBLIC})
        set(${DEPENDENCY_NAME}_INCLUDE_SCOPE "PUBLIC")
    endif()

    if (${CONNECT_ALL_DEPENDENCIES})
        set(${DEPENDENCY_NAME}_CONNECTED "TRUE")
    endif()

    update_git_dependency(${DEPENDENCY_REPOSITORY} ${DEPENDENCY_NAME}_FOLDER_NAME ${DEPENDENCY_NAME}_HAS_UPDATES ${ARGN} )

    set(${DEPENDENCY_NAME}_FOLDER "${DEPENDENCIES_FOLDER}/${${DEPENDENCY_NAME}_FOLDER_NAME}" )
    set(${DEPENDENCY_NAME}_DESTINATION "${DEPENDENCIES_DESTINATION}/${${DEPENDENCY_NAME}_FOLDER_NAME}")

    if (${${DEPENDENCY_NAME}_ADD_SUBDIRECTORY})
        make_directory("${${DEPENDENCY_NAME}_DESTINATION}")
        add_subdirectory(${${DEPENDENCY_NAME}_FOLDER} ${${DEPENDENCY_NAME}_DESTINATION})
    elseif(${${DEPENDENCY_NAME}_CMAKE_PROJECT})
        make_directory("${${DEPENDENCY_NAME}_DESTINATION}")
        set(${DEPENDENCY_NAME}_CMAKE_COMMAND "${${DEPENDENCY_NAME}_CMAKE} '-DDEPENDENCY=${${DEPENDENCY_NAME}_FOLDER_NAME}'")

        execute_process(COMMAND bash -c "${DEPENDENCY_CMAKE} '-DDEPENDENCY=${${DEPENDENCY_NAME}_FOLDER_NAME}'"
                WORKING_DIRECTORY ${${DEPENDENCY_NAME}_DESTINATION}
                RESULT_VARIABLE ${DEPENDENCY_NAME}_CMAKE_RESULT )

        if (NOT ${${DEPENDENCY_NAME}_CMAKE_RESULT} EQUAL "0")
            message(FATAL_ERROR "failed to load dependency cmake file" )
        endif()

        if (NOT ${${DEPENDENCY_NAME}_NO_BUILD}) # AND ${${DEPENDENCY_NAME}_HAS_UPDATES}
            execute_process(COMMAND make -j
                    WORKING_DIRECTORY ${${DEPENDENCY_NAME}_DESTINATION}
                    RESULT_VARIABLE ${DEPENDENCY_NAME}_MAKE_RESULT)
            if (NOT ${${DEPENDENCY_NAME}_MAKE_RESULT} EQUAL "0")
                message(FATAL_ERROR "failed to build dependency cmake file" )
            endif()
        endif()

        file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency-include_directories.txt" ${DEPENDENCY_NAME}_GENERATED_INCLUDE_DIRECTORIES)

        if(NOT "${${DEPENDENCY_NAME}_GENERATED_INCLUDE_DIRECTORIES}" STREQUAL "")
            if("${${DEPENDENCY_NAME}_TARGET}" STREQUAL "")
                include_directories(${${DEPENDENCY_NAME}_GENERATED_INCLUDE_DIRECTORIES})
            else()
                target_include_directories(${${DEPENDENCY_NAME}_TARGET} ${${DEPENDENCY_NAME}_INCLUDE_SCOPE} ${${DEPENDENCY_NAME}_GENERATED_INCLUDE_DIRECTORIES})
            endif()
        endif()

        if("${${DEPENDENCY_NAME}_IMPORT_TARGETS}" STREQUAL "")
            file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency-targets.txt" ${DEPENDENCY_NAME}_IMPORT_TARGETS)
        endif()

        foreach(${DEPENDENCY_NAME}_IMPORTED_TARGET ${${DEPENDENCY_NAME}_IMPORT_TARGETS})
            get_directory_property(hasParent PARENT_DIRECTORY)
            file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-bin.txt" ${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_BIN)
            add_library(${${DEPENDENCY_NAME}_IMPORTED_TARGET} STATIC IMPORTED)
            file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-include_directories.txt" ${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_INCLUDE_DIRECTORIES)

            set_target_properties(${${DEPENDENCY_NAME}_IMPORTED_TARGET} PROPERTIES
                    IMPORTED_LINK_INTERFACE_LANGUAGES_DEBUG "CXX"
                    IMPORTED_LOCATION "${${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_BIN}"
                    )

            if(NOT "${${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_INCLUDE_DIRECTORIES}" STREQUAL "")
                set_target_properties(${${DEPENDENCY_NAME}_IMPORTED_TARGET} PROPERTIES
                        INTERFACE_INCLUDE_DIRECTORIES "${${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_INCLUDE_DIRECTORIES}"
                )
            endif()

            file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-path.txt" ${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_PATH)
            target_link_directories(${${DEPENDENCY_NAME}_IMPORTED_TARGET} INTERFACE ${${${DEPENDENCY_NAME}_IMPORTED_TARGET}_IMPORTED_TARGET_PATH})
            if (EXISTS "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-link_libraries.txt")
                file(READ "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-link_libraries.txt" ${${${DEPENDENCY_NAME}_IMPORTED_TARGET}}_LINKED_LIBRARIES)
                target_link_libraries(${${DEPENDENCY_NAME}_IMPORTED_TARGET} INTERFACE ${${${${DEPENDENCY_NAME}_IMPORTED_TARGET}}_LINKED_LIBRARIES})
            endif()
            if(NOT "${${DEPENDENCY_NAME}_TARGET}" STREQUAL "")
                target_link_libraries(${${DEPENDENCY_NAME}_TARGET} ${${DEPENDENCY_NAME}_INCLUDE_SCOPE} ${${DEPENDENCY_NAME}_IMPORTED_TARGET})
            endif()

            if(${BUILD_AS_DEPENDENCY})
                if(EXISTS "${DEPENDENCY_TARGETS_FOLDER}/dependency-imported_targets.txt")
                    file(READ "${DEPENDENCY_TARGETS_FOLDER}/dependency-imported_targets.txt" DEPENDENCY_IMPORTED_TARGETS)
                    LIST(APPEND DEPENDENCY_IMPORTED_TARGETS ${${DEPENDENCY_NAME}_IMPORTED_TARGET})
                else()
                    set(DEPENDENCY_IMPORTED_TARGETS "${${DEPENDENCY_NAME}_IMPORTED_TARGET}")
                endif()
                file(WRITE "${DEPENDENCY_TARGETS_FOLDER}/dependency-imported_targets.txt" "${DEPENDENCY_IMPORTED_TARGETS}")
                file(COPY
                        "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-path.txt"
                        "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-bin.txt"
                        "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-include_directories.txt"
                        DESTINATION "${DEPENDENCY_TARGETS_FOLDER}")
                if (EXISTS "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-link_libraries.txt")
                    file(COPY
                            "${${DEPENDENCY_NAME}_DESTINATION}/dependency_${${DEPENDENCY_NAME}_IMPORTED_TARGET}-link_libraries.txt"
                            DESTINATION "${DEPENDENCY_TARGETS_FOLDER}")
                endif()
            endif()
        endforeach()

        if(NOT "${${DEPENDENCY_NAME}_PACKAGES}" STREQUAL "")
            foreach(${DEPENDENCY_NAME}_PACKAGE ${${DEPENDENCY_NAME}_PACKAGES})
                set(${${DEPENDENCY_NAME}_PACKAGE}_DIR ${${DEPENDENCY_NAME}_DESTINATION}/${${DEPENDENCY_NAME}_FOLDER_NAME})
                find_package(${${DEPENDENCY_NAME}_PACKAGE})
            endforeach()
        endif()

    endif()

    if("${${DEPENDENCY_NAME}_INCLUDE_DIRECTORIES}" STREQUAL "")
        set(${DEPENDENCY_NAME}_HAS_INCLUDE_DIRECTORIES FALSE)
    else()
        set(${DEPENDENCY_NAME}_HAS_INCLUDE_DIRECTORIES TRUE)
    endif()

    if(${${DEPENDENCY_NAME}_HAS_INCLUDE_DIRECTORIES})
        foreach(${DEPENDENCY_NAME}_INCLUDE_DIRECTORY ${${DEPENDENCY_NAME}_INCLUDE_DIRECTORIES})
            include_directories(${${DEPENDENCY_NAME}_FOLDER}/${${DEPENDENCY_NAME}_INCLUDE_DIRECTORY})
        endforeach()
    endif()
endmacro()
