ifeq ($(ROOTLESS),1)
	THEOS_PACKAGE_SCHEME = rootless
endif

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:clang::15.0
else
	TARGET = iphone:clang::12.0
endif

export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AnyKeyTrackpad
AnyKeyTrackpad_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences MobileNotes"
