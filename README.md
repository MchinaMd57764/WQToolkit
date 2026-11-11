# WQToolkit

An iOS toolkit built on an App Group container-query primitive. It gives you a real file browser and maintenance panel for your own app containers, without a jailbreak and without a Mac at runtime.

Bilingual UI (Chinese / English), light and dark themes, iPhone and iPad layouts.

## Download

- **[Latest release](https://github.com/MchinaMd57764/WQToolkit/releases/latest)** — IPA and source attached.
- **[WQToolkit-unsigned.ipa](https://github.com/MchinaMd57764/WQToolkit/raw/main/WQToolkit-unsigned.ipa)** — 4.6 MB, unsigned build.
- **[WQToolkit_source.tar.gz](https://github.com/MchinaMd57764/WQToolkit/raw/main/WQToolkit_source.tar.gz)** — source snapshot.

The IPA contains no signing material. Re-sign it with your own developer identity and an App Group entitlement before installing; every sideloading tool does this step. If you only want to read the code, browse `worse_query/` instead.

## Features

- **File browser** — browse, copy, move, rename, delete, archive and share files inside the app's own data container and its App Group containers.
- **Cache scan** — walks your own containers plus shared group containers, shows what is taking space, lets you clean it.
- **Device info** — model, chip, OS build, storage, display and other read-only values.
- **MobileGestalt cache panel** — read values from the on-device MobileGestalt cache and apply a whitelisted subset back to its cache copy (for example region-related keys). Always reversible from backups the app makes before writing.
- **Lenses** — storage map, timeline, media extractor, preferences inspector and a shared-group scanner that present the same container data from different angles.
- **Import / export** — export a list of your installed apps and re-import it after a reinstall.

## What it can and cannot do

The primitive resolves **your own** data container and **your own** App Group containers, then obtains a sandbox extension for them. That is enough for a full file manager over your own data.

It does **not** grant access to other apps' containers. On current iOS, container lookups for another app's bundle identifier or another team's group are refused by the container manager itself, so the app never tries to hide that: cross-app access is out of scope.

Everything runs on-device. There is no network backend, no account, no analytics.

## Requirements

- iOS 27 (arm64). Built, installed and exercised on iOS 27.x.
- Your own Apple Developer signing identity.
- An App Group you own.

## Build

1. Open `worse_query.xcodeproj` in Xcode.
2. Select the `worse_query` target → Signing & Capabilities:
   - set your **Team**,
   - add an **App Groups** capability with a group you own,
   - point the `APP_GROUP_ID` build setting at that group.
3. Build and install to your device.

The app needs the App Group because the primitive stages a symlink inside its own group container before querying it.

## Repository layout

```
worse_query/               Swift + Objective-C sources
worse_query.xcodeproj      Xcode project
WQInfo.plist               Info.plist merged at build time
WQToolkit-unsigned.ipa     unsigned build (no profile, no signature)
WQToolkit_source.tar.gz    snapshot of the sources
```

`WQToolkit-unsigned.ipa` contains no signing material. Re-sign it with your own identity and an App Group entitlement before installing — every sideloading tool does this step.

## Notes

- Builds with `#if DEBUG` include on-device probe screens used during development. Release builds exclude them.
- Back up anything you care about before using the write features, especially the MobileGestalt panel.
- This is a personal-use tool for devices you own.

## Credits

- The container-query primitive follows the approach published in [forcequitOS/worse_query](https://github.com/forcequitOS/worse_query).
- Some region presets are derived from [huamidev/GestaltX](https://github.com/huamidev/GestaltX).
