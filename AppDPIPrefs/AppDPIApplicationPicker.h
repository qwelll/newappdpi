#import <UIKit/UIKit.h>

/// Called with the final selection when the user taps Done.
typedef void (^AppDPIApplicationPickerCompletion)(NSArray<NSString *> *selectedBundles);

@interface AppDPIApplicationPickerController : UIViewController
@property (nonatomic, copy) AppDPIApplicationPickerCompletion appdpi_scale_completion;
- (instancetype)appdpi_scale_initWithSelectedBundles:(NSArray<NSString *> *)selectedBundles;
/// User applications as dictionaries with keys name and bundle, sorted by display name.
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)appdpi_scale_loadApplications;
@end
