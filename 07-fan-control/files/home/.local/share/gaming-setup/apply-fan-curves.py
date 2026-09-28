#!/usr/bin/env python3
"""
Recreate the Windows FanControl setup inside CoolerControl.

Ported from
  /run/media/lee/.../Program Files (x86)/FanControl/Configurations/userConfig.json

  GPU curve       NVIDIA GPU temp   60.1 C -> 25.5 %, 64.6 C -> 40 %
  CPU curve       k10temp Tctl      69.8 C -> 20.3 %, 79.7 C -> 49.9 %
  Main Mix        Max(GPU, CPU)

  CHA_FAN1 / Bottom Intake          fan1  -> Main Mix
  CPU_FAN  / Top Exhaust, radiator  fan2  -> Main Mix
  CHA_FAN3 / Rear 140 Exhaust       fan3  -> Main Mix
  CHA_FAN2 / Rear Exhaust           fan6  -> GPU
  pump                              fan7  -> left on BIOS control, as on Windows
  fan4, fan5                        unused

FanControl clamps a curve flat outside its first and last point; CoolerControl
does the same, but the flat sections are written out explicitly here so the
intent survives anyone opening the GUI later.

Idempotent: profiles are matched by name, so re-running updates rather than
duplicating. Run it again after a CoolerControl reinstall or a config reset.
"""
import json
import sys
import os
import urllib.request
import urllib.error
import uuid
import http.cookiejar

BASE = "http://localhost:11987"
# CoolerControl's stock credentials. If a password has been set in the GUI, these
# stop working and every call comes back 401 - the daemon keeps its hash in
# /etc/coolercontrol/.passwd, which cannot be read back, so pass the real one:
#
#     CC_PASSWORD='...' python3 apply-fan-curves.py
USER = os.environ.get("CC_USER", "CCAdmin")
PASSWORD = os.environ.get("CC_PASSWORD", "coolAdmin")

# FanControl's hysteresis block: 2 C up and down, 1 s response either way.
FUNCTION_NAME = "FanControl Hysteresis"

CURVES = {
    "GPU": [(20, 26), (60, 26), (65, 40), (100, 40)],
    "CPU": [(20, 20), (70, 20), (80, 50), (100, 50)],
}

# (hwmon channel, profile name)
ASSIGNMENTS = [
    ("fan1", "Main Mix"),   # CHA_FAN1, Bottom Intake
    ("fan2", "Main Mix"),   # CPU_FAN, Top Exhaust / radiator
    ("fan3", "Main Mix"),   # CHA_FAN3, Rear 140 Exhaust
    ("fan6", "GPU"),        # CHA_FAN2, Rear Exhaust
]

opener = urllib.request.build_opener(
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
)


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    if data:
        req.add_header("Content-Type", "application/json")
    if path == "/login":
        import base64
        token = base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()
        req.add_header("Authorization", "Basic " + token)
    try:
        with opener.open(req, timeout=10) as r:
            raw = r.read().decode()
            return json.loads(raw) if raw.strip() else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:300]}")
    except urllib.error.URLError as e:
        sys.exit(f"{method} {path} -> {e}. Is coolercontrold running?")


def find_device(devices, name):
    for d in devices:
        if d["name"] == name:
            return d
    sys.exit(f"CoolerControl does not see a device called {name!r}.")


def main():
    call("POST", "/login")
    devices = call("GET", "/devices")["devices"]

    nct = find_device(devices, "nct6799")
    gpu = find_device(devices, "NVIDIA GeForce RTX 5090")
    cpu = next(d for d in devices if d["type"] == "CPU")

    # The Windows curves read the GPU core temp and the CPU's Tctl. Resolve
    # both by their CoolerControl labels rather than hard-coding sensor keys.
    def temp_named(dev, label):
        for key, t in (dev.get("info") or {}).get("temps", {}).items():
            if t["label"] == label:
                return key
        sys.exit(f"{dev['name']} has no temperature labelled {label!r}.")

    sources = {
        "GPU": {"device_uid": gpu["uid"], "temp_name": temp_named(gpu, "GPU Temp")},
        "CPU": {"device_uid": cpu["uid"], "temp_name": temp_named(cpu, "CPU Temp Tctl")},
    }

    functions = {f["name"]: f["uid"] for f in call("GET", "/functions")["functions"]}
    if FUNCTION_NAME not in functions:
        fuid = str(uuid.uuid4())
        call("POST", "/functions", {
            "uid": fuid, "name": FUNCTION_NAME, "f_type": "Standard",
            "duty_minimum": 1, "duty_maximum": 100,
            "step_size_min_decreasing": 0, "step_size_max_decreasing": 0,
            "threshold_hopping": True, "bypass_min_at_extremes": True,
            "response_delay": 1, "deviance": 2.0, "only_downward": False,
        })
        functions[FUNCTION_NAME] = fuid
    fuid = functions[FUNCTION_NAME]

    existing = {p["name"]: p["uid"] for p in call("GET", "/profiles")["profiles"]}

    def upsert(profile):
        name = profile["name"]
        if name in existing:
            profile["uid"] = existing[name]
            call("PUT", "/profiles", profile)
            print(f"  updated profile {name}")
        else:
            profile["uid"] = str(uuid.uuid4())
            call("POST", "/profiles", profile)
            print(f"  created profile {name}")
        existing[name] = profile["uid"]
        return profile["uid"]

    print("Profiles:")
    for name, points in CURVES.items():
        upsert({
            "name": name, "p_type": "Graph",
            "speed_profile": [list(p) for p in points],
            "temp_source": sources[name], "function_uid": fuid,
            "member_profile_uids": [], "mix_function_type": None,
            "speed_fixed": None,
        })

    upsert({
        "name": "Main Mix", "p_type": "Mix",
        "speed_profile": None, "temp_source": None,
        "function_uid": "0",          # the mix takes its members' functions
        "member_profile_uids": [existing["GPU"], existing["CPU"]],
        "mix_function_type": "Max",
        "speed_fixed": None,
    })

    print("Fans:")
    for channel, profile_name in ASSIGNMENTS:
        call("PUT", f"/devices/{nct['uid']}/settings/{channel}/profile",
             {"profile_uid": existing[profile_name]})
        print(f"  {channel} -> {profile_name}")

    print("\nDone. fan7 (pump) and the GPU's own fans are deliberately left alone.")


if __name__ == "__main__":
    main()
