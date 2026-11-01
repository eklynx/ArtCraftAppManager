# 06 — Notifications and Auto-Update (`NOT`)

## Notification kinds
| Kind | When |
|---|---|
| `updateAvailable` | A newer Release is found and Auto Download is off |
| `updateReady` | An update is downloaded and Auto Install is off (or cannot proceed) |
| `updateReadyAppRunning` | An update is downloaded, Auto Install is on, but the App is running |
| `updateInstalled` | An automatic install finished |

## Requirements
- **REQ-NOT-1** The Manager requests notification permission on first launch. If denied, all notification kinds degrade to the menu bar badge / row state, and Settings shows a hint with a link to System Settings.
- **REQ-NOT-2** Clicking any notification activates the Manager and brings the relevant App's row into view.
- **REQ-NOT-3** At most one notification per App **per version per kind** is sent; sent versions are stored in the state file so restarts do not repeat them.
- **REQ-NOT-4** Behaviour matrix, evaluated after a check finds a newer Release for an installed App (never for "no longer in registry" or not-installed Apps):

| Auto Download | Auto Install | App running? | Result |
|---|---|---|---|
| off | off | – | `updateAvailable`; user clicks Update |
| on | off | – | Download; then `updateReady` |
| on | on | no | Download, install, `updateInstalled` |
| on | on | yes | Download; `updateReadyAppRunning`; install automatically when the App quits (REQ-NOT-5) |

(Auto Install on implies Auto Download on — REQ-SET-4; the combination off/on cannot occur.)
- **REQ-NOT-5** For `updateReadyAppRunning` the Manager observes App termination (`NSWorkspace` notifications). When the App quits and Auto Install is still on, the install runs immediately and `updateInstalled` is sent. If the Manager quits first, the install happens on the next launch/check once the App is not running.
- **REQ-NOT-6** Automatic downloads/installs honour all rules in [03](03-install-update.md) (checksum, safe replace) and report failures to the status line and, if the window is hidden, via a notification-less badge on the menu bar icon.
- **REQ-NOT-7** Scheduled checks run only while the Manager is running (REQ-REG-12). With "Launch at login" on that is effectively always; a separate background agent is out of scope for v1.
- **REQ-NOT-8** Notification posting goes through the `UpdateNotifying` protocol so tests can capture it.
