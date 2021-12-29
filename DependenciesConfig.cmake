make_directory (${CMAKE_CURRENT_BINARY_DIR}/dependency_include)
include_directories(${CMAKE_CURRENT_BINARY_DIR}/dependency_include)

if (NOT $ENV{DEPENDENCIES_FOLDER} EQUAL "")
    set(dependencies_folder "$ENV{DEPENDENCIES_FOLDER}" CACHE PATH "")
    message ("dependency folder parameter: $ENV{DEPENDENCIES_FOLDER}")
else()
    set(dependencies_folder "${CMAKE_CURRENT_SOURCE_DIR}/dependencies" CACHE PATH "")
endif()

make_directory(${dependencies_folder})

macro (copy_include)
    foreach(include_folder ${ARGN})
        execute_process(COMMAND bash -c "cp ${include_folder}/* ${CMAKE_CURRENT_BINARY_DIR}/dependency_include/ -r"
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}  )
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

macro(install_dependency git_repo)

    execute_process(COMMAND basename ${git_repo}
            OUTPUT_VARIABLE repo_name )

    string(REPLACE "\n" "" repo_name ${repo_name})

    message(STATUS "\nConfiguring dependency ${repo_name}")

    set(dependency_folder "${dependencies_folder}/${repo_name}")

    if (EXISTS "${dependency_folder}")
        execute_process(COMMAND git pull
                WORKING_DIRECTORY ${dependency_folder}
                OUTPUT_VARIABLE git_pull_output)
    else()
        execute_process(COMMAND git -C ${dependencies_folder} clone ${git_repo})
    endif()

    set(build_or_cache BUILD)

    set(destination_folder ${dependency_folder}/dependency-build)
    if ( "${git_pull_output}" MATCHES "Already up to date.")
        if (EXISTS "${destination_folder}")
            set(build_or_cache "USE_CACHE")
        endif()
    endif()

    if ("${build_or_cache}" MATCHES "BUILD")
        make_directory("${destination_folder}")

        execute_process(COMMAND bash -c "DEPENDENCIES_FOLDER='${dependencies_folder}' BUILD_AS_DEPENDENCY=TRUE CATCH_TESTS=NO_TESTS cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} '-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}' -G 'CodeBlocks - Unix Makefiles' ${dependency_folder}"
            WORKING_DIRECTORY ${destination_folder})
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
        message(STATUS "dependencies_packages found!")
        file(READ ${destination_folder}/dependencies_packages.txt dependencies_packages)
        foreach(dependencies_package_DIR ${dependencies_packages})
            if (NOT ${dependencies_package_DIR} EQUAL "")
                add_dependency_package(${dependencies_package_DIR})
            endif()
        endforeach()
    endif()

    if ("${build_or_cache}" MATCHES "BUILD")
        execute_process(COMMAND make -j
                WORKING_DIRECTORY ${destination_folder})
    endif()
    set (repo_targets "${destination_folder}/${repo_name}Targets.cmake")

    set (variadic_args ${ARGN})
    list(LENGTH variadic_args variadic_count)
    if (${variadic_count} GREATER 0)
        list(GET variadic_args 0 package_name)
        add_dependency_package ("${package_name}|${destination_folder}")
    endif ()

    add_dependency_output_directory(${destination_folder})

endmacro()
