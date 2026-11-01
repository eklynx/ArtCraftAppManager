# Glossary

**Manager**: This application; installs, updates, runs and uninstalls Apps of the Suite.

**Suite**: The family of ArtCraft desktop applications published by the `storytold` GitHub organisation.

**App**: One application of the Suite (e.g. GridCraft). _Avoid_: product, program.

**Registry**: The list of Apps and where each one's Releases live on GitHub (`apps.json`).

**Release**: A published, non-draft, non-prerelease GitHub release of an App, carrying a macOS disk image.

**Installed copy**: An `.app` bundle of an App found on a local volume; identified by its bundle ID.

**Install Location**: The folder containing an App's installed copy. Per App; chosen at install time.

**Default Install Location**: The folder offered when installing an App. Defaults to `/Applications`.

**Download Location**: The folder where disk images are downloaded.

**Update**: A Release whose version is strictly newer than the installed copy's. States: _available_ (found), _downloaded_ (disk image present and verified), _ready_ (downloaded and waiting for install).

**Enabled App**: An App ticked in Settings and therefore shown in the main window.

**Launch at login**: Setting that starts the Manager at login without showing its window and adds a menu bar item.
