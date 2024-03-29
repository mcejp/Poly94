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

add_executable(demo_hello_world
    start.s
    demos/hello_world/main.c
    stdio.c
    )

add_executable(demo_memory_latency
    start.s
    demos/memory_latency/MemoryLatency.c
    demos/memory_latency/MemoryLatency_rv32.s
    stdio.c
    )

foreach(TARGET boot boot_sdram demo_hello_world test_framebuffer)
    target_postprocess(${TARGET})
    target_link_options(${TARGET} PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/boot.ld")
endforeach()

foreach(TARGET demo_memory_latency test_dhrystone)
    target_postprocess(${TARGET})
    target_link_options(${TARGET} PRIVATE "-T" "${CMAKE_CURRENT_SOURCE_DIR}/sdram.ld")
endforeach()
