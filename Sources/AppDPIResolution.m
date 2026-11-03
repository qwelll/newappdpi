#import "AppDPIResolution.h"
#import "AppDPIResolutionMath.h"
#import "AppDPIConfig.h"

static NSString *appdpi_scale_bundleIDCache = nil;

NSString *appdpi_scale_currentBundleIdentifier(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *identifier = bundle.bundleIdentifier;
        // Extension hosts may report the extension bundle; prefer the executable bundle id.
        if (identifier.length == 0) {
            NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
            identifier = [[bundlePath stringByDeletingPathExtension] lastPathComponent];
        }
        appdpi_scale_bundleIDCache = [identifier copy] ?: @"";
    });
    return appdpi_scale_bundleIDCache;
}

@interface AppDPIResolution ()
@property (nonatomic, assign) BOOL appdpi_scale_active;
@property (nonatomic, assign) CGFloat appdpi_scale_ratio;
@property (nonatomic, assign) CGSize appdpi_scale_originalScreenSize;
@property (nonatomic, assign) CGSize appdpi_scale_targetScreenSize;
@end

@implementation AppDPIResolution

+ (instancetype)appdpi_scale_shared {
    static AppDPIResolution *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self appdpi_scale_refresh];
    }
    return self;
}

- (void)appdpi_scale_refresh {
    AppDPIConfig *config = [AppDPIConfig appdpi_scale_shared];
    CGFloat ratio = config.appdpi_scale_isEnabled ? [config appdpi_scale_forCurrentApplication] : 1.0;
    if (!appdpi_scale_isValidRatio(ratio)) {
        ratio = 1.0;
    }

    BOOL active = (ratio != 1.0);
    CGSize original = CGSizeZero;
    CGSize scaled = CGSizeZero;
    if (active) {
        if (self.appdpi_scale_active && fabs(self.appdpi_scale_ratio - ratio) < 0.0001) {
            return; // Same configuration, keep the cached geometry.
        }
        // Read the main screen directly so a previous (scaled) value can never feed back in.
        CGFloat width = [[UIScreen mainScreen] nativeBounds].size.width /
                        (([[UIScreen mainScreen] nativeScale] > 0) ? [[UIScreen mainScreen] nativeScale] : 1);
        CGFloat height = [[UIScreen mainScreen] nativeBounds].size.height /
                         (([[UIScreen mainScreen] nativeScale] > 0) ? [[UIScreen mainScreen] nativeScale] : 1);
        original = CGSizeMake(width, height);
        if (original.width < 100 || original.height < 100) {
            active = NO;
        } else {
            scaled = appdpi_scale_sizeForRatio(original, ratio);
        }
    }
    if (ratio == 1.0 && !self.appdpi_scale_active) {
        return;
    }
    self.appdpi_scale_ratio = ratio;
    self.appdpi_scale_active = active;
    self.appdpi_scale_originalScreenSize = original;
    self.appdpi_scale_targetScreenSize = scaled;
}

- (NSString *)appdpi_scale_debugDescription {
    return [NSString stringWithFormat:@"<%@ %p bundle=%@ ratio=%.3f active=%d>",
            NSStringFromClass([self class]), self, appdpi_scale_currentBundleIdentifier(),
            (double)self.appdpi_scale_ratio, self.appdpi_scale_active];
}

- (CGSize)appdpi_scale_adjustSize:(CGSize)size {
    if (!self.appdpi_scale_active) {
        return size;
    }
    if (self.appdpi_scale_isScaledScreenSize:size) {
        return self.appdpi_scale_targetScreenSize;
    }
    return appdpi_scale_sizeForRatio(size, self.appdpi_scale_ratio);
}

- (CGRect)appdpi_scale_adjustRect:(CGRect)rect {
    if (!self.appdpi_scale_active) {
        return rect;
    }
    return appdpi_scale_rectForRatio(rect, self.appdpi_scale_ratio);
}

- (BOOL)appdpi_scale_isScaledScreenSize:(CGSize)size {
    if (!self.appdpi_scale_active) {
        return NO;
    }
    CGSize scaled = self.appdpi_scale_targetScreenSize;
    return fabs(size.width - scaled.width) < 1.0 && fabs(size.height - scaled.height) < 1.0;
}

@end
