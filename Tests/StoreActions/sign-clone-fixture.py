"""Exercise the pinned native signer on synthetic Mach-O bundles, without an Apple identity."""
from pathlib import Path
import hashlib
import plistlib
import struct
import subprocess
import sys
import tempfile

signer = Path(sys.argv[1]).resolve()
fixture = Path(__file__).resolve().parents[2] / "Zsign/Upstream/test/dylib/bin/demo1.dylib"
with tempfile.TemporaryDirectory() as work:
    root = Path(work)
    def run(*args):
        subprocess.run(args, cwd=root, check=True, stdout=subprocess.DEVNULL)

    run("openssl", "req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
        "-subj", "/CN=Disposable Test", "-keyout", "key.pem", "-out", "cert.pem")
    run("openssl", "x509", "-in", "cert.pem", "-outform", "DER", "-out", "cert.der")
    profile = {"TeamIdentifier": ["TEAM"], "DeveloperCertificates": [(root / "cert.der").read_bytes()],
               "Entitlements": {"application-identifier": "TEAM.org.fixture.*"}}
    (root / "profile.plist").write_bytes(plistlib.dumps(profile))
    run("openssl", "cms", "-sign", "-binary", "-nodetach", "-in", "profile.plist", "-signer",
        "cert.pem", "-inkey", "key.pem", "-outform", "DER", "-out", "profile")
    profiles = (root / "profile").read_bytes()
    for identifier in ["org.fixture.app", "org.fixture.app.1"]:
        app = root / (identifier + ".app")
        paths = {app: identifier, app / "PlugIns/Example.appex": identifier + ".extension"}
        claims = {}
        for bundle, bundle_id in paths.items():
            bundle.mkdir(parents=True)
            data = bytearray(fixture.read_bytes())
            struct.pack_into("<I", data, 12, 2)  # MH_EXECUTE for entitlement slots
            (bundle / "Test").write_bytes(data)
            info = {"CFBundleIdentifier": bundle_id, "CFBundleVersion": "1", "CFBundleExecutable": "Test"}
            (bundle / "Info.plist").write_bytes(plistlib.dumps(info))
            claims[bundle_id] = {"application-identifier": "TEAM." + bundle_id}
        (root / "claims").write_bytes(plistlib.dumps({"AMARYTCloneClaims": claims}))
        run(signer, "-q", "-f", "-m", "profile", "-k", "key.pem", "-e", "claims", app)
        for bundle, bundle_id in paths.items():
            assert (bundle / "embedded.mobileprovision").read_bytes() == profiles
            seal = plistlib.loads((bundle / "_CodeSignature/CodeResources").read_bytes())
            assert seal["files2"]["embedded.mobileprovision"]["hash2"] == hashlib.sha256(profiles).digest()
            binary = (bundle / "Test").read_bytes()
            start = binary.rindex(b"\xfa\xde\x71\x71")  # XML entitlements slot
            size, = struct.unpack_from(">I", binary, start + 4)
            assert plistlib.loads(binary[start + 8:start + size]) == claims[bundle_id]
print("PASS: signed two distinct app IDs and extensions with sealed profiles and concrete entitlements")
