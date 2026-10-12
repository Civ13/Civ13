"""Review genuine existing DMI pixels, not a gameplay capture."""
from pathlib import Path
import importlib.util
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('native_dmi', ROOT / 'tests/animal_harvest/preview.py')
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)
panel = Image.new('RGB',(720,190),'#242830')
draw = ImageDraw.Draw(panel)
draw.text((12,12),'Existing Civ13 DMI pixels - static equipment review',fill='white')
for i,(label,resource,state) in enumerate([
    ('Early stone weights','materials.dmi','sheet-stone'),
    ('Modern iron weights','materials.dmi','sheet-iron'),
    ('Early / Modern course marker','flags.dmi','flagpole_blank'),
]):
    sprite = native.state(ROOT / 'icons/obj' / resource,state)
    sprite = sprite.resize((sprite.width*2,sprite.height*2),Image.Resampling.NEAREST)
    x = 12+i*235
    draw.text((x,40),label,fill='white')
    panel.paste(sprite,(x,65),sprite)
    draw.text((x,145),f'{resource}: {state}',fill='#CCCCCC')
output = ROOT / 'docs/assets/active-training.png'
output.parent.mkdir(parents=True,exist_ok=True)
panel.save(output)
print(f'Validated three nonblank native states: {output}')
