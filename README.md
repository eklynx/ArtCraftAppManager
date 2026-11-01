# ArtCraft Application Manager
## Description
This applicarions managers the instalation and updates of the ArtCraft suite of applications.

## Purpose
The Manager that ArtCraft distributes only handles the applications under the /Applications folder. I do not have the hard drive space on the built in drive to support this; I need them intstalled on my second drive.  This application managers the ArtCraft applications wherever they are installed, notifying and installing (when enabled) updated versions when they are available.

## Interface
### Main window
The main window shows a list of Arcraft suite applications that are enabled in the settings. If the applications are installed, it will show the version number that is installed and give you options to uninstall, run, or open location, and if an update is available, an update button will be enabled.  If it is not installed, it will give you the option to install it, which will let you choose a location to install it to (defaults to /Applications).  Each line in the list Will show the Application Icon, Name, Currently installed version, and Install location. 
The bottom of the window has a 'status' line that shows any error or important status text.
### Settings
The settings window has the following options:
1. Default Install Location: the default location when you choose to install an application.  Choose button brings up a folder picker.  Defaults to `/Applications
2. Download File Location: the location it will download the .dmg files for updates.  Choose button brings up a folder picker. Defaults to `\~/Downloads`.
3. Choose Applications to Show: a list of all the Artcraft suite applications (icons and Names) with checkboxes.  All applications checked will show in the main window.
4. Automatically Download Updates: a toggle.  When on, it will automatically download updates to the download location.  When off, if an updated version is detected, a notification will be triggered.  Clicking on the notification will active this application to show the option ot update.
5. Automatically Install Updates: a toggle.  When on, if the application is closed, it will automatically install the updated version to the install location for the application.  If the application is running, it will trigger a notification that will say that the update is ready to install but the Application is running.   When the toggle is off, a notification is sent saying it is ready to install.


