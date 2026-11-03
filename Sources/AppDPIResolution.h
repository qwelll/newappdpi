#pragma once

#import <UIKit/UIKit.h>

// Application bundle identifier of the process being hooked (falls back to the main bundle).
FOUNDATION_EXPORT NSString *AppDPICurrentBundleIdentifier(void);

/*
 * Per-process resolution state. Views are scaled exactly once: the first time a size is requested
 * the original is recorded and the scaled value is cached, so repeated queries are cheap and the
 * window hooks can tell scaled frames from originals.
 */
@interface AppDPIResolution : NSObject
+ (instancetype)appdpi_scale_shared;

@property (nonatomic, readonly) BOOL appdpi_scale_active;
@property (nonatomic, readonly) CGFloat appdpi_scale_ratio;
/// The screen bounds before scaling (UIKit logical points).
@property (nonatomic, readonly) CGSize appdpi_scale_originalScreenSize;
@property (nonatomic, readonly) CGSize appdpi_scale_targetScreenSize;

/// Reads the current bundle's ratio and resets cached geometry when it changes.
- (void)appdpi_scale_refresh;

/// Converts a size reported by UIKit; returns the original when scaling is not active.
- (CGSize)appdpi_scale_adjustSize:(CGSize)size;
- (CGRect)appdpi_scale_adjustRect:(CGRect)rect;
/// True when `size` is (approximately) an already scaled screen size, used to avoid double scaling.
- (BOOL)appdpi_scale_isScaledScreenSize:(CGSize)size;
@end
