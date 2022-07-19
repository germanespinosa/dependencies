make_directory (${CMAKE_CURRENT_BINARY_DIR}/dependency_include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/dependency_include)

if (NOT $ENV{DEPENDENCIES_FOLDER} EQUAL "")
    set(dependencies_folder "$ENV{DEPENDENCIES_FOLDER}" CACHE PATH "")
    message ("dependency folder parameter: $ENV{DEPENDENCIES_FOLDER}")
else()
    set(dependencies_folder "${CMAKE_CURRENT_SOURCE_DIR}/dependencies" CACHE PATH "")
endif()

make_directory(${dependencies_folder})

include_directories(${dependencies_folder})

set(ADDITIONAL_CLEAN_FILES "")
list(APPEND ADDITIONAL_CLEAN_FILES ${CMAKE_CURRENT_BINARY_DIR}/dependency_include)
list(APPEND ADDITIONAL_CLEAN_FILES ${dependencies_folder})
set_directory_properties(PROPERTIES ADDITIONAL_MAKE_CLEAN_FILES "${ADDITIONAL_CLEAN_FILES}")


macro (copy_include)
    foreach(include_folder ${ARGN})
        execute_process(COMMAND bash -c "cp ${include_folder}/* ${CMAKE_CURRENT_BINARY_DIR}/dependency_include/ -r"
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                ERROR_QUIET )
    endforeach()
endmacro()

macro (dependency_include)
    if ("$ENV{BUILD_AS_DEPENDENCY}" MATCHES "TRUE")
        copy_include(${ARGN})
    else()
        include_directories(${ARGN})
    endif()
endmacro()

function (append_new file_path new_string)
    if (NOT EXISTS "${file_path}")
        file(APPEND "${file_path}" "${new_string}")
    else()
        file(READ "${file_path}" content)
        string(FIND "${content}" "${new_string}" is_found)
        if (${is_found} EQUAL -1)
            file(APPEND "${file_path}" "${new_string}")
        endif()
    endif()
endfunction()

macro (add_dependency_package package_name_and_dir)
    message(STATUS "Adding package ${package_name_and_dir} to dependency tree")
    string(REPLACE "|" ";" package_name_and_dir ${package_name_and_dir})
    list(GET package_name_and_dir 0 package_name)
    list(LENGTH package_name_and_dir has_dir)
    if (${has_dir} GREATER 1)
        list(GET package_name_and_dir 1 package_DIR)
        set(package_dependency_string "${package_name}|${package_DIR};")
        set(${package_name}_DIR ${package_DIR})
    else()
        set(package_dependency_string "${package_name};")
    endif()
    append_new(${CMAKE_CURRENT_BINARY_DIR}/dependencies_packages.txt "${package_dependency_string}")
    find_package (${package_name} REQUIRED)
endmacro()

macro (add_dependency_output_directory dependency_output_directory)
    message(STATUS "Adding folder ${dependency_output_directory} to dependency tree")
    append_new("${CMAKE_CURRENT_BINARY_DIR}/dependencies_outputs.txt" "${dependency_output_directory};")
    link_directories(${dependency_output_directory})
endmacro()

macro(install_dependency git_repo_branch)
    string(REPLACE "|" ";" git_repo_branch ${git_repo_branch})
    list(GET git_repo_branch 0 git_repo)
    list(LENGTH git_repo_branch has_branch)

    execute_process(COMMAND basename ${git_repo}
            OUTPUT_VARIABLE repo_name )

    string(REPLACE "\n" "" repo_name ${repo_name})

    message(STATUS "\nConfiguring dependency ${repo_name}")

    set(dependency_folder "${dependencies_folder}/${repo_name}")

    if (CMAKE_BUILD_TYPE MATCHES Release)
        set(destination_folder "${dependency_folder}/dependency-build-release")
    else()
        set(destination_folder "${dependency_folder}/dependency-build-debug")
    endif()

    set(dependency_build_cache_file "${destination_folder}/dependency-build-cache")


    #if the dependency folder doesn't exists does the initial cloning of the repo
    if (NOT EXISTS "${dependency_folder}")
        execute_process(COMMAND git -C ${dependencies_folder} clone ${git_repo})
    endif()

    #if it has to switch branches, does the switch if not remains int he main branch
    if (${has_branch} GREATER 1)
        list(GET git_repo_branch 1 git_branch)
    else()
        #determines the main branch
        execute_process(COMMAND git branch -a
                WORKING_DIRECTORY ${dependency_folder}
                OUTPUT_VARIABLE dependency_branches)
        string(REPLACE "*" "" dependency_branches ${dependency_branches})
        string(REPLACE " " "" dependency_branches ${dependency_branches})
        string(REPLACE "\n" ";" dependency_branches ${dependency_branches})
        list(GET dependency_branches 0 main_branch)

        set(git_branch ${main_branch})
    endif()

    #checkouts the correct branch
    execute_process(COMMAND git checkout ${git_branch}
            WORKING_DIRECTORY ${dependency_folder}
            ERROR_VARIABLE dependency_checkout_error
            OUTPUT_VARIABLE dependency_checkout_output)

    if (NOT ${dependency_checkout_error} MATCHES "Already on")
        if (EXISTS "${dependency_build_cache_file}")
            file(REMOVE "${dependency_build_cache_file}")
        endif()
    endif()

    #pulls changes
    execute_process(COMMAND git pull
            WORKING_DIRECTORY ${dependency_folder}
            OUTPUT_VARIABLE git_pull_output
            ERROR_QUIET)

    set(build_or_cache BUILD)


    if ( NOT "${git_pull_output}" MATCHES "Already up to date.")
        if (EXISTS "${dependency_build_cache_file}")
            file(REMOVE "${dependency_build_cache_file}")
        endif()
    endif()

    if (NOT EXISTS "${dependency_build_cache_file}")
        make_directory("${destination_folder}")

        execute_process(COMMAND bash -c "DEPENDENCIES_FOLDER='${dependencies_folder}' BUILD_AS_DEPENDENCY=TRUE CATCH_TESTS=NO_TESTS cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} '-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}' -G 'CodeBlocks - Unix Makefiles' ${dependency_folder}"
            WORKING_DIRECTORY ${destination_folder}
            RESULT_VARIABLE dependency_cmake_result )
        if (NOT dependency_cmake_result EQUAL "0")
            message(FATAL_ERROR "failed to load dependency cmake file" )
        endif()
    endif()

    if (EXISTS "${destination_folder}/dependency_include")
        copy_include(${destination_folder}/dependency_include)
    endif()

    if (EXISTS "${destination_folder}/dependencies_outputs.txt")
        file(READ ${destination_folder}/dependencies_outputs.txt dependencies_outputs)
        foreach(output_folder ${dependencies_outputs})
            if (NOT ${output_folder} EQUAL "")
                add_dependency_output_directory(${output_folder})
            endif()
        endforeach()
    endif()

    if (EXISTS "${destination_folder}/dependencies_packages.txt")
        file(READ ${destination_folder}/dependencies_packages.txt dependencies_packages)
        foreach(dependencies_package_DIR ${dependencies_packages})
            if (NOT ${dependencies_package_DIR} EQUAL "")
                add_dependency_package(${dependencies_package_DIR})
            endif()
        endforeach()
    endif()

    if (NOT EXISTS "${dependency_build_cache_file}")
        execute_process(COMMAND make -j
                WORKING_DIRECTORY ${destination_folder}
                RESULT_VARIABLE dependency_make_result)
        if (NOT dependency_make_result EQUAL "0")
            message(FATAL_ERROR "failed to build dependency cmake file" )
        endif()
    endif()
    set (repo_targets "${destination_folder}/${repo_name}Targets.cmake")

    set (variadic_args ${ARGN})
    list(LENGTH variadic_args variadic_count)
    if (${variadic_count} GREATER 0)
        list(GET variadic_args 0 package_name)
        add_dependency_package ("${package_name}|${destination_folder}")
    endif ()
    file(APPEND "${destination_folder}/dependency-build-cache" "ready")
    add_dependency_output_directory(${destination_folder})
endmacro()
