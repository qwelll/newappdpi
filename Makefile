DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include AppDPIBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AppDPI
AppDPI_FILES = $(wildcard Hooks/*.xm Sources/*.m)
AppDPI_CFLAGS = -fobjc-arc -I./Headers -I./Sources
AppDPI_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore
AppDPI_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += AppDPIPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
