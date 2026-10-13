"""Validate and preview the existing solar controller sprite, without BYOND."""
import argparse
import importlib.util
from pathlib import Path
from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location("dmi_preview", root / "tests/animal_harvest/preview.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    sprite = helper.state(root / "icons/obj/computers.dmi", "solar_screen")
    canvas = Image.new("RGB", (480, 240), "#242830")
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), "Existing Civ13 solar controller - actual DMI pixels", fill="white")
    canvas.paste(sprite.resize((128, 128), Image.Resampling.NEAREST), (16, 50), sprite.resize((128, 128), Image.Resampling.NEAREST))
    draw.text((162, 60), "computers.dmi / solar_screen\nController graphic, not panel art.\n4x nearest-neighbor preview.\nNot a gameplay capture.", fill="white")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)
    print(f"Validated nonempty solar_screen pixels: {args.output}")


if __name__ == "__main__":
    main()
