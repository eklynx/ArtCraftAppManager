# Glossary

**Manager**: This application; installs, updates, runs and uninstalls Apps of the Suite.

**Suite**: The family of ArtCraft desktop applications published by the `storytold` GitHub organisation.

**App**: One application of the Suite (e.g. GridCraft). _Avoid_: product, program.

**Community App**: An App that is listed in ArtCraft's own launcher but published by another GitHub organisation (e.g. SolidCraft by `tangency-labs`). It is an App like any other in the Manager.

**Registry**: The list of Apps and where each one's Releases live on GitHub (`apps.json`).

**Release**: A published, non-draft, non-prerelease GitHub release of an App, carrying a macOS disk image.

**Installed copy**: An `.app` bundle of an App found on a local volume; identified by its bundle ID.

**Install Location**: The folder containing an App's installed copy. Per App; chosen at install time.

**Default Install Location**: The folder offered when installing an App. Defaults to `/Applications`.

**Download Location**: The folder where disk images are downloaded.

**Update**: A Release whose version is strictly newer than the installed copy's. States: _available_ (found), _downloaded_ (disk image present and verified), _ready_ (downloaded and waiting for install).

**App order**: The user's chosen order of Apps. It sets the order of rows in the main window and of lines in the menu bar menu; the default is the Registry's order.

**Enabled App**: An App ticked in Settings and therefore shown in the main window.

**Launch at login**: Setting that starts the Manager at login without showing its window and adds a menu bar item.

**Updated by Manager**: The date the Manager last installed or updated a given version of an App.

**Release date**: The date a Release was published on GitHub.

**Cached icon**: A copy of an App's icon downloaded from GitHub and kept locally, shown while the App is not installed.

**Manager release**: A tagged, signed and notarized build of the Manager, published as a disk image on the Manager's own GitHub releases. _Avoid_: Release (that term is for Apps).

**Nightly build**: A signed and notarized build of the Manager's `main` branch, published as a GitHub pre-release and kept only for the latest seven. Not a Manager release.

**Manager update**: A newer Manager release, pre-release or Nightly build offered to the running Manager through Sparkle. _Avoid_: Update (that term is for Apps).

**Feed**: The Sparkle appcast listing Manager builds, hosted on GitHub Pages.

**Release channel**: The default Manager update channel; offers Manager releases only.

**Pre-release channel**: Offers Manager releases and GitHub pre-releases whose tag does not start with `nightly-`.

**Nightly channel**: Offers everything, including Nightly builds.

