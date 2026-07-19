#import "../../Utils.h"

%hook IGStoryViewerTapTarget
- (void)_didTap:(id)arg1 forEvent:(id)arg2 {
    if ([SCIUtils getBoolPref:@"sticker_interact_confirm"]) {
        NSLog(@"[SCInsta] Confirm sticker interact triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}
%end
