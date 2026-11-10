#!/usr/bin/env bash
# Prints the UDID of a simulator to use, creating one if needed.
#   pick-simulator.sh phone   → an iPhone Duo if the runtime has one, else the newest iPhone
#   pick-simulator.sh spread  → an iPhone Duo if available, else the newest iPad (a stand-in
#                               for the unfolded inner display)
set -euo pipefail
KIND="${1:-phone}"

python3 - "$KIND" <<'PY'
import json, subprocess, sys

kind = sys.argv[1]
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "devices", "available"]))["devices"]
types = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "devicetypes"]))["devicetypes"]
runtimes = [r for r in json.loads(subprocess.check_output(["xcrun", "simctl", "list", "-j", "runtimes", "available"]))["runtimes"]
            if r.get("platform") == "iOS" or "iOS" in r.get("name", "")]
runtimes.sort(key=lambda r: [int(x) for x in r["version"].split(".")])
if not runtimes:
    sys.exit("No iOS simulator runtime installed")
runtime = runtimes[-1]

def preference(name):
    if "Duo" in name:
        return 0
    if kind == "spread" and name.startswith("iPad Pro 13"):
        return 1
    if kind == "spread" and name.startswith("iPad"):
        return 2
    if kind == "phone" and name.startswith("iPhone") and "Pro" in name and "Max" not in name:
        return 1
    if kind == "phone" and name.startswith("iPhone"):
        return 2
    return None

existing = [d for d in devices.get(runtime["identifier"], []) if preference(d["name"]) is not None]
if existing:
    existing.sort(key=lambda d: (preference(d["name"]), d["name"]), reverse=False)
    best = min(preference(d["name"]) for d in existing)
    candidates = [d for d in existing if preference(d["name"]) == best]
    candidates.sort(key=lambda d: d["name"])
    print(candidates[-1]["udid"])
    sys.exit(0)

supported = {t["identifier"] for t in runtime.get("supportedDeviceTypes", [])} or {t["identifier"] for t in types}
choices = [t for t in types if t["identifier"] in supported and preference(t["name"]) is not None]
if not choices:
    sys.exit("No suitable simulator device type")
best = min(preference(t["name"]) for t in choices)
choice = sorted([t for t in choices if preference(t["name"]) == best], key=lambda t: t["name"])[-1]
udid = subprocess.check_output(["xcrun", "simctl", "create", "FieldGuide " + choice["name"], choice["identifier"], runtime["identifier"]]).decode().strip()
print(udid)
PY
