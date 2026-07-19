# Feed Reel Filter

## Architecture

The `hide_all_feed_reels` setting is handled in `src/Features/Feed/HideFeedItems.xm`.
Filtering is limited to objects returned by `IGMainFeedListAdapterDataSource` and only
removes `IGMedia` items from the home feed path. It does not hook all `IGMedia`
instances globally, so Stories, Direct Messages, profile grids, search, contextual
feeds, and the dedicated Reels feed are outside this filter.

The classifier is conservative. It accepts strong Instagram-internal Reel markers:

- class names containing `Clips` or `Sundial`
- exact product-type values `clips`, `reels`, `reel`, or `sundial`
- non-null values under explicitly Clips/Sundial metadata properties
- object ivars named for `clips`, `sundial`, or product type when they are safe
  Objective-C object ivars

The classifier intentionally does not classify based on generic `reel` substrings in
class or ivar names because Instagram also uses Reel terminology for Stories.

## Settings

- `hide_all_feed_reels`: default off. Removes followed-account Reel media from the
  home feed while preserving photos, carousels, ordinary feed videos, Stories, DMs,
  profiles, and search.
- `reel_filter_diagnostics`: default off. Enables privacy-safe diagnostics for
  classifier development.

Existing SCInsta settings continue to operate independently. In particular,
`no_suggested_reels` still removes the suggested Reels carousel, `hide_reels_tab`
still hides the navigation tab, and `disable_scrolling_reels` still blocks vertical
Reels chaining.

## Diagnostic Output

Diagnostics are prefixed with `[SCInsta][ReelFilter]` and are emitted only when
`reel_filter_diagnostics` is enabled. They may include:

- Objective-C class names
- candidate selector/property names
- candidate ivar names and type encodings
- the classifier rule that matched

Diagnostics must never include captions, usernames, media IDs, URLs, cookies,
request headers, tokens, message content, object descriptions, or other user data.

## Known Limitations

Instagram class and property names change frequently. A future app version may move
Reel markers to different properties, which can cause followed-account Reels to remain
visible until diagnostics identify a new safe marker. Direct Reel links may still open
their first item; vertical chaining remains controlled by the existing
`disable_scrolling_reels` setting.
