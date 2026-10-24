# App Store header and search artwork

The Japanese and English 4.0.0 product pages each use a dedicated header and
search image. The header introduces the brand; search shows the actual Analytics
screen and the benefit of tracking battery changes. The original screenshots use
the app's sample records, never a user's diagnostics or battery history.

## Reproduce the artwork

The two unmodified Analytics captures are committed in
`fastlane/store-assets/creative-source/`. They were captured alongside the 4.0.0
store screenshots on 2026-10-24. The icon comes from the existing Icon Composer
export in `icon/Icon Exports/`. The generator uses native AppKit drawing, preserves
the complete application screen, and does not redraw any values or labels.

```sh
swift scripts/compose-store-creative.swift \
  fastlane/store-assets/creative-source fastlane/store-assets/creative
```

For a later release, first replace the source images with fresh Japanese and
English `iphone_03_analytics.png` captures from
`scripts/capture-store-screenshots.py`. Keep their 1320×2868 pixel dimensions.

## Dimensions and cropping

| Surface | Final image | Centered art-safe rectangle, top-left coordinates |
| --- | --- | --- |
| Product page header | 3840×1646 | x=1097, y=493, width=1646, height=661 |
| Search results | 3840×2560 | x=836, y=765, width=2168, height=1030 |

These safe areas were measured from Apple's official Photoshop templates on
2026-10-24. The brand and short message stay within them. Search's first capacity
chart is also inside the safe area; the rest of the real screen provides context
when the surface displays more of the image. Final files are opaque, 8-bit RGB
PNGs with no alpha channel.

References:

- [Apple asset guidance](https://developer.apple.com/app-store/asset-best-practices/)
- [Apple creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)
- [Header template](https://developer.apple.com/go/?id=photoshop-product-page-header-template)
- [Search template](https://developer.apple.com/go/?id=photoshop-search-results-template)
- [Asset category API](https://developer.apple.com/documentation/appstoreconnectapi/appassetlibraryassetcategory)

## Register and verify

Run the **Inspect Store Assets** workflow with mode `upload-creative` and the
editable store version. Authentication stays in the existing Actions secrets.
The uploader reserves `CREATIVE_ASSETS`, checks Apple's processed image
specification, then places each image on the exact locale and surface.

Both creative surfaces use `DEFAULT_PROFILE`. Replacements must be scoped to the
individual placement type; deleting/reordering the entire group could remove the
other image. Screenshot groups and public-version placements are left untouched.
For a changed creative image, the uploader waits until Apple's processing has
finished before replacing the draft's old reference. It retains the old library
image and restores its reference if the new placement request fails.

Run **Prepare App Store release (no submission)** in `verify` mode. It checks the
selected build and metadata, all 40 screenshots including both Duo poses, and the
four creative placements against the committed image hashes. In App Store
Connect, use Preview for both locales and both surfaces to check actual cropping
and legibility. Uploading and verifying these assets never submits an App Review
or a TestFlight review. The user presses the review submission button.
