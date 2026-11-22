"""Copies UI-test screenshots exported by xcresulttool to docs/screenshots with readable names."""
import json, os, re, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
clean = "--clean" in sys.argv
manifest = os.path.join(src, "manifest.json")
if not os.path.exists(manifest):
    sys.exit(0)
os.makedirs(dst, exist_ok=True)
if clean:
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
for test in json.load(open(manifest)):
    for att in test.get("attachments", []):
        name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
        name = re.sub(r"_\d+_[0-9A-F-]{36}", "", name)  # drop index + UUID suffix
        if not name.lower().endswith(".png"):
            name += ".png"
        shutil.copy(os.path.join(src, att["exportedFileName"]), os.path.join(dst, name))
        print("screenshot:", name)
