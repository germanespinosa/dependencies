project(Dependencies)

# Get all propreties that cmake supports
if(NOT CMAKE_PROPERTY_LIST)
    execute_process(COMMAND cmake --help-property-list OUTPUT_VARIABLE CMAKE_PROPERTY_LIST)

    # Convert command output into a CMake list
    string(REGEX REPLACE ";" "\\\\;" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
    string(REGEX REPLACE "\n" ";" CMAKE_PROPERTY_LIST "${CMAKE_PROPERTY_LIST}")
endif()

function(print_properties)
    message("CMAKE_PROPERTY_LIST = ${CMAKE_PROPERTY_LIST}")
endfunction()

function(print_target_properties target)
    if(NOT TARGET ${target})
        message(STATUS "There is no target named '${target}'")
        return()
    endif()

    foreach(property ${CMAKE_PROPERTY_LIST})
        string(REPLACE "<CONFIG>" "${CMAKE_BUILD_TYPE}" property ${property})

        # Fix https://stackoverflow.com/questions/32197663/how-can-i-remove-the-the-location-property-may-not-be-read-from-target-error-i
        if(property STREQUAL "LOCATION" OR property MATCHES "^LOCATION_" OR property MATCHES "_LOCATION$")
            continue()
        endif()

        get_property(was_set TARGET ${target} PROPERTY ${property} SET)
        if(was_set)
            get_target_property(value ${target} ${property})
            message("OUT:${target} ${property} = ${value}")
        endif()
    endforeach()
endfunction()


add_subdirectory(${DEPENDENCY})

get_property(DEPENDENCY_TARGETS DIRECTORY ${DEPENDENCY} PROPERTY BUILDSYSTEM_TARGETS)

get_property(DEPENDENCY_INCLUDE_DIRECTORIES DIRECTORY ${DEPENDENCY} PROPERTY INCLUDE_DIRECTORIES)

MESSAGE(STATUS "TARGETS DETECTED: ${DEPENDENCY_TARGETS}")
MESSAGE(STATUS "DEPENDENCY INCLUDE_DIRECTORIES: ${DEPENDENCY_INCLUDE_DIRECTORIES}")


set(DEPENDENCY_LIBRARY_TARGETS "")

foreach(DEPENDENCY_TARGET ${DEPENDENCY_TARGETS})
    get_target_property(DEPENDENCY_TARGET_TYPE ${DEPENDENCY_TARGET} TYPE)
    if (NOT "${DEPENDENCY_TARGET_TYPE}" MATCHES "LIBRARY")
        continue()
    endif()

    list(APPEND DEPENDENCY_LIBRARY_TARGETS ${DEPENDENCY_TARGET})

    get_target_property(DEPENDENCY_TARGET_PATH ${DEPENDENCY_TARGET} BINARY_DIR)
    get_target_property(DEPENDENCY_TARGET_INCLUDE_DIRECTORIES ${DEPENDENCY_TARGET} INCLUDE_DIRECTORIES)
    get_target_property(DEPENDENCY_TARGET_EXPORT_NAME ${DEPENDENCY_TARGET} EXPORT_PROPERTIES)
    get_target_property(DEPENDENCY_IMPORTED_LIBNAME ${DEPENDENCY_TARGET} IMPORTED_LIBNAME)

    MESSAGE(STATUS "TARGET: ${DEPENDENCY_TARGET}")
    MESSAGE(STATUS "TARGET_PATH: ${DEPENDENCY_TARGET_PATH}")
    MESSAGE(STATUS "TARGET_INCLUDE_DIRECTORIES: ${DEPENDENCY_TARGET_INCLUDE_DIRECTORIES}")
    MESSAGE(STATUS "TARGET_EXPORT_NAME:" ${DEPENDENCY_TARGET_EXPORT_NAME})
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dependency_${DEPENDENCY_TARGET}-path.txt" "${DEPENDENCY_TARGET_PATH}")
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dependency_${DEPENDENCY_TARGET}-include_directories.txt" "${DEPENDENCY_TARGET_INCLUDE_DIRECTORIES}")
    print_target_properties(${DEPENDENCY_TARGET})
endforeach()


file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dependency-targets.txt" "${DEPENDENCY_LIBRARY_TARGETS}")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dependency-include_directories.txt" "${DEPENDENCY_INCLUDE_DIRECTORIES}")


## Because OUTPUT option may not use generator expressions,
## extract name of file from target's properties.
#get_target_property(mytarget_basename mytarget OUTPUT_NAME)
#get_target_property(mytarget_suffix mytarget SUFFIX)
#set(mytarget_filename ${mytarget_basename}${mytarget_suffix})
## make copied file be dependent from one which is build.
## Note, that DEPENDS here creates dependencies both from the target
## and from the file it creates.
#add_custom_command(OUTPUT
#        ${CMAKE_BINARY_DIR}/final_destination/${mytarget_filename}
#        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:mytarget>
#        ${CMAKE_BINARY_DIR}/final_destination
#        DEPENDS mytarget
#        )
## Create target which consume the command via DEPENDS.
#add_custom_target(copy_files ALL
#        DEPENDS ${CMAKE_BINARY_DIR}/final_destination/${mytarget_filename}
#        )