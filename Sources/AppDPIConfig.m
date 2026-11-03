#import "AppDPIConfig.h"
#import "AppDPIPreferences.h"
#import "AppDPIResolution.h"

@interface AppDPIConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void appdpi_scale_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    AppDPIConfig *config = (__bridge AppDPIConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config appdpi_scale_reload];
    });
}

@implementation AppDPIConfig

+ (instancetype)appdpi_scale_shared {
    static AppDPIConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _snapshot = @{};
        _reloadQueue = dispatch_queue_create("com.appdpi.dpiscale.preferences", DISPATCH_QUEUE_SERIAL);
        [self appdpi_scale_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, appdpi_scale_preferencesDidChange,
            (__bridge CFStringRef)AppDPIPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)appdpi_scale_reload {
    self.snapshot = appdpi_scale_readPreferences() ?: @{};
}

- (id)appdpi_scale_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    id value = self.snapshot[key];
    return value ?: defaultValue;
}

- (BOOL)appdpi_scale_isEnabled {
    id value = [self appdpi_scale_valueForKey:@"enabled" defaultValue:@NO];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

- (NSArray<NSString *> *)appdpi_scale_selectedApplications {
    id value = [self appdpi_scale_valueForKey:@"selectedApps" defaultValue:nil];
    NSMutableArray *result = [NSMutableArray array];
    if ([value isKindOfClass:[NSArray class]]) {
        for (id item in (NSArray *)value) {
            if ([item isKindOfClass:[NSString class]] && [(NSString *)item length] > 0) {
                [result addObject:item];
            }
        }
    }
    return result;
}

- (CGFloat)appdpi_scale_forCurrentApplication {
    NSString *identifier = AppDPICurrentBundleIdentifier();
    if (identifier.length == 0) {
        return 1.0;
    }
    NSDictionary *ratios = [self appdpi_scale_valueForKey:@"appRatios" defaultValue:nil];
    CGFloat ratio = 1.0;
    if ([ratios isKindOfClass:[NSDictionary class]] && ratios[identifier] != nil) {
        // An explicit per-app value always wins, including values that disable scaling.
        id value = ratios[identifier];
        ratio = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 1.0;
    } else if ([[self appdpi_scale_selectedApplications] containsObject:identifier]) {
        id value = [self appdpi_scale_valueForKey:@"defaultRatio" defaultValue:@0.9];
        ratio = [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0.9;
    }
    if (!(ratio > 0.5 && ratio < 1.0)) {
        return 1.0;
    }
    return (CGFloat)ratio;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
