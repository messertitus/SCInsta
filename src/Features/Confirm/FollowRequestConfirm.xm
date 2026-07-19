#import "../../Utils.h"

%hook IGPendingRequestView
- (void)_onApproveButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        NSLog(@"[SCInsta] Confirm follow request triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}
- (void)_onIgnoreButtonTapped {
    if ([SCIUtils getBoolPref:@"follow_request_confirm"]) {
        NSLog(@"[SCInsta] Confirm follow request triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}
%end
