# Building and checking a device IPA

For an app already built and signed for direct device installation, run on the Mac:

```sh
bash scripts/package-device-app.sh "$HOME/Desktop/Feather.app" "$HOME/Desktop/AMARYT-STORE.ipa"
```

This creates a fresh archive and replaces the destination only after verification. Updating an existing zip can retain resources or frameworks from an older build. Repackaging cannot change a simulator build, an ad-hoc linker signature, or a profile that excludes the device into a valid device-signed application.

To build from source, initialize submodules and supply the bundle ID, signing team and ExportOptions.plist for your development or registered-device distribution. The Apple signing account must be configured in Xcode. Use a new output directory.

```sh
git submodule update --init --recursive
DEVELOPMENT_TEAM=TEAM_ID BUNDLE_ID=com.example.store bash scripts/export-device-ipa.sh ExportOptions.plist ./device-build
```

The Makefile's `iphoneos` artifact is for workflows that subsequently sign it. For the actual final IPA, run `python3 scripts/check_device_ipa.py MyStore.ipa --udid DEVICE_UDID` on macOS. This checks the embedded profile, signer, resource seal, main device binary, its strong bundled dependencies and the compiled database model. Compare the reported MinimumOSVersion with the installed OS. Certificate revocation, OS trust decisions and execution on device still require a real-device test.

For an immediate exit, capture the device Console around the tap or export the app's .ips file from Analytics Data. Keep the matching Xcode archive and dSYM. The termination namespace and first crashed-thread frames distinguish launch rejection, a missing image, a watchdog termination and an exception after process startup. The store emits `store.root.appeared` under the Feather / Startup log category after its persistent store opens. A disconnected network should still allow this marker.
