# Resources And Connect Screenshot Design QA

## Source

- Reference: the ten Figma screenshots supplied by the product owner on 2026-07-22.
- Implementation captures: `/private/tmp/daniel-resources-final.png` and `/private/tmp/daniel-connect-final.png` from iPhone 17 / iOS 26.3 Simulator.
- Comparison: the Resources overview and signed-out Connect state were inspected side by side with their corresponding reference screenshots at the same mobile form factor.

## Result

final result: passed

## Verified Alignment

- Resources follows the reference hierarchy: warm orange header, language/account controls, search, one full-width Hymnbook feature card, compact two-column directory cards, and a calm white/cream surface.
- Connect follows the reference hierarchy: church/Connect header, three text tabs with a thin orange selection underline, member-access card, and the same bottom navigation language.
- Card borders, corner radii, spacing, orange emphasis, and typography hierarchy remain consistent with the existing Daniel App design tokens.
- Chinese, English, and Korean header/tab/access states were switched live in the Simulator.
- Resource search, directory navigation, Hymnbook detail, and the full-screen no-media reader state are reachable and expose accessibility labels.

## Intentional Product Differences

- Connect does not implement the Figma feed, likes, comments, posting, or native chat. Canada pilot v1 keeps Announcements, Newsletter, and the protected KakaoTalk link.
- Resources keeps shared Church Documents and native Bible Reader/Favorites because they are working product capabilities, even where the reference overview uses a different four-card sample.
- Real Hymn PDF/audio is not fabricated. The reader supports both media types together and now explains accurately when neither, one, or both media files are configured.

## Remaining Follow-up

- Repeat the active-member Connect capture after a real pilot church, admin approval, newsletter, and KakaoTalk URL are configured.
- Confirm pinch zoom and audio/PDF coexistence on a physical TestFlight device using licensed church media.
