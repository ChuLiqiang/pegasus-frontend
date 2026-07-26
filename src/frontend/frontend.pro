TEMPLATE = lib

QT += qml quick 3dcore 3drender 3dinput 3dlogic 3dextras 3danimation 3dquick
CONFIG += c++11 staticlib warn_on exceptions_off rtti_off qtquickcompiler
DEFINES *= $${COMMON_DEFINES}

RESOURCES += \
    ./frontend.qrc \
    ../qmlutils/qmlutils.qrc \
    ../themes/themes.qrc
