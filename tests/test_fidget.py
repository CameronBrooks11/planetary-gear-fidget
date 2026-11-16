"""Render the fidget in several layouts and check that it prints in place and meshes.

usage: python3 tests/test_fidget.py [OPENSCAD]

Each case renders planetary_gear_fidget.scad to a binary STL with
--hardwarnings, then sorts the result into separate solids (triangles sharing a
vertex belong to the same solid):

- At the layout's clearance, the parts must come out as planetGearCount + 2
  solids, the sun, the ring and each planet, none touching another, and the
  whole outerRingDiameter across and gearThickness tall from z = 0.
- At a clearance of -0.05 mm, overlapping a little, they must fuse into one: a
  planet only fuses with the sun and the ring if its teeth are in mesh with
  theirs. Overlapping teeth can enclose small voids, which are left out of
  the count.
- The sun tooth count must let the planets sit evenly: sun + ring a multiple of
  the planet count.
"""

import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAD = os.path.join(ROOT, "planetary_gear_fidget.scad")
SMALL = 1000  # triangles; enclosed voids and slivers between overlapping teeth are far smaller


def solids(path):
    """Triangle count and bounding box of each separate solid."""
    data = open(path, "rb").read()
    (n,) = struct.unpack_from("<I", data, 80)
    tris = [struct.unpack_from("<9f", data, 84 + i * 50 + 12) for i in range(n)]
    parent = {}

    def find(v):
        while parent[v] != v:
            parent[v] = parent[parent[v]]
            v = parent[v]
        return v

    for t in tris:
        corners = [t[0:3], t[3:6], t[6:9]]
        for c in corners:
            parent.setdefault(c, c)
        root = find(corners[0])
        for c in corners[1:]:
            parent[find(c)] = root
    groups = {}
    for t in tris:
        groups.setdefault(find(t[0:3]), []).append(t)
    out = []
    for g in groups.values():
        pts = [p for t in g for p in (t[0:3], t[3:6], t[6:9])]
        out.append((len(g), [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]))
    return out


def render(openscad, out, params):
    cmd = [openscad, "--hardwarnings", "--export-format", "binstl", "-o", out]
    for k, v in params.items():
        cmd += ["-D", f"{k}={v}"]
    return subprocess.run(cmd + [SCAD], capture_output=True, text=True)


LAYOUTS = [
    ("default", {}),
    ("3 planets of 9 teeth", {"planetGearCount": 3, "planetGearTeethCount": 9, "approxSunGearTeethCount": 15}),
    ("4 planets", {"planetGearCount": 4, "approxSunGearTeethCount": 10}),
    ("5 planets of 8 teeth", {"planetGearCount": 5, "planetGearTeethCount": 8, "approxSunGearTeethCount": 12}),
    ("spur gears, wide hex hole", {"twistTeethCount": 0, "hexHoleWidth": 8}),
    ("smaller and thinner", {"outerRingDiameter": 60, "gearThickness": 12, "outerTorusDiameter": 62, "torusThickness": 20}),
]

results = []


def check(label, ok, got):
    results.append(bool(ok))
    print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")


def main():
    openscad = sys.argv[1] if len(sys.argv) > 1 else "openscad"
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "case.stl")
        for label, params in LAYOUTS:
            planets = params.get("planetGearCount", 6)
            planet_teeth = params.get("planetGearTeethCount", 7)
            diameter = params.get("outerRingDiameter", 90)
            thickness = params.get("gearThickness", 25)

            r = render(openscad, out, params)
            bad = [l for l in r.stderr.splitlines() if "WARNING" in l or "ERROR" in l]
            if r.returncode != 0 or bad:
                check(f"{label}: prints in place", False, bad[:1] or f"exit {r.returncode}")
                continue
            m = re.search(r"sun_teeth = (\d+), ring_teeth = (\d+)", r.stderr)
            sun, ring = int(m.group(1)), int(m.group(2))
            check(f"{label}: planets sit evenly", (sun + ring) % planets == 0 and ring == sun + 2 * planet_teeth,
                  f"sun {sun}, ring {ring}, {planets} planets")
            parts = solids(out)
            lo = [min(p[1][i] for p in parts) for i in range(3)]
            hi = [max(p[2][i] for p in parts) for i in range(3)]
            size = [hi[i] - lo[i] for i in range(3)]
            ok = len(parts) == planets + 2 and abs(size[0] - diameter) <= 0.01 and abs(size[1] - diameter) <= 0.01 \
                and abs(size[2] - thickness) <= 0.01 and abs(lo[2]) <= 0.01
            check(f"{label}: prints in place", ok,
                  f"{len(parts)} separate parts (want {planets + 2}), {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f} mm")

            r = render(openscad, out, {**params, "clearanceTolerance": -0.05})
            large = [p for p in solids(out) if p[0] >= SMALL] if r.returncode == 0 else []
            check(f"{label}: teeth mesh", len(large) == 1,
                  f"{len(large)} part(s) once they overlap by 0.05 mm (want 1)")

        for label, params, message in [
            ("refuses too few planet teeth", {"planetGearTeethCount": 4}, "planetGearTeethCount has to be at least 5"),
            ("refuses planets that overlap each other", {"planetGearCount": 9}, "overlap each other"),
        ]:
            r = render(openscad, out, params)
            errors = [l for l in r.stderr.splitlines() if "ERROR" in l]
            check(label, errors and message in errors[0], errors[0][:120] if errors else f"exit {r.returncode}, no error")

    print(f"{sum(results)} of {len(results)} checks passed")
    sys.exit(0 if all(results) else 1)


main()
