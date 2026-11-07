"""Applies Little Garage's native settings after `flutter create`.

Landscape only on iOS and Android, app name, and a landscape web manifest.
Idempotent: safe to run on every build.
"""
import json
import pathlib
import re

APP_NAME = "Little Garage"
LANDSCAPE = (
    "<array>\n"
    "\t\t<string>UIInterfaceOrientationLandscapeLeft</string>\n"
    "\t\t<string>UIInterfaceOrientationLandscapeRight</string>\n"
    "\t</array>"
)


def patch_ios():
    p = pathlib.Path("ios/Runner/Info.plist")
    if not p.exists():
        return
    s = p.read_text()
    s = re.sub(
        r"(<key>UISupportedInterfaceOrientations(?:~ipad)?</key>\s*)<array>.*?</array>",
        lambda m: m.group(1) + LANDSCAPE,
        s,
        flags=re.S,
    )
    s = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        lambda m: m.group(1) + APP_NAME + m.group(2),
        s,
    )
    p.write_text(s)
    print("Patched", p)


def patch_android():
    p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
    if not p.exists():
        return
    s = p.read_text()
    if "android:screenOrientation" not in s:
        s = s.replace(
            'android:name=".MainActivity"',
            'android:name=".MainActivity"\n            android:screenOrientation="sensorLandscape"',
            1,
        )
    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)
    p.write_text(s)
    print("Patched", p)


def patch_web():
    m = pathlib.Path("web/manifest.json")
    if m.exists():
        d = json.loads(m.read_text())
        d.update(
            name=APP_NAME,
            short_name=APP_NAME,
            orientation="landscape",
            display="fullscreen",
            background_color="#56CCF2",
            theme_color="#4C6EF5",
        )
        m.write_text(json.dumps(d, indent=2) + "\n")
        print("Patched", m)
    i = pathlib.Path("web/index.html")
    if i.exists():
        s = i.read_text()
        s = re.sub(r"<title>.*?</title>", f"<title>{APP_NAME}</title>", s, flags=re.S)
        s = re.sub(
            r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")',
            lambda mm: mm.group(1) + APP_NAME + mm.group(2),
            s,
        )
        i.write_text(s)
        print("Patched", i)


if __name__ == "__main__":
    patch_ios()
    patch_android()
    patch_web()
