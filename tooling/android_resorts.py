#!/usr/bin/env python3
"""Write android/.../logic/ResortIndex.kt from Slide/Logic/ResortIndex.swift (same offline resort list on both platforms)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Slide/Logic/ResortIndex.swift"
OUT = ROOT / "android/app/src/main/java/ch/geneve/slide/logic/ResortIndex.kt"

MATCH = '''    fun match(latitude: Double, longitude: Double): Resort? {
        var best: Pair<Resort, Double>? = null
        var nearest: Pair<Resort, Double>? = null
        for (place in places) {
            val km = Geo.haversineMeters(latitude, longitude, place.latitude, place.longitude) / 1000
            if (km <= place.radiusKm) {
                val current = best
                if (current == null || place.radiusKm < current.first.radiusKm ||
                    (place.radiusKm == current.first.radiusKm && km < current.second)
                ) best = place to km
            }
            if (nearest == null || km < nearest.second) nearest = place to km
        }
        best?.let { return it.first }
        return nearest?.takeIf { it.second <= 12 }?.first
    }

    fun match(samples: List<TrackSample>): Resort? {
        if (samples.isEmpty()) return null
        return match(samples.sumOf { it.latitude } / samples.size, samples.sumOf { it.longitude } / samples.size)
    }
}
'''


def main():
    rows = re.findall(
        r'Resort\(name: "((?:[^"\\]|\\.)*)", country: "(\w+)", latitude: ([-\d.]+), longitude: ([-\d.]+), radiusKm: ([\d.]+)\)',
        SRC.read_text(),
    )
    out = [
        "package ch.geneve.slide.logic",
        "",
        "// Generated from Slide/Logic/ResortIndex.swift by tooling/android_resorts.py. Do not edit by hand.",
        "",
        "data class Resort(val name: String, val country: String, val latitude: Double, val longitude: Double, val radiusKm: Double)",
        "",
        "object ResortIndex {",
        "    val places: List<Resort> = listOf(",
    ]
    for name, country, lat, lon, radius in rows:
        name = name.replace("\\", "\\\\").replace("$", "\\$")
        out.append(f'        Resort("{name}", "{country}", {lat}, {lon}, {float(radius)}),')
    out += ["    )", "", MATCH]
    OUT.write_text("\n".join(out))
    print(f"{len(rows)} resorts -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
