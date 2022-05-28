#pragma once

#include <fstream>

inline void write_ppm(const char* path, int width, int height, uint32_t const* pixels_rgb) {
    std::ofstream f(path, std::ios::binary);

    char header[20];
    snprintf(header, sizeof(header), "P6\n%d %d\n255\n", width, height);
    f << header;

    for (int i = 0; i < width * height; i++) {
        auto rgb = pixels_rgb[i];

        f << (uint8_t)(rgb >> 16);
        f << (uint8_t)(rgb >> 8);
        f << (uint8_t)(rgb >> 0);
    }
}
