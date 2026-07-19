#import "../../Utils.h"

%hook IGCommentComposer.IGCommentComposerController
- (void)onSendButtonTap {
    if ([SCIUtils getBoolPref:@"post_comment_confirm"]) {
        NSLog(@"[SCInsta] Confirm post comment triggered");

        void (^originalAction)(void) = ^{
            %orig;
        };
        [SCIUtils showConfirmation:originalAction];
    } else {
        return %orig;
    }
}
%end
