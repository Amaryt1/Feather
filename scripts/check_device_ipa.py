"""Check a device IPA before attempting installation. Full checks require macOS."""
import argparse
import datetime as dt
import fnmatch
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect(archive):
    names = archive.namelist()
    require(len(names) == len(set(names)), "Duplicate archive entries; rebuild from an empty archive.")
    require(all(not PurePosixPath(n).is_absolute() and ".." not in PurePosixPath(n).parts for n in names),
            "Invalid archive path.")
    plist_paths = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
    require(len(plist_paths) == 1, "Expected one main app under Payload.")
    info = plistlib.loads(archive.read(plist_paths[0]))
    app = plist_paths[0].rsplit("/", 1)[0]
    require("iPhoneOS" in info.get("CFBundleSupportedPlatforms", []), "Expected an iPhoneOS device build.")
    require({1, 2}.issubset(info.get("UIDeviceFamily", [])), "Expected iPhone and iPad support.")
    executable = info.get("CFBundleExecutable", "")
    require(executable and "/" not in executable and f"{app}/{executable}" in names, "Missing main executable.")
    require(any(n.startswith(app + "/Feather.momd/") and n.endswith(".mom") or n == app + "/Feather.mom"
                for n in names), "Missing compiled Feather Core Data model.")
    require(app + "/_CodeSignature/CodeResources" in names, "Missing code signature resource seal.")
    require(app + "/embedded.mobileprovision" in names, "No embedded profile for direct device distribution.")
    return app, info


def command(*args):
    return subprocess.check_output(args)


def verify_macos(path, root, info, udid):
    require(sys.platform == "darwin", "Full signature and Mach-O verification requires macOS.")
    with tempfile.TemporaryDirectory() as temp:
        command("/usr/bin/ditto", "-x", "-k", path, temp)
        app = Path(temp, root).resolve()
        command("codesign", "--verify", "--deep", "--strict", app)
        profile = plistlib.loads(command("security", "cms", "-D", "-i", app / "embedded.mobileprovision"))
        now = dt.datetime.now(dt.timezone.utc)
        require(profile["ExpirationDate"].replace(tzinfo=dt.timezone.utc) > now, "Expired profile.")
        require(profile.get("ProvisionsAllDevices") or profile.get("ProvisionedDevices"),
                "This profile does not allow direct installation on registered devices.")
        if udid and not profile.get("ProvisionsAllDevices"):
            require(udid.lower() in {s.lower() for s in profile.get("ProvisionedDevices", [])}, "Device not provisioned.")
        ent = plistlib.loads(command("codesign", "-d", "--entitlements", ":-", app))
        app_id = ent.get("application-identifier", "")
        allowed = profile["Entitlements"]
        require(app_id.partition(".")[2] == info["CFBundleIdentifier"] and
                fnmatch.fnmatchcase(app_id, allowed["application-identifier"]), "Signed app ID and profile disagree.")
        require(not ent.get("get-task-allow") or allowed.get("get-task-allow"), "Debug entitlement denied by profile.")
        cert = Path(temp, "cert")
        command("codesign", "-d", "--extract-certificates=" + str(cert), app)
        require(Path(str(cert) + "0").read_bytes() in profile["DeveloperCertificates"], "Signing certificate not in profile.")
        main = app / info["CFBundleExecutable"]
        seen = set()

        def check_binary(binary, inherited):
            if binary in seen:
                return
            seen.add(binary)
            listing = command("otool", "-arch", "arm64", "-l", binary).decode()
            require(re.search(r"platform\s+(2|IOS|iOS)\b", listing) or "LC_VERSION_MIN_IPHONEOS" in listing,
                    "Expected arm64 device Mach-O: " + binary.name)
            def expand(s):
                return s.replace("@executable_path", str(app)).replace("@loader_path", str(binary.parent))
            rpaths = [expand(p) for p in re.findall(r"cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset", listing)]
            rpaths += inherited
            for dep in re.findall(r"cmd LC_(?:LOAD_DYLIB|REEXPORT_DYLIB|LOAD_UPWARD_DYLIB)\s+cmdsize \d+\s+name (.*?) \(offset", listing):
                if dep.startswith(("/usr/lib/", "/System/Library/")):
                    continue
                candidates = [dep.replace("@rpath", p, 1) for p in rpaths] if dep.startswith("@rpath/") else [expand(dep)]
                if dep.startswith("@rpath/libswift") and any(p.startswith("/usr/lib/swift/") for p in candidates):
                    continue
                bundled = next((Path(p).resolve() for p in candidates if Path(p).is_file() and Path(p).resolve().is_relative_to(app)), None)
                require(bundled is not None, "Missing strong dependency of " + binary.name + ": " + dep)
                check_binary(bundled, rpaths)
        check_binary(main, [])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--udid")
    parser.add_argument("--structure-only", action="store_true")
    args = parser.parse_args()
    try:
        with zipfile.ZipFile(args.ipa) as archive:
            root, info = inspect(archive)
        if not args.structure_only:
            verify_macos(args.ipa.resolve(), root, info, args.udid)
        print("PASS:", "archive structure" if args.structure_only else "structure, signature, profile and main executable dependencies",
              "| minimum OS:", info.get("MinimumOSVersion", "unknown"))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException, subprocess.CalledProcessError) as exc:
        sys.exit("IPA verification failed: " + str(exc))
