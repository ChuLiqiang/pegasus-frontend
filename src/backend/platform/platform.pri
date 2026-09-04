HEADERS += \
    $$PWD/PowerCommands.h \
    $$PWD/TerminalKbd.h \

SOURCES += \
    $$PWD/TerminalKbd.cpp \


win32 {
    SOURCES += $$PWD/PowerCommands_win.cpp
}
else:unix:!android {
    macx {
        SOURCES += $$PWD/PowerCommands_mac.cpp
        HEADERS += $$PWD/macos/NativeFullscreen.h
        OBJECTIVE_SOURCES += $$PWD/macos/NativeFullscreen.mm
        LIBS += -framework Cocoa
    }
    else: SOURCES += $$PWD/PowerCommands_linux.cpp
}
else {
    SOURCES += $$PWD/PowerCommands_unimpl.cpp
}

android {
    HEADERS += \
        $$PWD/AndroidAppIconProvider.h \
        $$PWD/AndroidHelpers.h

    SOURCES += \
        $$PWD/AndroidAppIconProvider.cpp \
        $$PWD/AndroidHelpers.cpp
}
