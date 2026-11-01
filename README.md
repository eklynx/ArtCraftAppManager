<h1>
  <img src="ArtCraftAppManager/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="ArtCraft Application Manager icon" width="128" height="128" align="absmiddle">
  ArtCraft Application Manager
</h1>
## Description
This application manages the installation and updates of the ArtCraft suite of applications.

## Purpose
The Manager that ArtCraft distributes only handles the applications under the /Applications folder. I do not have the hard drive space on the built-in drive to support this; I need them installed on my second drive. This application manages the ArtCraft applications wherever they are installed, notifying and installing (when enabled) updated versions when they are available.

## Specifications
Detailed requirements live in [`docs/specs/`](docs/specs/README.md). The list of applications and where their releases live on GitHub is [`docs/registry/apps.json`](docs/registry/apps.json). Terms are defined in [`GLOSSARY.md`](GLOSSARY.md); design decisions are in [`docs/adr/`](docs/adr/).

## Interface
### Main window
The main window shows a list of ArtCraft suite applications that are enabled in the settings. If an application is installed, it shows the installed version number and gives you options to uninstall, run, or open its location, and if an update is available, an update button is enabled. If it is not installed, it gives you the option to install it, which lets you choose a location to install it to (defaults to /Applications). Each line in the list shows the application icon, name, currently installed version, and install location.
The bottom of the window has a 'status' line that shows any error or important status text.
### Settings
The settings window has the following options:
1. Default Install Location: the default location when you choose to install an application. Choose button brings up a folder picker. Defaults to `/Applications`.
2. Download File Location: the location it will download the .dmg files for updates. Choose button brings up a folder picker. Defaults to `~/Downloads`.
3. Choose Applications to Show: a list of all the ArtCraft suite applications (icons and names) with checkboxes. All applications checked will show in the main window.
4. Automatically Download Updates: a toggle. When on, it will automatically download updates to the download location. When off, if an updated version is detected, a notification will be triggered. Clicking on the notification will activate this application to show the option to update.
5. Automatically Install Updates: a toggle. When on (this also turns on Automatically Download Updates), if the application is closed, it will automatically install the updated version to the install location for the application. If the application is running, it will trigger a notification that says the update is ready to install but the application is running, and the update is installed as soon as the application quits. When the toggle is off, a notification is sent saying the update is ready to install; it can be installed from the main window once the application is not running.
6. Launch at login: a toggle (off by default). When on, the Manager starts at login without showing its window and adds a menu bar item showing available updates, with Open Manager, Check Now and Quit. Closing the main window then leaves the Manager running in the menu bar; when off, closing the window quits the Manager.

## Building and testing
Requires Xcode 27 on macOS 27. Open `ArtCraftAppManager.xcodeproj` and run the `ArtCraftAppManager` scheme, or from the command line:

```sh
xcodebuild test -project ArtCraftAppManager.xcodeproj -scheme ArtCraftAppManager -destination 'platform=macOS'
```

The unit tests (Swift Testing) are hermetic. The UI tests drive the real app, so leave the mouse and keyboard alone while they run. Steps that can't be automated are in [`docs/manual-verification.md`](docs/manual-verification.md). The app runs unsandboxed (see [`docs/adr/0001-sandbox-and-install-strategy.md`](docs/adr/0001-sandbox-and-install-strategy.md)).

## License
MIT — see [`LICENSE`](LICENSE).

## AI Usage Notes
AI was used heavily in the creation of this application.  I am using projects such as these to determine the best ways for my process to utilize AI tools to come up with clean code efficiently.