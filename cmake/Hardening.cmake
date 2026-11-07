# Optional compiler and linker hardening, controlled by OPENMW_HARDENING.
#
# Off by default. Enabling it changes the code generated for every translation
# unit, so it is opt-in rather than something that quietly alters an existing
# build. It is aimed at anyone building a dedicated server that accepts
# connections from untrusted clients, and at distributors.
#
# The compile options are applied to the whole project rather than to one
# target. Packet deserialization lives in the "components" static library,
# which is linked into the client, the server, OpenCS and the test suite, so
# applying these to tes3mp-server alone would leave the parsing code
# untouched. Applying _GLIBCXX_ASSERTIONS to some targets but not others would
# additionally be an ODR violation across inline libstdc++ functions.
#
# Deliberately not included here: -fPIE and -pie. CMP0083 only exists in CMake
# 3.14 and later, and before that POSITION_INDEPENDENT_CODE on an executable
# adds -fPIE when compiling but never -pie when linking, so asking for PIE in
# this project's supported CMake range would either do nothing or fail to link
# against dependencies that are not built as PIC. A GCC configured with
# --enable-default-pie, which is the default on Debian and Ubuntu, already
# produces a position-independent executable.

include(CheckCXXCompilerFlag)

# Collects the hardening compile options supported by the active compiler.
function (get_hardening_compile_options OUT_VAR)
    if (NOT (CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
            OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang"
            OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang"))
        message(WARNING
            "OPENMW_HARDENING is enabled but no hardening options are known for "
            "CMAKE_CXX_COMPILER_ID ${CMAKE_CXX_COMPILER_ID}; building unhardened.")
        set(${OUT_VAR} "" PARENT_SCOPE)
        return()
    endif()

    set(_options -fstack-protector-strong -D_GLIBCXX_ASSERTIONS)

    # glibc's features.h emits a #warning when _FORTIFY_SOURCE is requested
    # without optimization, so keep it out of Debug builds. Debian and Ubuntu
    # predefine it, so undefine it first to avoid a redefinition warning on
    # every translation unit.
    list(APPEND _options
        $<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE>
        $<$<NOT:$<CONFIG:Debug>>:-D_FORTIFY_SOURCE=2>)

    # Not available on every supported compiler or target architecture, so
    # probe rather than assume, in the same spirit as the check_ipo_supported
    # call used for OPENMW_LTO_BUILD.
    #
    # Probed with -Werror because Clang accepts both of these on targets where
    # they do nothing and merely warns that the argument went unused, which
    # would otherwise pass the check and then emit that warning for every
    # translation unit in the project.
    set(_saved_required_flags "${CMAKE_REQUIRED_FLAGS}")
    set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -Werror")
    foreach (_candidate -fstack-clash-protection -fcf-protection=full)
        string(MAKE_C_IDENTIFIER "HAVE${_candidate}" _cache_var)
        check_cxx_compiler_flag(${_candidate} ${_cache_var})
        if (${_cache_var})
            list(APPEND _options ${_candidate})
        endif()
    endforeach()
    set(CMAKE_REQUIRED_FLAGS "${_saved_required_flags}")

    set(${OUT_VAR} "${_options}" PARENT_SCOPE)
endfunction ()

# Appends the hardening link flags for an executable or shared library.
# Separated from the compile options because these are ELF concepts: ld64
# rejects -z, so nothing is added on Apple platforms.
function (harden_target_links TARGET_NAME)
    if (NOT OPENMW_HARDENING)
        return()
    endif()

    if (APPLE OR NOT (CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
            OR CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
        return()
    endif()

    # Full RELRO. GNU_RELRO alone leaves .got.plt writable for the lifetime of
    # the process; -z now resolves every PLT entry at load time so the whole
    # GOT can be mapped read-only.
    #
    # This hardens one image. A server process maps its dependencies too, and
    # their RELRO status is decided by whoever built them, so treat this as
    # raising the cost of exploiting a memory-safety bug rather than as
    # preventing it.
    #
    # set_property with APPEND_STRING is used in preference to
    # target_link_options because the latter requires CMake 3.13 and this
    # project still declares 3.1.0.
    set_property(TARGET ${TARGET_NAME} APPEND_STRING PROPERTY
        LINK_FLAGS " -Wl,-z,relro,-z,now -Wl,-z,noexecstack")
endfunction ()
