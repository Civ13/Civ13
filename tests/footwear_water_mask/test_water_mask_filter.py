"""Source contracts for sharing the unattached water-mask filter."""
import unittest

from prepare import ROOT, SOURCE, procedure


def source():
    return (ROOT / SOURCE).read_text(encoding='utf-8')


def water_mask_filter_contract(text):
    mask = procedure(text, 'proc/apply_water_mask')
    wet, dry = mask.split('\n\telse\n', 1)
    assert wet.count('filter(type=') == 1
    assert 'var/mask_filter = filter(type="alpha", icon=mask_icon, flags=MASK_INVERSE)' in wet
    assert (
        '\t\tfilters += mask_filter\n'
        '\t\tfor(var/over in overlays_standing)\n'
        '\t\t\tvar/image/img = over'
    ) in wet
    assert '\t\t\tif(img)\n\t\t\t\timg.filters = null\n\t\t\t\timg.filters += mask_filter' in wet
    assert '\t\tfilters = null\n\t\tclear_overlay_filters()' in dry


class WaterMaskFilterContracts(unittest.TestCase):
    def test_wet_mask_constructs_one_filter_and_attaches_it_to_every_owner(self):
        water_mask_filter_contract(source())

    def test_filter_reuse_controls_are_rejected(self):
        text = source()
        attach = 'img.filters += mask_filter'
        alpha = 'filter(type="alpha", icon=mask_icon, flags=MASK_INVERSE)'
        for old, new in (
            (attach, 'img.filters += ' + alpha),
            (attach, '// no standing-overlay mask'),
            ('\t\tfilters += mask_filter', '\t\t// no body mask'),
            ('\t\tclear_overlay_filters()', '\t\t// stale overlay masks'),
        ):
            with self.subTest(control=new), self.assertRaises(AssertionError):
                water_mask_filter_contract(text.replace(old, new, 1))
