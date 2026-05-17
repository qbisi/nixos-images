cmake_minimum_required(VERSION 3.20)

project(configuration VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml Multimedia Network LinguistTools)
find_package(PkgConfig REQUIRED)
pkg_check_modules(UDEV REQUIRED libudev)

set_source_files_properties(src/qml/Main.qml PROPERTIES
    QT_RESOURCE_ALIAS Main.qml
)

qt_add_executable(configuration
    src/BacklightController.cpp
    src/BacklightController.h
    src/SoundCheckController.cpp
    src/SoundCheckController.h
    src/UpdateController.cpp
    src/UpdateController.h
    src/UsbDeviceModel.cpp
    src/UsbDeviceModel.h
    src/main.cpp
)

qt_add_qml_module(configuration
    URI Configuration
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        src/qml/Main.qml
)

qt_add_translations(configuration
    TS_FILES
        src/translations/configuration_zh_CN.ts
    RESOURCE_PREFIX /i18n
)

target_include_directories(configuration PRIVATE ${UDEV_INCLUDE_DIRS})
target_link_libraries(configuration
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Qml
        Qt6::Multimedia
        Qt6::Network
        ${UDEV_LIBRARIES}
)

install(TARGETS configuration RUNTIME DESTINATION bin)
