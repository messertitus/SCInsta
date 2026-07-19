#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import <objc/runtime.h>
#import <stdlib.h>

static BOOL SCIReelFilterDiagnosticsEnabled(void) {
    return [SCIUtils getBoolPref:@"reel_filter_diagnostics"];
}

static void SCIReelFilterLogClassRule(NSString *className, NSString *rule) {
    if (!SCIReelFilterDiagnosticsEnabled()) return;

    NSLog(@"[SCInsta][ReelFilter] class=%@ rule=%@", className ?: @"", rule ?: @"");
}

static void SCIReelFilterLogPropertyRule(NSString *className, NSString *propertyName, NSString *rule) {
    if (!SCIReelFilterDiagnosticsEnabled()) return;

    NSLog(@"[SCInsta][ReelFilter] class=%@ property=%@ rule=%@", className ?: @"", propertyName ?: @"", rule ?: @"");
}

static void SCIReelFilterLogIvarRule(NSString *className, NSString *ivarName, NSString *typeEncoding, NSString *rule) {
    if (!SCIReelFilterDiagnosticsEnabled()) return;

    NSLog(@"[SCInsta][ReelFilter] class=%@ ivar=%@ type=%@ rule=%@", className ?: @"", ivarName ?: @"", typeEncoding ?: @"", rule ?: @"");
}

static NSString *SCINormalizedMarkerString(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return nil;

    return [[value lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL SCIStringIsExactReelProductType(NSString *value) {
    NSString *normalized = SCINormalizedMarkerString(value);
    if (normalized == nil) return NO;

    return [normalized isEqualToString:@"clips"]
        || [normalized isEqualToString:@"reels"]
        || [normalized isEqualToString:@"reel"]
        || [normalized isEqualToString:@"sundial"];
}

static BOOL SCIStringHasClipsOrSundialMarker(NSString *value) {
    NSString *normalized = SCINormalizedMarkerString(value);
    if (normalized == nil) return NO;

    return [normalized containsString:@"clips"] || [normalized containsString:@"sundial"];
}

static id SCIReadKVCValue(id object, NSString *key) {
    @try {
        return [object valueForKey:key];
    }
    @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL SCIValueLooksLikeClipsMetadata(id value) {
    if (value == nil || value == [NSNull null]) return NO;

    NSString *className = NSStringFromClass([value class]);
    if (SCIStringHasClipsOrSundialMarker(className)) return YES;

    if ([value isKindOfClass:[NSDictionary class]]) {
        for (id rawKey in [(NSDictionary *)value allKeys]) {
            if ([rawKey isKindOfClass:[NSString class]] && SCIStringHasClipsOrSundialMarker((NSString *)rawKey)) {
                return YES;
            }
        }
    }

    return NO;
}

static BOOL SCIReadObjectIvarsForClipsMarkers(id object, NSString **matchedRule) {
    NSString *objectClassName = NSStringFromClass([object class]);

    for (Class cls = [object class]; cls != Nil && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);

        for (unsigned int index = 0; index < count; index++) {
            Ivar ivar = ivars[index];
            const char *rawName = ivar_getName(ivar);
            const char *rawType = ivar_getTypeEncoding(ivar);
            if (rawName == NULL || rawType == NULL) continue;

            NSString *name = [NSString stringWithUTF8String:rawName];
            NSString *typeEncoding = [NSString stringWithUTF8String:rawType];
            NSString *lowerName = [name lowercaseString];

            BOOL clipsNamed = [lowerName containsString:@"clips"] || [lowerName containsString:@"sundial"];
            BOOL productTypeNamed = [lowerName containsString:@"producttype"] || [lowerName containsString:@"product_type"];
            if (!clipsNamed && !productTypeNamed) continue;

            SCIReelFilterLogIvarRule(objectClassName, name, typeEncoding, @"candidate_ivar");

            // Only read Objective-C object ivars. Reading scalar ivars as objects is unsafe.
            if (rawType[0] != '@') continue;

            id value = object_getIvar(object, ivar);
            if (clipsNamed && value != nil) {
                if (matchedRule != NULL) *matchedRule = @"clips_or_sundial_ivar";
                SCIReelFilterLogIvarRule(objectClassName, name, typeEncoding, @"clips_or_sundial_ivar");
                free(ivars);
                return YES;
            }

            if (productTypeNamed && [value isKindOfClass:[NSString class]] && SCIStringIsExactReelProductType((NSString *)value)) {
                if (matchedRule != NULL) *matchedRule = @"product_type_ivar";
                SCIReelFilterLogIvarRule(objectClassName, name, typeEncoding, @"product_type_ivar");
                free(ivars);
                return YES;
            }
        }

        free(ivars);
    }

    return NO;
}

static BOOL SCIIsFeedReelMedia(id object, NSString **matchedRule) {
    if (object == nil) return NO;

    NSString *className = NSStringFromClass([object class]);
    if (SCIStringHasClipsOrSundialMarker(className)) {
        if (matchedRule != NULL) *matchedRule = @"clips_or_sundial_class";
        SCIReelFilterLogClassRule(className, @"clips_or_sundial_class");
        return YES;
    }

    NSArray<NSString *> *productTypeKeys = @[
        @"mediaProductType", @"media_product_type", @"productType", @"product_type"
    ];

    for (NSString *key in productTypeKeys) {
        id value = SCIReadKVCValue(object, key);
        SCIReelFilterLogPropertyRule(className, key, @"candidate_product_type_property");

        if ([value isKindOfClass:[NSString class]] && SCIStringIsExactReelProductType((NSString *)value)) {
            if (matchedRule != NULL) *matchedRule = @"product_type_property";
            SCIReelFilterLogPropertyRule(className, key, @"product_type_property");
            return YES;
        }
    }

    NSArray<NSString *> *metadataKeys = @[
        @"clipsMetadata", @"clips_metadata", @"clipsInfo", @"clips_info",
        @"sundialContext", @"sundial_context"
    ];

    for (NSString *key in metadataKeys) {
        id value = SCIReadKVCValue(object, key);
        SCIReelFilterLogPropertyRule(className, key, @"candidate_metadata_property");

        if (value != nil && value != [NSNull null] && SCIStringHasClipsOrSundialMarker(key)) {
            if (matchedRule != NULL) *matchedRule = @"clips_or_sundial_metadata_property";
            SCIReelFilterLogPropertyRule(className, key, @"clips_or_sundial_metadata_property");
            return YES;
        }

        if (SCIValueLooksLikeClipsMetadata(value)) {
            if (matchedRule != NULL) *matchedRule = @"clips_or_sundial_metadata_value";
            SCIReelFilterLogPropertyRule(className, key, @"clips_or_sundial_metadata_value");
            return YES;
        }
    }

    return SCIReadObjectIvarsForClipsMarkers(object, matchedRule);
}

static NSArray *removeItemsInList(NSArray *list, BOOL isFeed) {
    NSArray *originalObjs = list;
    NSMutableArray *filteredObjs = [NSMutableArray arrayWithCapacity:[originalObjs count]];

    for (id obj in originalObjs) {
        // Hide followed-account Reels in the home feed only. Stories, DMs,
        // Explore, profiles, and the dedicated Reels feed are not targeted here.
        if (isFeed && [SCIUtils getBoolPref:@"hide_all_feed_reels"]) {
            NSString *matchedRule = nil;
            if ([obj isKindOfClass:%c(IGMedia)] && SCIIsFeedReelMedia(obj, &matchedRule)) {
                SCIReelFilterLogClassRule(NSStringFromClass([obj class]), matchedRule ?: @"matched");
                continue;
            }
        }

        // Remove suggested posts
        if (isFeed && [SCIUtils getBoolPref:@"no_suggested_post"]) {

            // Posts
            if (
                ([obj isKindOfClass:%c(IGMedia)] && [((IGMedia *)obj).explorePostInFeed isEqual:@YES])
                || ([obj isKindOfClass:%c(IGFeedGroupHeaderViewModel)] && [[obj title] isEqualToString:@"Suggested Posts"])
            ) {
                NSLog(@"[SCInsta] Removing suggested posts");

                continue;
            }

            // Suggested stories (carousel)
            if ([obj isKindOfClass:%c(IGInFeedStoriesTrayModel)]) {
                NSLog(@"[SCInsta] Hiding suggested stories carousel");

                continue;
            }

        }

        // Remove suggested reels (carousel)
        if (isFeed && [SCIUtils getBoolPref:@"no_suggested_reels"]) {
            if ([obj isKindOfClass:%c(IGFeedScrollableClipsModel)]) {
                NSLog(@"[SCInsta] Hiding suggested reels carousel");

                continue;
            }
        }
        
        // Remove suggested for you (accounts)
        if ([SCIUtils getBoolPref:@"no_suggested_account"]) {
            
            // Feed
            if (isFeed && [obj isKindOfClass:%c(IGHScrollAYMFModel)]) {
                NSLog(@"[SCInsta] Hiding accounts suggested for you (feed)");

                continue;
            }

            // Reels
            if ([obj isKindOfClass:%c(IGSuggestedUserInReelsModel)]) {
                NSLog(@"[SCInsta] Hiding accounts suggested for you (reels)");

                continue;
            }
        }

        // Remove suggested threads posts
        if ([SCIUtils getBoolPref:@"no_suggested_threads"]) {

            // Feed (carousel)
            if (isFeed) {
                if ([obj isKindOfClass:%c(IGBloksFeedUnitModel)] || [obj isKindOfClass:objc_getClass("IGThreadsInFeedModels.IGThreadsInFeedModel")]) {
                    NSLog(@"[SCInsta] Hiding suggested threads posts (carousel)");

                    continue;
                }
            }

            // Reels
            if ([obj isKindOfClass:%c(IGSundialNetegoItem)]) {
                NSLog(@"[SCInsta] Hiding suggested threads posts (reels)");

                continue;
            }

        }        

        // Remove story tray
        if (isFeed && [SCIUtils getBoolPref:@"hide_stories_tray"]) {
            if ([obj isKindOfClass:%c(IGStoryDataController)]) {
                NSLog(@"[SCInsta] Hiding stories tray");

                continue;
            }
        }

        // Hide entire feed
        if (isFeed && [SCIUtils getBoolPref:@"hide_entire_feed"]) {
            if ([obj isKindOfClass:%c(IGPostCreationManager)] || [obj isKindOfClass:%c(IGMedia)] || [obj isKindOfClass:%c(IGEndOfFeedDemarcatorModel)] || [obj isKindOfClass:%c(IGSpinnerLabelViewModel)]) {
                NSLog(@"[SCInsta] Hiding entire feed");

                continue;
            }
        }

        // Remove ads
        if ([SCIUtils getBoolPref:@"hide_ads"]) {
            if (
                ([obj isKindOfClass:%c(IGFeedItem)] && ([obj isSponsored] || [obj isSponsoredApp]))
                || ([obj isKindOfClass:%c(IGDiscoveryGridItem)] && [[obj model] isKindOfClass:%c(IGAdItem)])
                || [obj isKindOfClass:%c(IGAdItem)]
            ) {
                NSLog(@"[SCInsta] Removing ads");

                continue;
            }
        }

        [filteredObjs addObject:obj];
    }

    return [filteredObjs copy];
}

// Suggested posts/reels
%hook IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    NSArray *filteredObjs = removeItemsInList(%orig, YES);

    // Remove loading spinner at end of feed (if 5 or less items in feed)
    NSUInteger arrayLength = [filteredObjs count];

    if (arrayLength <= 5) {
        filteredObjs = [filteredObjs filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
                return ![obj isKindOfClass:[%c(IGSpinnerLabelViewModel) class]];
            }]
        ];
    }

    return filteredObjs;
}
%end
%hook IGSundialFeedDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    NSArray *filteredList = removeItemsInList(%orig, NO);

    if ([SCIUtils getBoolPref:@"prevent_doom_scrolling"]) {
        double reelCount = [SCIUtils getDoublePref:@"doom_scrolling_reel_count"];
        return [filteredList subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)reelCount, filteredList.count))];
    }

    return filteredList;
}
%end
%hook IGContextualFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return removeItemsInList(%orig, NO);
    }

    return %orig;
}
%end
%hook IGVideoFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return removeItemsInList(%orig, NO);
    }

    return %orig;
}
%end
%hook IGChainingFeedViewController
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return removeItemsInList(%orig, NO);
    }

    return %orig;
}
%end
%hook IGStoryAdPool
- (id)initWithUserSession:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%hook IGStoryAdsManager
- (id)initWithUserSession:(id)arg1 storyViewerLoggingContext:(id)arg2 storyFullscreenSectionLoggingContext:(id)arg3 viewController:(id)arg4 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%hook IGStoryAdsFetcher
- (id)initWithUserSession:(id)arg1 delegate:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
// IG 148.0
%hook IGStoryAdsResponseParser
- (id)parsedObjectFromResponse:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
- (id)initWithReelStore:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%hook IGStoryAdsOptInTextView
- (id)initWithBrandedContentStyledString:(id)arg1 sponsoredPostLabel:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
%end
%hook IGSundialAdsResponseParser
- (id)parsedObjectFromResponse:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");

        return nil;
    }

    return %orig;
}
- (id)initWithMediaStore:(id)arg1 userStore:(id)arg2 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        NSLog(@"[SCInsta] Removing ads");
        
        return nil;
    }
    
    return %orig;
}
%end
// "Sponsored" posts on discover/search page
%hook IGExploreListKitDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return removeItemsInList(%orig, NO);
    }

    return %orig;
}
%end
// Demangled name: IGExploreViewControllerSwift.IGExploreListKitDataSource
%hook _TtC28IGExploreViewControllerSwift26IGExploreListKitDataSource
- (NSArray *)objectsForListAdapter:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return removeItemsInList(%orig, NO);
    }

    return %orig;
}
%end

// Hide shopping carousel in reel comments
// Demangled name: IGCommentThreadCommerceCarouselPill.IGCommentThreadCommerceCarousel
%hook _TtC35IGCommentThreadCommerceCarouselPill31IGCommentThreadCommerceCarousel
- (id)initWithFrame:(CGRect)frame pillText:(id)text pillStyle:(NSInteger)style {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return nil;
    }

    return %orig(frame, text, style);
}
%end

// Hide suggested search/shopping on reels

// Demangled name: IGShoppableEverythingCommon.IGRapEntrypointResolver
%hook _TtC27IGShoppableEverythingCommon23IGRapEntrypointResolver
- (id)initWithLauncherSet:(id)arg1 {
    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        return nil;
    }

    return %orig(arg1);
}
%end
// Demangled name: IGSundialOrganicCTAContainerView.IGSundialOrganicCTAContainerView
%hook _TtC32IGSundialOrganicCTAContainerView32IGSundialOrganicCTAContainerView
- (void)didMoveToWindow {
    %orig;

    if ([SCIUtils getBoolPref:@"hide_ads"]) {
        [self removeFromSuperview];
    }
}
%end


// Hide "suggested for you" text at end of feed
%hook IGEndOfFeedDemarcatorCellTopOfFeed
- (void)configureWithViewConfig:(id)arg1 {
    %orig;

    if ([SCIUtils getBoolPref:@"no_suggested_post"]) {
        NSLog(@"[SCInsta] Hiding end of feed message");

        // Hide suggested for you text
        UILabel *_titleLabel = MSHookIvar<UILabel *>(self, "_titleLabel");

        if (_titleLabel != nil) {
            [_titleLabel setText:@""];
        }
    }

    return;
}
%end
