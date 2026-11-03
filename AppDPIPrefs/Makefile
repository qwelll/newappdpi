include ../AppDPIBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AppDPIPrefs
AppDPIPrefs_FILES = $(wildcard *.m)
AppDPIPrefs_CFLAGS = -fobjc-arc -I../Sources
AppDPIPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
AppDPIPrefs_PRIVATE_FRAMEWORKS = Preferences
AppDPIPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
