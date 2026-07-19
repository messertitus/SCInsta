#import "../../Utils.h"

%hook IGDirectThreadViewController
- (void)swipeableScrollManagerDidEndDraggingAboveSwipeThreshold:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}

- (void)shhModeTransitionButtonDidTap:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}

- (void)messageListViewControllerDidToggleShhMode:(id)arg1 {
    if ([SCIUtils getBoolPref:@"shh_mode_confirm"]) {
        NSLog(@"[SCInsta] Confirm shh mode triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}
%end
