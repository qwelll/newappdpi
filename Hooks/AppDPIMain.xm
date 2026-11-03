#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "AppDPIConfig.h"
#import "AppDPIResolution.h"
#import "AppDPIResolutionMath.h"
#import "AppDPIPreferences.h"

/*
 * Per-application logical resolution override.
 *
 * 1. UIScreen reports the shrunk bounds so every screen-relative layout gets more points.
 * 2. The main UIWindow is resized to the same bounds (UIKit does not re-read UIScreen for an
 *    already existing window), and inbound frames are converted so repeated layout passes do not
 *    shrink the window again.
 * 3. Nothing touches nativeBounds/nativeScale/scale: the physical framebuffer, the touch
 *    digitizer and screenshots stay as they were, so gestures stay correct on notched devices.
 */

static NSMapTable<UIWindow *, NSValue *> *appdpi_scale_windowFrames(void) {
    static NSMapTable *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality)
                                      valueOptions:NSPointerFunctionsStrongMemory];
    });
    return table;
}

static BOOL appdpi_scale_isFullScreenRect(CGRect rect, CGSize screen) {
    if (screen.width < 100 || screen.height < 100) {
        return NO;
    }
    return fabs(rect.size.width - screen.width) < 1.5 && fabs(rect.size.height - screen.height) < 1.5;
}

// Converts an inbound window frame to the scaled value. Only frames that look like the current
// logical screen are scaled; overlays and partial windows keep their own geometry.
static CGRect appdpi_scale_frameForWrite(UIWindow *window, CGRect frame) {
    AppDPIResolution *resolution = [AppDPIResolution appdpi_scale_shared];
    if (!resolution.appdpi_scale_active || ![UIApplication sharedApplication]) {
        return frame;
    }
    NSMapTable *frames = appdpi_scale_windowFrames();
    NSValue *stored = window ? [frames objectForKey:window] : nil;
    if (stored) {
        // Our own resize arriving back through setFrame: reports the scaled screen size.
        if ([resolution appdpi_scale_isScaledScreenSize:frame.size]) {
            return frame;
        }
        [frames removeObjectForKey:window];
    }
    BOOL fullScreen = appdpi_scale_isFullScreenRect(frame, resolution.appdpi_scale_originalScreenSize);
    CGSize scaledSize = resolution.appdpi_scale_targetScreenSize;
    if (!fullScreen && !(fabs(frame.size.width - scaledSize.width) < 1.5 &&
                         fabs(frame.size.height - scaledSize.height) < 1.5)) {
        return frame;
    }
    CGRect scaled = [resolution appdpi_scale_adjustRect:frame];
    if (CGRectEqualToRect(scaled, frame)) {
        return frame;
    }
    if (window) {
        [frames setObject:[NSValue valueWithCGRect:frame] forKey:window];
    }
    return scaled;
}

static void appdpi_scale_resizeVisibleWindows(void) {
    AppDPIResolution *resolution = [AppDPIResolution appdpi_scale_shared];
    if (!resolution.appdpi_scale_active || ![UIApplication sharedApplication]) {
        return;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray<UIWindow *> *windows = [UIApplication sharedApplication].windows;
#pragma clang diagnostic pop
    for (UIWindow *window in windows) {
        CGRect frame = window.frame;
        if (!appdpi_scale_isFullScreenRect(frame, resolution.appdpi_scale_originalScreenSize) &&
            ![resolution appdpi_scale_isScaledScreenSize:frame.size]) {
            continue;
        }
        window.frame = appdpi_scale_frameForWrite(window, frame);
    }
}

%group AppDPIScreen
%hook UIScreen

- (CGRect)bounds {
    return [[AppDPIResolution appdpi_scale_shared] appdpi_scale_adjustRect:%orig];
}

- (CGRect)_referenceBounds {
    return [[AppDPIResolution appdpi_scale_shared] appdpi_scale_adjustRect:%orig];
}

- (CGRect)_mainScreenBounds {
    return [[AppDPIResolution appdpi_scale_shared] appdpi_scale_adjustRect:%orig];
}

// Status bar metrics follow the screen; keep them inside the new bounds.
- (CGRect)_statusBarFrameForOrientation:(long long)orientation {
    return [[AppDPIResolution appdpi_scale_shared] appdpi_scale_adjustRect:%orig(orientation)];
}

%end
%end

%group AppDPIWindow
%hook UIWindow

- (void)setFrame:(CGRect)frame {
    %orig(appdpi_scale_frameForWrite(self, frame));
}

%end
%end

static void appdpi_scale_installHooks(void);

static void appdpi_scale_applyConfiguration(void) {
    AppDPIResolution *resolution = [AppDPIResolution appdpi_scale_shared];
    [resolution appdpi_scale_refresh];
    if (!resolution.appdpi_scale_active) {
        // Disabling from the panel restores the original window geometry immediately.
        appdpi_scale_installHooks();
        return;
    }
    // Hooks are installed lazily on the main thread: UIApplication exists and injecting an app that
    // is already running is safe.
    appdpi_scale_installHooks();
    appdpi_scale_resizeVisibleWindows();
}

// Logos groups may only be %init'd once, so every caller funnels through this gate.
static void appdpi_scale_installHooks(void) {
    static dispatch_once_t installToken;
    dispatch_once(&installToken, ^{
        %init(AppDPIScreen);
        %init(AppDPIWindow);
    });
}

%ctor {
    @autoreleasepool {
        // Readers only load a snapshot; they never write preferences.
        [AppDPIConfig appdpi_scale_shared];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            (CFNotificationCallback)appdpi_scale_applyConfiguration,
            (__bridge CFStringRef)AppDPIPreferencesChanged,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Wait for the first main-thread turn so UIApplication/UIScreen are fully initialized.
        dispatch_async(dispatch_get_main_queue(), ^{
            appdpi_scale_applyConfiguration();
        });
    }
}
