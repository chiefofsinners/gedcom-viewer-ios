# Localization Guide

The app now centralizes every user-facing string inside `GEDCOM Viewer/Resources/Base.lproj/Localizable.strings` and `Localizable.stringsdict`. SwiftUI views and the parser load copy through `LocalizedStringKey`, `String(localized:)`, or `NSLocalizedString` (for formatted/plural text). Follow these steps to keep translations in sync.

## Add a new language
1. In Finder or Xcode, duplicate `Base.lproj` inside `GEDCOM Viewer/Resources` and rename it to the desired locale (e.g. `fr.lproj`).
2. Translate every entry in the new `Localizable.strings` (and `Localizable.stringsdict` if plurals are required). Keep the keys identical; only change the values.
3. In Xcode, open the project settings (Project navigator → select **GEDCOM Viewer**) and add the new language under **Project > Info > Localizations** so Interface Builder knows about it.
4. Rebuild the app and run with **Scheme > Options > Application Language** set to the new locale to verify.

## Updating or adding strings
- Prefer creating a new key instead of hard-coded literals. Use `Text("some.key")` for SwiftUI labels and `String(localized: "some.key", defaultValue: "English text")` for imperative code.
- When a string needs interpolation or special formatting, use `%@`, `%d`, etc. in the `.strings` entry and call `String(format:locale: …)` or `String.localizedStringWithFormat` in code.
- For plural logic (e.g. counts), add an entry to `Localizable.stringsdict`. See `family.children.title` for an example of zero vs. non-zero forms.
- Keep translator comments (`/* ... */`) up to date to explain context.

## Testing
- Run `Product > Scheme > Edit Scheme > Options` and override the Application Language to inspect each translation at runtime.
- `rg -n '"[^"]*[A-Za-z][^"]*"' -g'*.swift'` is a handy check for stray literals before shipping.
- When changing keys, search the entire workspace to update every reference and regenerate translations before release.

Following this flow keeps the Base strings authoritative and ensures every market gets the same experience.
