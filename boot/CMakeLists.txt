# cmake -DCMAKE_TOOLCHAIN_FILE=../toolchain.cmake -DCMAKE_BUILD_TYPE=MinSizeRel -S boot -B boot/build
# cmake --build boot/build

cmake_minimum_required(VERSION 3.16)

project(Poly94_boot ASM C)

function(target_postprocess TARGET)
    target_include_directories(${TARGET} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../sdk/include)

    target_link_options(${TARGET} PRIVATE "-Wl,-Map=$<TARGET_FILE:${TARGET}>.map")

    add_custom_command(TARGET ${TARGET} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${TARGET}> ${TARGET}.bin
            COMMAND hexdump -v -e "1/4 \\\"%08x\\\\n\\\"" ${TARGET}.bin > ${TARGET}.vh
            COMMAND ${CMAKE_OBJDUMP} -dt $<TARGET_FILE:${TARGET}> > ${TARGET}.objdump.txt
            COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${TARGET}>
            COMMENT "Building ${TARGET}.bin")
endfunction()


add_executable(boot
    start.s
    boot.c
    )

add_executable(boot_sdram
    start_sdram.s
    )

add_executable(test_dhrystone
    start.s
    dhrystone/dhrystone.c
    dhrystone/dhrystone.h
    dhrystone/dhrystone_main.c
    stdio.c
    )

add_executable(test_framebuffer
    start.s
    test_framebuffer.c
    )

target_postprocess(boot)
target_link_options(boot PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/boot.ld")
target_postprocess(boot_sdram)
target_link_options(boot_sdram PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/boot.ld")
target_postprocess(test_dhrystone)
target_link_options(test_dhrystone PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/sdram.ld")
target_postprocess(test_framebuffer)
target_link_options(test_framebuffer PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/boot.ld")
