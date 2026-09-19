# Xcode 27 RC / iPhone Duo readiness

September 19 follow-up: see [native Duo simulator verification with Xcode 27.1](iphone-duo-27.1.md). The notes below preserve the earlier size-only checks.

Environment checked: Xcode 27.0 RC, build 27A266a. Deployment target remains unchanged.

## RC review

Reviewed Apple's [Xcode RC notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) and [iOS / iPadOS RC notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes).

- The app already has a UIKit scene lifecycle. It does not need a lifecycle rewrite for SDK 27.
- The three selected tab values correspond to visible tabs; there are no hidden selections to migrate.
- The app does not use the new document protocols/factories affected by beta-to-RC signature changes.
- RC compilation exposed actor-isolation warnings in the shared date parser. Its static formatters are now explicitly nonisolated; the existing lock still serializes all formatter access. Concurrent parsing is covered by `bash scripts/test-log-dates.sh`.
- Do not treat changes listed as OS fixes as a reason to rewrite unrelated app code.

## Flexible layout changes

Reference: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) and the [user-supplied article](https://zenn.dev/d_date/articles/d874e248ac7851).

- A regular-width iPhone can use the wide home layout; narrow iPhones retain the compact log list.
- Settings only shows the category column when both columns have usable space. Its sidebar width scales with the available width.
- Analysis charts can sit side by side in a regular-width region with enough room for their controls. Narrow regions and accessibility text sizes use one column.
- iPhone chart ranges remain shared; iPad chart ranges remain independent, as previously requested. This is a behavior preference, not a screen-size assumption.
- Detail layout considers its own available width and text size. Sharing lives in the standard toolbar in both layouts.
- An open detail sheet and share sheet no longer have their presentation bindings gated by size class, so a resize does not request dismissal.
- Wide home cards route selection through the parent navigation destination, preserving the selected log when the card layout is replaced during a resize.
- Info popovers use the presenting window's safe-area height instead of `UIScreen.main`.

## Approximation test

Only a Debug simulator build with `MOCHI_LAYOUT_TEST=1` enables the validation host. It displays the actual app views at 800×1120 (the requested 1:1.4 ratio), 390×844, and 980×700. These are test dimensions, **not confirmed iPhone Duo point dimensions**. The host also changes the SwiftUI size class without changing the device idiom.

Run `LanguageAndLayoutTests/testDuoAspectRatioAndResize` using the `MochiLogUITests` scheme on a large iPad simulator. Screenshots are attached to the test result. Keep SDK selection automatic so the companion watch target builds against watchOS, not iOS.

## Verification on September 12, 2026

- Release build succeeded with Xcode 27 RC.
- Date parsing checks passed, including 1,000 concurrent parses.
- The approximation UI test passed on iPad Pro 13-inch (M5), iOS 27 RC (24A434), with no runtime warnings reported by the test result. It visits Home, Analytics, and Settings and verifies that a selected log remains open across wide → compact → wide resizing. Wide and compact detail screenshots were also visually checked.
- The standard Home / Analytics / Settings UI test passed on iPhone 18 Pro, iOS 27 RC (24A434), without the approximation host. Its home assertion checks a visible log row instead of assuming a specific device's section is already materialized by the lazy list.

## Still requires Xcode 27.1 and device validation

The dedicated Duo simulator, hinge poses, asymmetric device safe areas, camera occlusion, reserved regions, and vertical system bars cannot be validated by this size-only host. No unavailable 27.1 API or guessed hinge inset is included. On 27.1, test unfolding/folding while a detail, share sheet, editor, and keyboard are open; verify scroll positions, focus, and chart ranges. Inspect the phone idiom separately from this iPad-hosted approximation.
