"""Patch the Flutter-generated Android app module for Unsung.

Run after `flutter create . --platforms=android`. Idempotent.
- minSdk 24 (MediaCodec/MediaExtractor APIs used by the native audio engine,
  and the recorder plugin's own minimum).
- media3-common for the Sonic pitch shifter used when rendering key changes.
"""
import pathlib
import re
import sys

app = pathlib.Path("android/app")
kts = app / "build.gradle.kts"
groovy = app / "build.gradle"

if kts.exists():
    path, src = kts, kts.read_text()
    src = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 24", src)
    src = re.sub(r"minSdk\s*=\s*\d+", "minSdk = 24", src)
    dep = 'implementation("androidx.media3:media3-common:1.4.1")'
elif groovy.exists():
    path, src = groovy, groovy.read_text()
    src = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdkVersion 24", src)
    dep = "implementation 'androidx.media3:media3-common:1.4.1'"
else:
    sys.exit("android/app build file not found; run flutter create first")

if "media3-common" not in src:
    if re.search(r"^dependencies\s*\{", src, flags=re.M):
        src = re.sub(r"^dependencies\s*\{", "dependencies {\n    " + dep, src, count=1, flags=re.M)
    else:
        src += "\ndependencies {\n    " + dep + "\n}\n"

path.write_text(src)
print(f"patched {path}")
print(src)
