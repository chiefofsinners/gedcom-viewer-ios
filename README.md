# GEDCOM Viewer

A native SwiftUI iOS app for browsing GEDCOM genealogy files. Open a `.ged` file from Files, iCloud Drive, or any document provider, and navigate the family tree by individual, family, and timeline.

## Features

- **Pure native iOS** — SwiftUI + Swift Concurrency, no third-party runtime dependencies.
- **Three-tab navigation** — Home, alphabetical Index, and Family relationship view.
- **Adaptive layout** — Native `TabView` on iPhone, custom horizontal tab bar on iPad.
- **Robust GEDCOM parsing** — Line-by-line state machine handles individual events (BIRT, DEAT, BAPM, RESI, OCCU, etc.), family events (MARR), and non-standard variants.
- **Encoding auto-detection** — UTF-8, UTF-16, Windows-1252, ISO-8859-1, MacOS Roman, and ANSEL. BOM and declared charset are both consulted before falling back.
- **Multiple marriages, custom event tags, GIVN/SURN sub-tags** — supported.
- **Cloud-friendly** — Security-scoped bookmarks for persistent access; `NSFileCoordinator` for iCloud and other document providers.
- **23 languages** — Full localization including plural forms (`Localizable.stringsdict`).
- **Theming** — Two color palettes (Earth and Silver) with 16 semantic colors.

## Requirements

- Xcode 16 or newer
- iOS 16.4+ (deployment target)
- Swift 5

## Building

The Xcode project lives at `GEDCOM Viewer.xcodeproj` with a single scheme, `GEDCOM Viewer`.

```bash
# Build
xcodebuild build -scheme "GEDCOM Viewer" -configuration Debug -project "GEDCOM Viewer.xcodeproj"

# Run all tests (unit + UI)
xcodebuild test -scheme "GEDCOM Viewer" -configuration Debug -project "GEDCOM Viewer.xcodeproj"
```

In Xcode, open `GEDCOM Viewer.xcodeproj`, set your own development team under the target's **Signing & Capabilities** tab, then ⌘R.

A sample file (`Resources/Sample-GEDCOM.ged`) is bundled with the app so you can try the viewer without your own data.

## Architecture

SwiftUI app using MVVM:

```
GEDCOM file → GedcomTextDecoder (encoding detection) → GedcomParser (state machine)
            → GedcomData (individuals + families) → GedcomViewModel → SwiftUI Views
```

### Layers

**Model** (`GEDCOM Viewer/Model/`)
- `GedcomParser` — Line-by-line state machine. Builder pattern for incremental construction.
- `GedcomTextDecoder` — Encoding auto-detection (BOM → declared charset → fallback).
- `GedcomData` — Container for parsed `Individual` and `Family` records with sorting and lookup.
- `Individual`, `Family`, `LifeEvent`, `TimelineEntry` — Immutable, `Hashable` records.

**ViewModel** (`GEDCOM Viewer/ViewModel/`)
- `GedcomViewModel` — Single `@MainActor` observable. Immutable state updates via copy-modify-reassign on a `GedcomUIState` struct.

**Views** (`GEDCOM Viewer/Views/`)
- `ContentView` — Root with three-tab navigation.
- `IndexTabView` — Searchable alphabetical list of individuals.
- `FamilyView` — Parents, spouse, children for a selected individual.
- `IndividualDetailSheet` — Modal with full timeline and notes.
- `Components/` — Shared `PersonViews`, `Controls`, `MiscViews`.

**Theme** (`Color+Theme`) — Two palettes with 16 semantic colors, persisted to `UserDefaults`.

## Localization

23 languages are supported via `Localizable.strings` (and `Localizable.stringsdict` for plurals) in `Resources/`. Use `Text("key")` in SwiftUI and `String(localized:defaultValue:bundle:)` in imperative code. See [`LOCALIZATION.md`](LOCALIZATION.md) for the full guide on adding a language.

## Testing

- **Unit tests** (`GEDCOM ViewerTests/`) — Swift Testing framework.
- **UI tests** (`GEDCOM ViewerUITests/`) — XCTest. Views expose accessibility identifiers for test reliability.

The unit suite validates the parser against reference GEDCOM files; the UI suite walks the full user flow (home → sample load → index search → person selection → family view → detail sheet).

## Releasing (fastlane)

Fastlane lanes are provided for App Store workflows but are intentionally not committed — they contain account-specific identifiers. Place your own `Appfile`, `Fastfile`, `Snapfile`, and `Deliverfile` under `fastlane/` (they are git-ignored) and run, for example:

```bash
fastlane ios release_build              # Build & upload binary
fastlane ios screenshots                # Generate localized screenshots
fastlane ios link_build build_number:N  # Link a build to an App Store version
```

A Ruby toolchain plus `bundle install` (using the supplied `Gemfile`) is required.

## Contributing

Issues and pull requests are welcome. For non-trivial changes, please open an issue first to discuss the direction.

## License

[MIT](LICENSE) © Alun Lewis
