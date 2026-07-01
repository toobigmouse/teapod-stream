cmake_minimum_required(VERSION 3.14)
project(win_tun LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(win_tun SHARED
    win_tun_wrapper.cpp
    win_tun_wrapper.h
)

target_compile_definitions(win_tun PRIVATE WIN_TUN_EXPORTS)

target_link_libraries(win_tun PRIVATE
    advapi32
    iphlpapi
    ws2_32
    secur32
)
