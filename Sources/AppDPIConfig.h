#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface AppDPIConfig : NSObject
+ (instancetype)appdpi_scale_shared;
- (BOOL)appdpi_scale_isEnabled;
- (id)appdpi_scale_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
/// Scale factor for the current process' bundle identifier, 1.0 when the app is not configured.
- (CGFloat)appdpi_scale_forCurrentApplication;
/// Explicit application identifiers from the preferences panel.
- (NSArray<NSString *> *)appdpi_scale_selectedApplications;
- (void)appdpi_scale_reload;
@end
