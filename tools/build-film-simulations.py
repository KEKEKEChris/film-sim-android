"""Build ten film-simulation profiles from the ones the project already carries.

Each new stock is a copy of a real base record with three things changed, and nothing else:

  * `curves[].sampled.density` — the H&D density against log exposure. Contrast is a scaling
    of that array about its own midpoint; a colour cast is a small per-channel offset. The
    analytic `gamma`/`toe`/`shoulder` beside it are metadata when `sampled` is present, so they
    are left alone rather than made to disagree with it.
  * `couplerInhibition` — the interlayer restraint that lowers saturation. Velvia carries
    0.05–0.08 and Eterna 0.08–0.32, so a larger number is a less saturated film.
  * the identity fields, so the loader lists it as its own stock.

The spectral record, the layered transport, the grain and the halation are inherited from the
base unchanged: they describe the emulsion, not the grade, and inventing them would be making
up physics.

Run from the repository root:

    python build-film-simulations.py --dry-run    # report, write nothing
    python build-film-simulations.py              # write the profiles and the manifest
"""

import argparse
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1] if "__file__" in globals() else pathlib.Path(".")
STOCKS = ROOT / "Sources/FotufilmCore/Stocks"
MANIFEST = ROOT / "licenses/FILM-PROFILES.json"

# The interlayer restraint Velvia states, used as the shape for a reversal stock that carries
# none of its own. Scaled by strength/0.08 so `strength` reads as "as much as Velvia at 0.08".
INHIBITION_SHAPE = [[0.0, 0.081, 0.0], [0.051, 0.0, 0.058], [0.012, 0.084, 0.0]]
SHAPE_PEAK = 0.084

DENSITY_CEILING = 4.0
# The floor is a fraction of the base's own minimum, not a constant. On a reversal stock that
# minimum is the brightest highlight, and clamping it to a fixed 0.02 blows the highlight out;
# on a negative it is the base fog, and clamping it kills the shadow's detail. Keeping a share
# of whatever the base states preserves both.
DENSITY_FLOOR_SHARE = 0.6
DENSITY_FLOOR_MINIMUM = 0.03


def scale_about_midpoint(values, factor):
    """Contrast: widen or narrow the density range about its own middle."""
    low, high = min(values), max(values)
    middle = (low + high) / 2
    floor = max(low * DENSITY_FLOOR_SHARE, DENSITY_FLOOR_MINIMUM)
    return [min(max(middle + (v - middle) * factor, floor), DENSITY_CEILING)
            for v in values]


def offset(values, amount):
    low = min(values)
    floor = max(low * DENSITY_FLOOR_SHARE, DENSITY_FLOOR_MINIMUM)
    return [min(max(v + amount, floor), DENSITY_CEILING) for v in values]


def inhibit(base, strength=None, scale=None):
    """The interlayer matrix, either stated outright or scaled from the base's own."""
    if strength is not None:
        k = strength / SHAPE_PEAK
        return [[round(v * k, 6) for v in row] for row in INHIBITION_SHAPE]
    return [[round(v * scale, 6) for v in row] for row in base]


SPECS = [
    # id, name, subtitle, base, contrast, (R, G, B) offset, inhibition
    # Names are initials, and the subtitles describe the look rather than naming a brand:
    # the stocks are our own grades, and the initials keep a trademark off the label.
    dict(id="simCC", name="C C",
         subtitle="film look · low saturation, cool shadows", base="provia100f",
         contrast=1.15, shift=(-0.010, 0.000, -0.020), inhibit=0.12),
    dict(id="simCN", name="C N",
         subtitle="film look · hard contrast, warm shadows", base="eterna500",
         contrast=1.20, shift=(0.030, 0.000, -0.020), inhibit_scale=1.10),
    dict(id="simNN", name="N N",
         subtitle="film look · amber, softly printed", base="eterna500",
         contrast=1.05, shift=(0.050, 0.020, 0.000), inhibit_scale=1.25),
    dict(id="simEBB", name="E B B",
         subtitle="film look · near-monochrome, hard", base="eterna500",
         contrast=1.35, shift=(0.000, 0.000, 0.000), inhibit_scale=1.60),
    dict(id="simRA", name="R A",
         subtitle="film look · neutral, faithful colour", base="provia100f",
         contrast=1.06, shift=(0.010, 0.000, 0.000), inhibit=0.02),
    dict(id="simPF", name="P F",
         subtitle="image control · vivid, kept natural", base="velvia50",
         contrast=0.96, shift=(0.000, 0.000, 0.000), inhibit_scale=1.30),
    dict(id="simNF", name="N F",
         subtitle="image control · soft, muted", base="eterna500",
         contrast=1.10, shift=(0.000, 0.000, 0.000), inhibit_scale=1.15),
    dict(id="simHCBW", name="H C B&W",
         subtitle="image control · hard monochrome", base="acros100",
         contrast=1.40, shift=(0.000, 0.000, 0.000)),
    dict(id="simRT", name="R T",
         subtitle="image control · faded, warm", base="provia100f",
         contrast=0.88, shift=(0.040, 0.010, 0.000), inhibit=0.10),
    dict(id="simBB", name="B B",
         subtitle="image control · high contrast, desaturated", base="eterna500",
         contrast=1.30, shift=(0.000, 0.000, 0.000), inhibit_scale=1.55),
]


def build(spec):
    source = json.loads((STOCKS / f"{spec['base']}.json").read_text(encoding="utf-8"))
    record = json.loads(json.dumps(source))  # deep copy

    record["id"] = spec["id"]
    record["name"] = spec["name"]
    record["subtitle"] = spec["subtitle"]

    for index, curve in enumerate(record["curves"]):
        sampled = curve.get("sampled")
        if not sampled:
            raise SystemExit(f"{spec['base']}: curve {index} carries no sampled record")
        density = scale_about_midpoint(sampled["density"], spec["contrast"])
        density = offset(density, spec["shift"][index])
        sampled["density"] = [round(v, 6) for v in density]
        # The validator treats the first sampled point as the curve's actual minimum.
        # Contrast and colour shifts can move that point, so keep the analytic metadata
        # in sync or the whole stock directory is rejected as malformed.
        curve["dMin"] = sampled["density"][0]

    if "inhibit" in spec:
        record["couplerInhibition"] = inhibit(None, strength=spec["inhibit"])
    elif "inhibit_scale" in spec:
        record["couplerInhibition"] = inhibit(source["couplerInhibition"],
                                              scale=spec["inhibit_scale"])

    transport = record.get("layeredTransport")
    if isinstance(transport, dict) and transport.get("constructionID"):
        transport["constructionID"] = f"{spec['id']}-inferred-v1"

    return record


# Ids these stocks carried before the rename to initials. Their files and manifest entries are
# removed on every run, so a rename leaves no stale profile behind for the loader to pick up.
RETIRED = [
    "fujiClassicChrome", "fujiClassicNeg", "fujiNostalgicNeg", "fujiEternaBleach",
    "fujiRealaAce", "ricohPositiveFilm", "ricohNegativeFilm", "ricohHighContrastBW",
    "ricohRetro", "ricohBleachBypass",
]


def write_lf(path, text):
    """Write with LF endings whatever the platform. The manifest hashes the bytes, and the
    rest of the Stocks directory is LF, so a CRLF write would change every digest and leave
    the tree with mixed line endings."""
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for retired in RETIRED:
        stale = STOCKS / f"{retired}.json"
        if stale.exists() and not args.dry_run:
            stale.unlink()
            print(f"{retired:<22} removed (renamed)")
        manifest.pop(retired, None)

    for spec in SPECS:
        record = build(spec)
        text = json.dumps(record, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
        path = STOCKS / f"{spec['id']}.json"
        digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
        print(f"{spec['id']:<22} <- {spec['base']:<12} "
              f"{len(text)/1024:6.1f} KiB  {digest[:12]}")
        if not args.dry_run:
            write_lf(path, text)
            manifest[spec["id"]] = digest

    if args.dry_run:
        print("\ndry run: nothing written")
        return

    write_lf(MANIFEST, json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"\nmanifest: {len(manifest)} profiles")


if __name__ == "__main__":
    main()
