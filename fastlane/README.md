fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate new localized screenshots on every device and upload them

### ios device_screenshots

```sh
[bundle exec] fastlane ios device_screenshots
```

Capture screenshots on the Snapfile's devices and the iPhone Duo, in every Snapfile language (no upload)

### ios duo_screenshots

```sh
[bundle exec] fastlane ios duo_screenshots
```

Capture iPhone Duo screenshots only (no upload)

### ios release_notes

```sh
[bundle exec] fastlane ios release_notes
```

Upload text metadata (release notes etc.) only - no binary, no screenshots

### ios release_build

```sh
[bundle exec] fastlane ios release_build
```

Build and upload to App Store (Binary only)

### ios link_build

```sh
[bundle exec] fastlane ios link_build
```

Link a specific build to the App Store version without submitting

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
