#pragma once

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

/*
 * Logical-resolution scaling.
 *
 * UIKit layout density depends on UIScreen bounds, scale and coordinate spaces. Shrinking the
 * logical bounds makes an app lay out as if the display were smaller (more content per point)
 * while the physical framebuffer is untouched. These helpers are pure functions shared by the
 * property hooks and the window-frame hooks.
 */

/// Ratios outside this range are treated as "no scaling".
static inline BOOL appdpi_scale_isValidRatio(CGFloat ratio) {
    return ratio > 0.5 && ratio < 1.0;
}

static inline CGFloat appdpi_scale_clamp(CGFloat value, CGFloat maximum) {
    return MAX(0.0, MIN(value, maximum));
}

/// Scales a full-screen size. Guards against zero/placeholder sizes reported before layout.
static inline CGSize appdpi_scale_sizeForRatio(CGSize original, CGFloat ratio) {
    if (!appdpi_scale_isValidRatio(ratio) || original.width < 100 || original.height < 100) {
        return original;
    }
    double width = floor(original.width * ratio + 0.5);
    double height = floor(original.height * ratio + 0.5);
    // Keep even-dimension screens even so center-split layouts never land on half points.
    if (((long)original.width % 2) == 0 && ((long)width % 2) != 0) width += 1;
    if (((long)original.height % 2) == 0 && ((long)height % 2) != 0) height += 1;
    return CGSizeMake((CGFloat)width, (CGFloat)height);
}

static inline CGRect appdpi_scale_rectForRatio(CGRect original, CGFloat ratio) {
    if (!appdpi_scale_isValidRatio(ratio) || original.size.width < 100 || original.size.height < 100) {
        return original;
    }
    CGSize size = appdpi_scale_sizeForRatio(original.size, ratio);
    // Window origins are small offsets around 0; keep them inside the shrunk screen.
    CGFloat maxX = MAX(size.width - original.size.width, 0);
    CGFloat maxY = MAX(size.height - original.size.height, 0);
    return CGRectMake(appdpi_scale_clamp(original.origin.x, maxX),
                      appdpi_scale_clamp(original.origin.y, maxY),
                      size.width, size.height);
}
