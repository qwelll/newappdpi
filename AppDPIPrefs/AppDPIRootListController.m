#import "AppDPIRootListController.h"
#import "AppDPIApplicationPicker.h"
#import "AppDPIPreferences.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

/*
 * Settings panel. Single writer for com.appdpi.dpiscale.
 *
 * Besides the static plist specifiers this controller builds two specifier groups on the fly:
 * one slider per selected application (overriding the default ratio) and a reset button.
 */

static NSString * const appdpi_scale_ratiosKey = @"appRatios";

@interface AppDPIRootListController ()
@end

@implementation AppDPIRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [[self loadSpecifiersFromPlistName:@"AppDPIRoot" target:self] mutableCopy];
        [self appdpi_scale_appendApplicationSpecifiers];
    }
    return _specifiers;
}

#pragma mark - Dynamic specifiers

- (void)appdpi_scale_appendApplicationSpecifiers {
    NSDictionary *preferences = appdpi_scale_readPreferences();
    NSArray *selected = [preferences[@"selectedApps"] isKindOfClass:[NSArray class]] ? preferences[@"selectedApps"] : @[];
    NSDictionary *ratios = [preferences[appdpi_scale_ratiosKey] isKindOfClass:[NSDictionary class]] ? preferences[appdpi_scale_ratiosKey] : @{};
    NSNumber *defaultRatio = [preferences[@"defaultRatio"] isKindOfClass:[NSNumber class]] ? preferences[@"defaultRatio"] : @0.9;
    if (selected.count == 0) {
        return;
    }

    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"应用比例"];
    [group setProperty:@"不单独调整的 App 使用上方的默认比例。" forKey:@"footerText"];
    [_specifiers addObject:group];

    for (NSString *bundle in selected) {
        NSString *name = [self appdpi_scale_displayNameForBundle:bundle];
        PSSpecifier *slider = [PSSpecifier preferenceSpecifierNamed:name
                                                             target:self
                                                                set:@selector(setPreferenceValue:specifier:)
                                                                get:@selector(appdpi_scale_readPreferenceValueForSpecifier:)
                                                             detail:nil
                                                                cell:PSSliderCell
                                                                edit:nil];
        // Sliders read and write the whole appRatios dictionary; the getter/setter below unwrap one key.
        [slider setProperty:bundle forKey:@"key"];
        [slider setProperty:bundle forKey:@"appdpiBundle"];
        [slider setProperty:@0.6 forKey:@"min"];
        [slider setProperty:@1.0 forKey:@"max"];
        [slider setProperty:@(YES) forKey:@"showValue"];
        [slider setProperty:ratios[bundle] ?: defaultRatio forKey:@"default"];
        [slider setProperty:@YES forKey:@"isSegmented"];
        [slider setProperty:@"0.6" forKey:@"leftLabel"];
        [slider setProperty:@"1.0" forKey:@"rightLabel"];
        [_specifiers addObject:slider];
    }

    PSSpecifier *reset = [PSSpecifier preferenceSpecifierNamed:@"清除单个应用比例"
                                                        target:self
                                                           set:nil
                                                           get:nil
                                                        detail:nil
                                                          cell:PSButtonCell
                                                          edit:nil];
    reset.buttonAction = @selector(appdpi_scale_resetApplicationRatios);
    [_specifiers addObject:reset];
}

- (id)appdpi_scale_readPreferenceValueForSpecifier:(PSSpecifier *)specifier {
    NSString *bundle = [specifier propertyForKey:@"appdpiBundle"];
    NSDictionary *ratios = appdpi_scale_readPreferences()[appdpi_scale_ratiosKey];
    id value = [ratios isKindOfClass:[NSDictionary class]] ? ratios[bundle] : nil;
    return [value isKindOfClass:[NSNumber class]] ? value : [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *bundle = [specifier propertyForKey:@"appdpiBundle"];
    if (bundle.length > 0) {
        NSDictionary *existing = appdpi_scale_readPreferences()[appdpi_scale_ratiosKey];
        NSMutableDictionary *ratios = [existing isKindOfClass:[NSDictionary class]] ? [existing mutableCopy] : [NSMutableDictionary dictionary];
        if (!value) value = @1.0;
        // A value equal to the default is redundant, so remove the override instead of storing it.
        NSNumber *defaultRatio = [specifier propertyForKey:@"default"];
        if ([value isKindOfClass:[NSNumber class]] && defaultRatio &&
            fabs([value doubleValue] - [defaultRatio doubleValue]) < 0.0005) {
            [ratios removeObjectForKey:bundle];
        } else {
            ratios[bundle] = value;
        }
        [self appdpi_scale_writeValue:ratios forKey:appdpi_scale_ratiosKey];
        return;
    }
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;
    [self appdpi_scale_writeValue:value forKey:key];
}

- (void)appdpi_scale_writeValue:(id)value forKey:(NSString *)key {
    NSError *error = nil;
    if (!appdpi_scale_writePreference(key, value, &error)) {
        [self appdpi_scale_showWriteError:error];
        [self reloadSpecifiers];
    }
}

- (void)appdpi_scale_showWriteError:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存"
        message:error.localizedDescription ?: @"请检查配置文件路径和写入权限。"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)appdpi_scale_resetApplicationRatios {
    [self appdpi_scale_writeValue:@{} forKey:appdpi_scale_ratiosKey];
    [self reloadSpecifiers];
}

#pragma mark - Application picker

- (void)appdpi_scale_pickApplications {
    NSArray *selected = appdpi_scale_readPreferences()[@"selectedApps"];
    AppDPIApplicationPickerController *picker =
        [[AppDPIApplicationPickerController alloc] initWithSelectedBundles:
            [selected isKindOfClass:[NSArray class]] ? selected : @[]];
    picker.appdpi_scale_completion = ^(NSArray<NSString *> *bundles) {
        NSError *error = nil;
        if (!appdpi_scale_writePreference(@"selectedApps", bundles, &error)) {
            [self appdpi_scale_showWriteError:error];
            return;
        }
        // Drop ratios for apps that are no longer selected so stale entries cannot resurrect later.
        NSDictionary *existing = appdpi_scale_readPreferences()[appdpi_scale_ratiosKey];
        if ([existing isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *kept = [NSMutableDictionary dictionary];
            for (NSString *bundle in bundles) {
                if (existing[bundle]) kept[bundle] = existing[bundle];
            }
            if (kept.count != existing.count) {
                appdpi_scale_writePreference(appdpi_scale_ratiosKey, kept, NULL);
            }
        }
        [self appdpi_scale_rebuildSpecifiers];
    };
    [self.navigationController pushViewController:picker animated:YES];
}

- (void)appdpi_scale_rebuildSpecifiers {
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSString *)appdpi_scale_displayNameForBundle:(NSString *)bundle {
    for (NSDictionary *application in [AppDPIApplicationPickerController appdpi_scale_loadApplications]) {
        if ([application[@"bundle"] isEqualToString:bundle]) {
            return application[@"name"];
        }
    }
    return bundle;
}

@end
