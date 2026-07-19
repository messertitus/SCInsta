#import "../../Utils.h"

static BOOL SCIShouldDisableInstantsCreation(void) {
    return [SCIUtils getBoolPref:@"disable_instants_creation"];
}

// Demangled name: IGQuickSnapExperimentation.IGQuickSnapExperimentationHelper
%hook _TtC26IGQuickSnapExperimentation32IGQuickSnapExperimentationHelper
+ (_Bool)isQuicksnapEnabled:(id)enabled {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInFeed:(id)feed {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInInbox:(id)inbox {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInStories:(id)stories {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInNotesTray:(id)tray {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPeek:(id)peek {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapEnabledInNotesTrayWithPog:(id)pog {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
+ (_Bool)isQuicksnapNotesTrayEmptyPogEnabled:(id)enabled {
    if (SCIShouldDisableInstantsCreation()) return false;
    return %orig;
}
// + (_Bool)isStoriesSpringEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)shouldEnableScreenshotBlocking:(id)blocking {
//     return false;
// }
// + (_Bool)areFiltersEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)isBottomsheetCustomAudienceEnabled:(id)enabled {
//     return true;
// }
// + (_Bool)isVideoCaptureEnabled:(id)enabled {
//     return true;
// }
%end

// %hook IGDirectNotesTrayRowCell
// - (_Bool)isQuicksnapPeekVisible {
//     return true;
// }
// %end

// %hook IGDirectNotesTrayRowSectionController
// - (_Bool)isQuicksnapPeekVisible {
//     return true;
// }
// %end
