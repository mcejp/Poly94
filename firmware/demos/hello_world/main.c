#include <unistd.h>

/*
Build it: see ../README.md

Run it (sim):

    BOOTROM=firmware/build/demo_hello_world.bin make sim

Run it (hw):

    (TODO)

*/

static const char message[] = "Hello, world!\n";

int main() {
    write(0, message, sizeof(message) - 1);

    for (;;) {}
}
