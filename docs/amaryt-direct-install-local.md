# AMARYT Direct Install (local)

Select Settings → Installation → AMARYT Direct Install (value 2). Existing selections Server (0) and IDevice (1) keep their current routes. The local path downloads from the selected HTTPS source with URLSessionDownloadTask, signs using the selected local Feather identity, archives the signed app and waits for Install Now. Import to Library remains a separate action. The API catalog already opens the standard source detail screen. There is no remote install service, upload, online configuration or GitHub dependency at runtime.

## Device setup

In the AMARYT installation settings export the public mobileconfig to On My iPhone/iPad. Open it and install the downloaded profile in Settings. In General → About → Certificate Trust Settings enable full trust for that device's AMARYT root. The profile contains only the public root. Each installation creates a distinct EC authority and loopback leaf; the authority private key is discarded after issuance. Only the leaf private key and public certificates are stored together in a device-only Keychain item. The signed application uses a separate, eligible signing identity and provisioning profile. This project supplies neither a distribution identity nor permission to distribute third-party apps.

The leaf certificate covers the literal IP 127.0.0.1 and lasts 180 days. On expiry, remove the old profile, renew the identity in AMARYT settings, then export, install and trust the new profile. Managed devices may prohibit local profile installation. Removing the profile revokes local HTTPS trust. Changing the local installer preference does not uninstall apps.

## Handoff and limitations

A dedicated TLS listener binds to IPv4 loopback on a random port and exposes the manifest and signed IPA under an unguessable per-operation path. A system-trusted URLSession GET must return the exact generated manifest before the app enables Install Now. No trust override, DNS hostname or remote certificate pack is used. The user explicitly opens itms-services and the system chooses whether to prompt and proceed. Keep the store available while iOS fetches. The view reports a package request if its local route is called. An accepted URL and a completed file transfer are insufficient evidence of installation. The user ends sharing explicitly. iOS may suspend or terminate the store despite a finite background task.

Apple documents HTTPS OTA distribution for eligible in-house apps. It does not guarantee an app-hosted loopback manifest on every iOS release. An app-level trust probe cannot establish the installer daemon's reachability or acceptance. Declining the prompt, profile eligibility, device policy, trust and process suspension can prevent completion after handoff. There is no silent fallback to an external server or to IDevice.

## Resources

Download and archive output are file-backed. The UI uses actual received bytes and expected length, when supplied; brief interruptions can retry with system resume data when provided. Unknown lengths display bytes and indeterminate progress. Retrying after closing the operation starts a fresh download. Disk checks use current available capacity during download and before copying or archiving. Decompression and signing also require working space and can still fail mid-operation. Device storage, archive library support and iOS execution lifetime determine practical limits. There is no relay size cap, session pool or fixed file expiry. Cancel closes the operation and cleans temporary copies once any in-flight native signing/archiving call unwinds.

## Verification

CI runs Swift policy/handoff checks, tests real TLS trust using the same certificate generator and builds for generic iOS. For physical acceptance, record the device/OS, provision type, byte count and free space. Use a distributable test app and both source browsing interfaces. Check download percentage and speed, interrupted download, missing certificate, cancellation during signing, and both trust-enabled and trust-disabled cases. Confirm no installer prompt before Install Now. Observe the OS prompt, allow it, confirm the local IPA request and open the installed app from the Home Screen. Repeat with the prompt declined. Exercise a large IPA, archive sharing, import-to-library and both legacy install types. A successful build or desktop TLS test does not replace these results.

References: [Apple OTA deployment](https://support.apple.com/guide/deployment/depce7cefc4d/web) and [manual certificate trust](https://support.apple.com/en-us/102390).
