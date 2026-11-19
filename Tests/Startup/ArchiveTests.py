import io
import plistlib
import sys
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from check_device_ipa import inspect


class ArchiveTests(unittest.TestCase):
    def sample(self, exclude="", platform="iPhoneOS", extra=""):
        buf = io.BytesIO()
        app = "Payload/Feather.app/"
        info = {"CFBundleSupportedPlatforms": [platform], "UIDeviceFamily": [1, 2], "CFBundleExecutable": "Feather"}
        with zipfile.ZipFile(buf, "w") as archive:
            archive.writestr(app + "Info.plist", plistlib.dumps(info))
            for name in ("Feather", "_CodeSignature/CodeResources", "embedded.mobileprovision", "Feather.momd/Feather.mom"):
                if name != exclude:
                    archive.writestr(app + name, b"fixture")
            if extra:
                archive.writestr(extra, b"fixture")
        return zipfile.ZipFile(buf)

    def test_complete_structure(self):
        with self.sample() as archive:
            self.assertEqual(inspect(archive)[0], "Payload/Feather.app")

    def test_missing_components(self):
        for name in ("Feather", "_CodeSignature/CodeResources", "embedded.mobileprovision", "Feather.momd/Feather.mom"):
            with self.subTest(name=name), self.sample(exclude=name) as archive, self.assertRaises(ValueError):
                inspect(archive)

    def test_device_and_stale_app(self):
        with self.sample(platform="iPhoneSimulator") as archive, self.assertRaises(ValueError):
            inspect(archive)
        with self.sample(extra="Payload/Old.app/Info.plist") as archive, self.assertRaises(ValueError):
            inspect(archive)


if __name__ == "__main__":
    unittest.main()
