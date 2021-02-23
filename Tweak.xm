#define PREF_PATH @"/var/mobile/Library/Preferences/jp.r-plus.AnyKeyTrackpad.plist"
#define LOG_PATH @"/tmp/zanykey.log"
#import <DLog.h>
#import <UIKit/UIKit.h>

static BOOL allowVariantKeys = NO;
static BOOL allowTenKeys = YES;

// {{{ interfaces
@interface UIKBTree : NSObject
@property(retain, nonatomic) NSString *name; // iOS 5+
@property(retain, nonatomic) NSMutableDictionary *cache; // iOS 5+
@property(retain, nonatomic) NSMutableArray *subtrees; // iOS 5+
- (CGRect)frame; // iOS 5+
- (BOOL)isKanaPlane; // iOS 13+
@end

@interface UIKeyboardLayoutStar : UIView
@property(readonly, nonatomic) UIKBTree *keyplane;
- (BOOL)keyHasAccentedVariants:(UIKBTree *)arg1;
@end
// }}}
// {{{ util
static BOOL ContainsStringAny(NSString *str, NSArray<NSString *> *any)
{
    for (NSString *s in any) {
        if ([str containsString:s]) {
            return YES;
        }
    }
    return NO;
}
// }}}
%hook UIKeyboardLayoutStar // {{{ main hook
- (NSArray<NSValue *> *)_keyboardLongPressInteractionRegions // iOS 12+
{
    NSMutableArray<NSValue *> *regions = [NSMutableArray array];
    NSArray<UIKBTree *> *keys = self.keyplane.cache[@"keys"];
    DLog(@"%@", keys);
    for (UIKBTree *k in keys) {
        if (ContainsStringAny(k.name, @[
                    @"Shift-Key",
                    @"Delete-Key",
                    @"More-Key",
                    @"Return-Key",
                    @"Dictation-Key",
                    @"International-Key"])) {
            continue;
        }
        BOOL isTenKey = ContainsStringAny(k.name, @[@"Hiragana", @"TenKey", @"10Key"]);
        // `keyHasAccentedVariants` method return YES for kana keys.
        // this guard is for alphabetically keys.
        if (!allowVariantKeys && [self keyHasAccentedVariants:k] && !isTenKey) {
            continue;
        }
        if (!allowTenKeys && isTenKey) {
            continue;
        }

        [regions addObject:[NSValue valueWithCGRect:k.frame]];
    }
    return regions;
}
%end
// }}}
// {{{ pref
static void LoadSettings()
{
    NSDictionary *dict;
    CFStringRef appID = CFSTR("jp.r-plus.AnyKeyTrackpad");
    CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        dict = [(NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) autorelease];
        CFRelease(keyList);
    } else {
        dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    }
    id variantPref = [dict objectForKey:@"AllowVariantKeys"];
    allowVariantKeys = variantPref ? [variantPref boolValue] : NO;
    id tenPref = [dict objectForKey:@"AllowTenKeys"];
    allowTenKeys = tenPref ? [tenPref boolValue] : YES;
}

static void PostNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    LoadSettings();
}

%ctor
{
    @autoreleasepool {
        // enabled only for Application
        BOOL shouldLoad = NO;
        NSArray *args = [[NSClassFromString(@"NSProcessInfo") processInfo] arguments];
        NSUInteger count = args.count;
        if (count != 0) {
            NSString *executablePath = args[0];
            if (executablePath) {
                NSString *processName = [executablePath lastPathComponent];
                BOOL isSpringBoard = [processName isEqualToString:@"SpringBoard"];
                BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound || [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
                BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
                BOOL skip = [processName isEqualToString:@"AdSheet"]
                         || [processName isEqualToString:@"CoreAuthUI"]
                         || [processName isEqualToString:@"InCallService"]
                         || [processName isEqualToString:@"MessagesNotificationViewService"]
                         || [executablePath rangeOfString:@".appex/"].location != NSNotFound;
                if (!isFileProvider && (isSpringBoard || isApplication) && !skip) {
                    shouldLoad = YES;
                }
            }
        }
        if (!shouldLoad) return;

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PostNotification, CFSTR("jp.r-plus.anykeytrackpad.settingschanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
        LoadSettings();
        %init;
    }
}
// }}}
