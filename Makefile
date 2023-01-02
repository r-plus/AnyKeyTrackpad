export ARCHS = arm64 arm64e
export TARGET = iphone:clang::12.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnyKeyTrackpad
AnyKeyTrackpad_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
