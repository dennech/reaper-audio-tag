#!/usr/bin/env python3
"""Generate Lua emoji asset and label-map bundles for the REAPER report UI."""

from __future__ import annotations

import base64
import csv
import math
import struct
import zlib
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "reaper" / "assets" / "noto-emoji" / "png128"
CSV_PATH = ROOT / "reaper" / "data" / "class_labels_indices.csv"
ASSET_OUTPUT = ROOT / "reaper" / "lib" / "report_icon_assets.lua"
MAP_OUTPUT = ROOT / "reaper" / "lib" / "report_icon_map.lua"

UPSTREAM_REPO = "https://github.com/googlefonts/noto-emoji"
UPSTREAM_COMMIT = "8998f5dd683424a73e2314a8c1f1e359c19e8742"
UPSTREAM_IMAGE_LICENSE = "Apache-2.0"
UPSTREAM_FONT_LICENSE = "OFL-1.1"

ICON_FILES: "OrderedDict[str, str]" = OrderedDict(
    [
        ("brand", "emoji_u1f3a7.png"),
        ("ready", "emoji_u2705.png"),
        ("loading", "emoji_u23f3.png"),
        ("error", "emoji_u274c.png"),
        ("details", "emoji_u1f50e.png"),
        ("cues", "emoji_u1f3af.png"),
        ("tags", "emoji_u1f3f7.png"),
        ("generic", "emoji_u2728.png"),
        ("sound", "emoji_u1f50a.png"),
        ("speech", "emoji_u1f399.png"),
        ("laughter", "emoji_u1f606.png"),
        ("crying", "emoji_u1f62d.png"),
        ("breath", "emoji_u1f62e_200d_1f4a8.png"),
        ("footsteps", "emoji_u1f463.png"),
        ("mouth", "emoji_u1f444.png"),
        ("hands", "emoji_u1f44f.png"),
        ("heart", "emoji_u2764.png"),
        ("crowd", "emoji_u1f465.png"),
        ("animal", "emoji_u1f43e.png"),
        ("dog", "emoji_u1f436.png"),
        ("cat", "emoji_u1f431.png"),
        ("farm", "emoji_u1f42e.png"),
        ("bird", "emoji_u1f426.png"),
        ("insect", "emoji_u1f41b.png"),
        ("frog", "emoji_u1f438.png"),
        ("snake", "emoji_u1f40d.png"),
        ("whale", "emoji_u1f433.png"),
        ("guitar", "emoji_u1f3b8.png"),
        ("piano", "emoji_u1f3b9.png"),
        ("synth", "emoji_u1f39b.png"),
        ("drum", "emoji_u1f941.png"),
        ("strings", "emoji_u1f3bb.png"),
        ("brass", "emoji_u1f3ba.png"),
        ("woodwind", "emoji_u1f3b7.png"),
        ("bell", "emoji_u1f514.png"),
        ("music", "emoji_u1f3b5.png"),
        ("wind", "emoji_u1f4a8.png"),
        ("storm", "emoji_u26c8.png"),
        ("water", "emoji_u1f4a7.png"),
        ("fire", "emoji_u1f525.png"),
        ("boat", "emoji_u26f5.png"),
        ("vehicle", "emoji_u1f697.png"),
        ("train", "emoji_u1f686.png"),
        ("aircraft", "emoji_u2708.png"),
        ("engine", "emoji_u2699.png"),
        ("door", "emoji_u1f6aa.png"),
        ("kitchen", "emoji_u1f373.png"),
        ("bathroom", "emoji_u1f6bf.png"),
        ("keys", "emoji_u1f511.png"),
        ("typing", "emoji_u2328.png"),
        ("phone", "emoji_u260e.png"),
        ("alarm", "emoji_u23f0.png"),
        ("clock", "emoji_u1f552.png"),
        ("camera", "emoji_u1f4f7.png"),
        ("tools", "emoji_u1f528.png"),
        ("gun", "emoji_u1f52b.png"),
        ("explosion", "emoji_u1f4a5.png"),
        ("tree", "emoji_u1f333.png"),
        ("glass", "emoji_u1f943.png"),
        ("bubble", "emoji_u1fae7.png"),
        ("liquid", "emoji_u1f4a6.png"),
        ("impact", "emoji_u1f44a.png"),
        ("click", "emoji_u1f5b1.png"),
        ("silence", "emoji_u1f507.png"),
        ("room", "emoji_u1f3e0.png"),
    ]
)

ICON_SIZE = 128
ATLAS_PADDING = 8

SECTION_ICON_KEYS = {
    "cues": "cues",
    "tags": "tags",
}

EXACT_ICON_KEYS = {
    "Applause": "hands",
    "Battle cry": "speech",
    "Beatboxing": "music",
    "Belly laugh": "laughter",
    "Bell": "bell",
    "Bicycle bell": "bell",
    "Boiling": "bubble",
    "Busy signal": "phone",
    "Bird vocalization, bird call, bird song": "bird",
    "Cattle, bovinae": "farm",
    "Change ringing (campanology)": "bell",
    "Chatter": "speech",
    "Cowbell": "bell",
    "Doorbell": "bell",
    "Drum and bass": "music",
    "Drum machine": "synth",
    "Electronic dance music": "music",
    "Electronic music": "music",
    "Electronic organ": "synth",
    "Electronic tuner": "synth",
    "Effects unit": "synth",
    "Field recording": "sound",
    "Fire alarm": "alarm",
    "Fireworks": "explosion",
    "Flap": "wind",
    "Happy music": "music",
    "Heavy engine (low frequency)": "engine",
    "Honk": "farm",
    "Hum": "sound",
    "Jingle (music)": "music",
    "Jingle bell": "bell",
    "Light engine (high frequency)": "engine",
    "Mechanisms": "engine",
    "Medium engine (mid frequency)": "engine",
    "Mains hum": "sound",
    "Music": "music",
    "Musical instrument": "music",
    "Moo": "farm",
    "Noise": "sound",
    "Outside, rural or natural": "tree",
    "Outside, urban or manmade": "sound",
    "Power windows, electric windows": "vehicle",
    "Rain on surface": "water",
    "Rattle": "snake",
    "Rattle (instrument)": "drum",
    "Reverberation": "room",
    "Rustling leaves": "wind",
    "Scratching (performance technique)": "synth",
    "Silence": "silence",
    "Sine wave": "synth",
    "Smoke detector, smoke alarm": "alarm",
    "Sonar": "sound",
    "Sound effect": "synth",
    "Speech synthesizer": "synth",
    "Static": "sound",
    "Steam": "water",
    "Steam whistle": "alarm",
    "Telephone": "phone",
    "Telephone bell ringing": "phone",
    "Theme music": "music",
    "Throbbing": "sound",
    "Tick": "clock",
    "Tick-tock": "clock",
    "Tuning fork": "bell",
    "Tubular bells": "bell",
    "Vehicle horn, car horn, honking": "vehicle",
    "Video game music": "music",
    "Vibration": "sound",
    "Wedding music": "music",
    "Whimper (dog)": "dog",
    "Whistling": "music",
    "Whoosh, swoosh, swish": "wind",
    "Wind chime": "bell",
    "Wind noise (microphone)": "wind",
    "Writing": "typing",
    "Liquid": "bubble",
    "Splash, splatter": "bubble",
    "Slosh": "bubble",
    "Squish": "bubble",
    "Drip": "bubble",
    "Pour": "bubble",
    "Trickle, dribble": "bubble",
    "Gush": "bubble",
    "Fill (with liquid)": "bubble",
    "Spray": "bubble",
    "Pump (liquid)": "bubble",
    "Stir": "bubble",
    "Plop": "bubble",
}

RULES: list[tuple[str, tuple[str, ...]]] = [
    ("speech", ("speech", "conversation", "narration", "monologue", "babbling", "whisper", "shout", "bellow", "whoop", "yell", "scream")),
    ("laughter", ("laughter", "giggle", "snicker", "chuckle")),
    ("crying", ("cry", "sobb", "whimper", "wail", "moan")),
    ("breath", ("sigh", "breath", "wheeze", "snor", "gasp", "pant", "snort", "cough", "throat clearing", "sneeze", "sniff", "groan", "grunt")),
    ("music", ("singing", "choir", "yodel", "chant", "mantra", "rapping", "humming", "vocal music", "a capella", "song", "lullaby", "pop music", "hip hop music", "rock music", "heavy metal", "punk rock", "grunge", "progressive rock", "rock and roll", "psychedelic rock", "rhythm and blues", "soul music", "reggae", "country", "swing music", "bluegrass", "funk", "folk music", "middle eastern music", "jazz", "disco", "classical music", "opera", "house music", "techno", "dubstep", "electronica", "ambient music", "trance music", "salsa music", "flamenco", "blues", "christmas music", "dance music", "afrobeat", "gospel music", "christian music", "carnatic music", "ska", "traditional music", "independent music", "background music", "soundtrack music", "music for children", "music of ")),
    ("footsteps", ("run", "shuffle", "walk, footsteps", "clip-clop")),
    ("mouth", ("chewing", "mastication", "biting", "gargling", "stomach rumble", "burping", "eructation", "hiccup", "fart")),
    ("hands", ("hands", "finger snapping", "clapping", "slap", "smack")),
    ("heart", ("heart sounds", "heartbeat", "heart murmur")),
    ("crowd", ("crowd", "cheering", "hubbub", "children shouting", "children playing", "public space")),
    ("dog", ("dog", "bark", "yip", "howl", "bow-wow", "growling", "canidae")),
    ("cat", ("cat", "purr", "meow", "hiss", "caterwaul")),
    ("farm", ("livestock", "farm animals", "working animals", "horse", "neigh", "cattle", "pig", "oink", "goat", "bleat", "sheep", "fowl", "chicken", "rooster", "cluck", "crowing", "cock-a-doodle-doo", "turkey", "gobble", "duck", "quack", "goose")),
    ("bird", ("bird", "chirp", "tweet", "squawk", "pigeon", "dove", "coo", "crow", "caw", "owl", "hoot", "flapping wings")),
    ("insect", ("insect", "cricket", "mosquito", "fly", "buzz", "bee", "wasp")),
    ("frog", ("frog", "croak")),
    ("snake", ("snake",)),
    ("whale", ("whale",)),
    ("animal", ("animal", "pets", "wild animals", "roaring cats", "roar", "rodents", "mouse")),
    ("guitar", ("plucked string instrument", "guitar", "banjo", "sitar", "mandolin", "zither", "ukulele", "tapping (guitar technique)", "strum", "steel guitar", "slide guitar")),
    ("piano", ("keyboard (musical)", "piano", "electric piano", "organ", "harpsichord", "hammond organ")),
    ("synth", ("synth", "sampler", "synthetic singing", "electronic organ", "theremin", "harmonic", "chirp tone", "pulse", "chorus effect")),
    ("drum", ("percussion", "drum kit", "drum", "rimshot", "tabla", "cymbal", "hi-hat", "wood block", "tambourine", "maraca", "gong", "tubular bells", "mallet percussion", "marimba", "xylophone", "glockenspiel", "vibraphone", "steelpan")),
    ("strings", ("orchestra", "bowed string instrument", "string section", "violin", "fiddle", "pizzicato", "cello", "double bass", "harp")),
    ("brass", ("brass instrument", "french horn", "trumpet", "trombone")),
    ("woodwind", ("wind instrument", "woodwind instrument", "flute", "saxophone", "clarinet", "harmonica", "accordion", "bagpipes", "didgeridoo", "shofar")),
    ("bell", ("church bell", "bell", "jingle", "ding-dong", "chime", "campanology", "singing bowl", "ding", "clang", "tinkle")),
    ("boat", ("boat", "water vehicle", "sailboat", "rowboat", "canoe", "kayak", "motorboat", "speedboat", "ship")),
    ("train", ("rail transport", "train", "subway", "metro", "underground", "railroad car", "train wagon")),
    ("aircraft", ("aircraft", "jet engine", "propeller", "airscrew", "helicopter", "airplane", "fixed-wing")),
    ("vehicle", ("vehicle", "motor vehicle", "car", "horn", "honking", "toot", "car alarm", "skidding", "tire squeal", "passing by", "race car", "truck", "air brake", "air horn", "reversing beeps", "ice cream truck", "bus", "emergency vehicle", "police car", "ambulance", "fire engine", "motorcycle", "traffic noise", "roadway noise", "bicycle", "skateboard")),
    ("engine", ("engine", "lawn mower", "chainsaw", "ratchet", "pawl", "gears", "pulleys", "sewing machine", "mechanical fan", "air conditioning", "cash register", "printer", "idling", "accelerating", "revving", "vroom", "engine knocking", "dental drill")),
    ("wind", ("wind", "rustling leaves", "whoosh", "swoosh", "swish", "rustle")),
    ("storm", ("thunderstorm", "thunder")),
    ("water", ("water", "rain", "raindrop", "stream", "waterfall", "ocean", "waves", "surf", "gurgling", "steam")),
    ("fire", ("fire", "crackle", "sizzle")),
    ("door", ("door", "doorbell", "sliding door", "slam", "knock", "tap", "squeak", "cupboard", "drawer")),
    ("kitchen", ("dishes", "pots", "pans", "cutlery", "silverware", "chopping", "frying", "microwave oven", "blender")),
    ("bathroom", ("water tap", "faucet", "sink", "bathtub", "hair dryer", "toilet flush", "toothbrush", "vacuum cleaner")),
    ("keys", ("zipper", "keys jangling", "coin", "scissors", "electric shaver", "electric razor", "shuffling cards")),
    ("typing", ("typing", "typewriter", "computer keyboard", "writing")),
    ("phone", ("telephone", "ringtone", "dialing", "dtmf", "dial tone", "busy signal")),
    ("alarm", ("alarm", "siren", "buzzer", "smoke detector", "foghorn", "whistle")),
    ("clock", ("clock", "tick", "tick-tock")),
    ("camera", ("camera", "single-lens reflex camera")),
    ("tools", ("tools", "hammer", "jackhammer", "sawing", "filing", "sanding", "power tool", "drill")),
    ("gun", ("gunshot", "gunfire", "machine gun", "fusillade", "artillery", "cap gun")),
    ("explosion", ("explosion", "fireworks", "firecracker", "burst", "pop", "eruption", "boom", "bang")),
    ("tree", ("wood", "chop", "splinter", "outside, rural or natural")),
    ("glass", ("glass", "clink", "shatter")),
    ("liquid", ("liquid", "splash", "splatter", "slosh", "squish", "drip", "pour", "trickle", "dribble", "gush", "fill (with liquid)", "spray", "pump (liquid)", "stir")),
    ("click", ("clicking", "click")),
    ("impact", ("basketball bounce", "thump", "thud", "thunk", "whack", "thwack", "smash", "crash", "breaking", "bouncing", "whip", "scratch", "scrape", "rub", "roll", "crushing", "crumpling", "crinkling", "tearing", "plop", "boing", "crunch", "clickety-clack", "rumble", "squeal", "creak", "whir", "clatter", "zing")),
    ("room", ("inside, small room", "inside, large room or hall", "inside, public space", "reverberation", "echo")),
    ("sound", ("noise", "environmental noise", "static", "mains hum", "distortion", "sidetone", "cacophony", "white noise", "pink noise", "throbbing", "vibration", "television", "radio", "outside, urban or manmade")),
]


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def wrap_base64(text: str, width: int = 88) -> list[str]:
    return [text[index : index + width] for index in range(0, len(text), width)]


def png_chunk(chunk_type: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + chunk_type
        + payload
        + struct.pack(">I", zlib.crc32(chunk_type + payload) & 0xFFFFFFFF)
    )


def paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def unfilter_scanlines(raw: bytes, width: int, height: int, bpp: int) -> bytes:
    stride = width * bpp
    cursor = 0
    rows = []
    prev = bytearray(stride)

    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor : cursor + stride])
        cursor += stride

        if filter_type == 1:
            for index in range(stride):
                left = row[index - bpp] if index >= bpp else 0
                row[index] = (row[index] + left) & 0xFF
        elif filter_type == 2:
            for index in range(stride):
                row[index] = (row[index] + prev[index]) & 0xFF
        elif filter_type == 3:
            for index in range(stride):
                left = row[index - bpp] if index >= bpp else 0
                up = prev[index]
                row[index] = (row[index] + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = row[index - bpp] if index >= bpp else 0
                up = prev[index]
                up_left = prev[index - bpp] if index >= bpp else 0
                row[index] = (row[index] + paeth_predictor(left, up, up_left)) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"Unsupported PNG filter type: {filter_type}")

        rows.append(bytes(row))
        prev = row

    return b"".join(rows)


def decode_png_rgba(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG file")

    cursor = 8
    width = None
    height = None
    idat_parts: list[bytes] = []

    while cursor < len(data):
        chunk_len = struct.unpack(">I", data[cursor : cursor + 4])[0]
        chunk_type = data[cursor + 4 : cursor + 8]
        chunk_data = data[cursor + 8 : cursor + 8 + chunk_len]
        cursor += chunk_len + 12

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
            if bit_depth != 8 or color_type != 6 or compression != 0 or filter_method != 0 or interlace != 0:
                raise ValueError(f"Unsupported PNG format in {path}")
        elif chunk_type == b"IDAT":
            idat_parts.append(chunk_data)
        elif chunk_type == b"IEND":
            break

    if width is None or height is None:
        raise ValueError(f"Missing IHDR in {path}")

    raw = zlib.decompress(b"".join(idat_parts))
    return width, height, unfilter_scanlines(raw, width, height, 4)


def encode_png_rgba(width: int, height: int, pixels: bytes) -> bytes:
    stride = width * 4
    scanlines = bytearray()
    for row_index in range(height):
        scanlines.append(0)
        start = row_index * stride
        scanlines.extend(pixels[start : start + stride])

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(scanlines), level=9)

    return b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            png_chunk(b"IHDR", ihdr),
            png_chunk(b"IDAT", idat),
            png_chunk(b"IEND", b""),
        ]
    )


def build_atlas() -> tuple[bytes, int, int, OrderedDict[str, dict[str, int]]]:
    icon_count = len(ICON_FILES)
    columns = max(1, math.ceil(math.sqrt(icon_count)))
    rows = math.ceil(icon_count / columns)
    cell_size = ICON_SIZE + (ATLAS_PADDING * 2)
    atlas_width = columns * cell_size
    atlas_height = rows * cell_size
    atlas_pixels = bytearray(atlas_width * atlas_height * 4)
    rects: "OrderedDict[str, dict[str, int]]" = OrderedDict()

    for index, (icon_key, filename) in enumerate(ICON_FILES.items()):
        width, height, rgba = decode_png_rgba(ASSET_DIR / filename)
        if width != ICON_SIZE or height != ICON_SIZE:
            raise ValueError(f"Unexpected icon size for {filename}: {width}x{height}")

        column = index % columns
        row = index // columns
        dest_x = column * cell_size + ATLAS_PADDING
        dest_y = row * cell_size + ATLAS_PADDING
        rects[icon_key] = {"x": dest_x, "y": dest_y, "w": width, "h": height}

        for row_index in range(height):
            src_start = row_index * width * 4
            src_end = src_start + (width * 4)
            dst_start = ((dest_y + row_index) * atlas_width + dest_x) * 4
            atlas_pixels[dst_start : dst_start + (width * 4)] = rgba[src_start:src_end]

    return encode_png_rgba(atlas_width, atlas_height, bytes(atlas_pixels)), atlas_width, atlas_height, rects


def choose_icon_key(label: str) -> str:
    if label in EXACT_ICON_KEYS:
        return EXACT_ICON_KEYS[label]

    lowered = label.lower()
    for icon_key, patterns in RULES:
        for pattern in patterns:
            if pattern in lowered:
                return icon_key
    return "sound"


def load_labels() -> list[str]:
    labels: list[str] = []
    with CSV_PATH.open("r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            labels.append(row["display_name"])
    return labels


def generate_asset_bundle() -> str:
    atlas_png, atlas_width, atlas_height, rects = build_atlas()
    lines: list[str] = []
    lines.append("-- Generated by scripts/generate_report_emoji_assets.py")
    lines.append(f"-- Upstream: {UPSTREAM_REPO} @ {UPSTREAM_COMMIT}")
    lines.append(f"-- Image resources license: {UPSTREAM_IMAGE_LICENSE}")
    lines.append(f"-- Font software license upstream: {UPSTREAM_FONT_LICENSE}")
    lines.append("")
    lines.append("local M = {}")
    lines.append("")
    lines.append("M.UPSTREAM_REPO = " + lua_quote(UPSTREAM_REPO))
    lines.append("M.UPSTREAM_COMMIT = " + lua_quote(UPSTREAM_COMMIT))
    lines.append("M.UPSTREAM_IMAGE_LICENSE = " + lua_quote(UPSTREAM_IMAGE_LICENSE))
    lines.append("M.UPSTREAM_FONT_LICENSE = " + lua_quote(UPSTREAM_FONT_LICENSE))
    lines.append("")
    lines.append("M.ORDER = {")
    for key in ICON_FILES:
        lines.append(f"  {lua_quote(key)},")
    lines.append("}")
    lines.append("")
    lines.append(f"M.ATLAS_WIDTH = {atlas_width}")
    lines.append(f"M.ATLAS_HEIGHT = {atlas_height}")
    lines.append(f"M.ICON_SIZE = {ICON_SIZE}")
    lines.append(f"M.ATLAS_PADDING = {ATLAS_PADDING}")
    lines.append("")
    atlas_payload = base64.b64encode(atlas_png).decode("ascii")
    atlas_wrapped = wrap_base64(atlas_payload)
    lines.append(f"M.ATLAS_PNG = [[{atlas_wrapped[0]}")
    for chunk in atlas_wrapped[1:]:
        lines.append(chunk)
    lines.append("]]")
    lines.append("")
    lines.append("M.ICON_RECTS = {")
    for key, rect in rects.items():
        lines.append(
            "  %s = { x = %d, y = %d, w = %d, h = %d },"
            % (key, rect["x"], rect["y"], rect["w"], rect["h"])
        )
    lines.append("}")
    lines.append("")
    lines.append("return M")
    lines.append("")
    return "\n".join(lines)


def generate_label_map(labels: list[str]) -> tuple[str, Counter]:
    counts: Counter = Counter()
    lines: list[str] = []
    lines.append("-- Generated by scripts/generate_report_emoji_assets.py")
    lines.append(f"-- Upstream labels: {CSV_PATH.relative_to(ROOT)}")
    lines.append("")
    lines.append("local M = {}")
    lines.append("")
    lines.append("local LABEL_ICON_KEYS = {")
    for label in labels:
        icon_key = choose_icon_key(label)
        counts[icon_key] += 1
        lines.append(f"  [{lua_quote(label)}] = {lua_quote(icon_key)},")
    lines.append("}")
    lines.append("")
    lines.append("local SECTION_ICON_KEYS = {")
    for section_key, icon_key in SECTION_ICON_KEYS.items():
        lines.append(f"  {section_key} = {lua_quote(icon_key)},")
    lines.append("}")
    lines.append("")
    lines.append("function M.label_icon_key(label)")
    lines.append('  return LABEL_ICON_KEYS[tostring(label or "")] or "generic"')
    lines.append("end")
    lines.append("")
    lines.append("function M.has_known_label(label)")
    lines.append('  return LABEL_ICON_KEYS[tostring(label or "")] ~= nil')
    lines.append("end")
    lines.append("")
    lines.append("function M.section_icon_key(section_key)")
    lines.append('  return SECTION_ICON_KEYS[section_key] or "generic"')
    lines.append("end")
    lines.append("")
    lines.append("function M.label_count()")
    lines.append("  return " + str(len(labels)))
    lines.append("end")
    lines.append("")
    lines.append("return M")
    lines.append("")
    return "\n".join(lines), counts


def main() -> None:
    missing = [filename for filename in ICON_FILES.values() if not (ASSET_DIR / filename).exists()]
    if missing:
        raise SystemExit("Missing icon assets: " + ", ".join(missing))

    labels = load_labels()
    ASSET_OUTPUT.write_text(generate_asset_bundle(), encoding="utf-8")
    map_bundle, counts = generate_label_map(labels)
    MAP_OUTPUT.write_text(map_bundle, encoding="utf-8")
    summary = ", ".join(f"{key}={counts[key]}" for key in sorted(counts))
    print(f"Wrote {ASSET_OUTPUT.relative_to(ROOT)}")
    print(f"Wrote {MAP_OUTPUT.relative_to(ROOT)}")
    print(f"Label coverage: {len(labels)} labels")
    print(f"Counts: {summary}")


if __name__ == "__main__":
    main()
