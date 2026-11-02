"""Offline negative controls for species fallback fixture and host oracle."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


contract = load("species_contract", HERE / "species_fallback_contract.py")
stage = load("species_stage", HERE / "species_fallback_stage.py")
HEAD = "a" * 40


def event(case, ident, label, y, px=0, **state):
    result = dict(event=label, time=0.5, case=case, id=ident, x=6 + px // 32, y=y, z=1,
                  sx=px % 32, sy=0, enabled=0, species_enabled=0, owned=0,
                  transaction=0, pulse=0, wild=0, generation=1, until=0,
                  tick_lag=0.5, ticks=1, health=10, turns=0, bx=0, by=0, bw=32, bh=32, step_size=32, locs=1,
                  map_x=18, map_y=14, icon_size=32, detail=None)
    result.update(state)
    return result


def sample():
    rows=[]
    for idx, case in enumerate(contract.CASES, 1):
        y = 5 if case.startswith("crab") else 8 if case.startswith("mosquito") else 11
        make = lambda label, at, px=0, **kw: event(case, idx, label, y, px, time=at, **kw)
        events=[make("start",0.5)]
        complete=0
        if case.startswith("crab"):
            sp=int(case=="crab_mixed")
            events += [make("life_before",0.5,species_enabled=sp), make("move_before",0.5,species_enabled=sp),
                       make("move_after",0.5,32,species_enabled=sp),make("life_after",0.5,32,species_enabled=sp),
                       make("end",0.5,32,species_enabled=sp)]
        elif case.startswith("mosquito"):
            sp=int(case=="mosquito_mixed")
            events += [make("command_before",0.5,species_enabled=sp),make("command_after",0.5,species_enabled=sp),
                       make("move_before",3.5,species_enabled=sp),make("move_after",3.5,32,species_enabled=sp),
                       make("before_stop",7.5,32,species_enabled=sp),make("after_stop",7.5,32,species_enabled=sp)]
            events += [make("quiet_sample",7.5+n*0.5,32,species_enabled=sp) for n in range(1,9)]
            events.append(make("end",11.5,32,species_enabled=sp))
        elif case == "setter":
            events += [make("wild_before",0.5,enabled=1,species_enabled=1),
                       make("wild_after",0.5,enabled=1,species_enabled=1,wild=1,generation=2),
                       make("before_disable",0.5,enabled=1,species_enabled=1,wild=1,generation=2,detail={"owner_generation":2,"owner_revision":1}),
                       make("after_disable",0.5,species_enabled=1,generation=3,detail={"old_cancelled":1,"owner_generation":2,"owner_revision":1}),
                       make("move_before",3.5,species_enabled=1,generation=3),make("move_after",3.5,32,species_enabled=1,generation=3),
                       make("replacement_stop",7.5,32,species_enabled=1,generation=3)]
            events += [make("quiet_sample",7.5+n*0.5,32,species_enabled=1,generation=3) for n in range(1,9)]
            events.append(make("end",11.5,32,species_enabled=1,generation=3))
        else:
            st=dict(enabled=1,species_enabled=1,wild=1,transaction=1,owned=1,generation=2)
            info={"owner_generation":2,"owner_revision":1}
            events += [make("wild_before",0.5,enabled=1,species_enabled=1),
                       make("wild_after",0.5,enabled=1,species_enabled=1,wild=1,generation=2),
                       make("step_before",4.5,enabled=1,species_enabled=1,wild=1,generation=2),
                       make("move_before",4.5,**st),make("move_after",4.5,2,**st),
                       make("step_after",4.5,2,**st),make("partial_before",5,2,detail=info.copy(),**st),
                       make("partial_after",5,2,detail=info.copy(),**st),
                       make("fault_base_off",5,2,species_enabled=1,wild=1,transaction=1,owned=1,generation=2),
                       make("fallback_refused",5,2,species_enabled=1,wild=1,transaction=1,owned=1,generation=2,
                            detail={"result":0,"same_owner":1,"same_tx":1}),
                       make("completion",5.5,2,species_enabled=1,owned=1,generation=3),
                       make("partial_stopped",5.5,2,species_enabled=1,owned=1,generation=3)]
            events += [make("quiet_sample",5.5+n*0.5,2,species_enabled=1,owned=1,generation=3) for n in range(1,9)]
            events.append(make("end",9.5,2,species_enabled=1,owned=1,generation=3))
            complete=1
        for e in events:
            e["time"] += (idx-1)*40
        rows.append(dict(case=case,id=idx,events=events,completions=complete))
    return dict(head=HEAD,error=None,port=0,byond_version=516,byond_build=1688,
                scope=stage.SCOPE,species_checks=187,species_rows=rows)


class ReceiptContracts(unittest.TestCase):
    def test_valid_synthetic_receipt(self):
        self.assertEqual(contract.validate(sample(),HEAD)["cases"],list(contract.CASES))

    def test_rejects_zero_motion_and_missing_move_return(self):
        row=sample()
        for e in row["species_rows"][1]["events"]:
            e.update(x=6,sx=0)
        with self.assertRaises(ValueError): contract.validate(row,HEAD)
        row=sample()
        row["species_rows"][0]["events"].pop(3)
        with self.assertRaises(ValueError): contract.validate(row,HEAD)

    def test_rejects_late_move_even_if_it_returns_to_stop(self):
        row=sample(); ev=row["species_rows"][2]["events"]
        after=copy.deepcopy(ev[-1]); after["event"]="move_before"; after["time"]-=0.2
        ret=copy.deepcopy(after); ret["event"]="move_after";ret["time"]+=0.1
        ev[-1:-1]=[after,ret]
        with self.assertRaises(ValueError): contract.validate(row,HEAD)

    def test_rejects_unobserved_displacement_and_stale_owner(self):
        row=sample();row["species_rows"][3]["events"][-1]["x"]+=1
        with self.assertRaises(ValueError): contract.validate(row,HEAD)
        row=sample()
        after=next(e for e in row["species_rows"][4]["events"] if e["event"]=="after_disable")
        after["detail"]["owner_generation"]=99
        with self.assertRaises(ValueError): contract.validate(row,HEAD)

    def test_rejects_terminal_or_quiet_reacquisition_without_movement(self):
        for field in ("transaction","pulse","wild"):
            row=sample(); row["species_rows"][2]["events"][-1][field]=1
            with self.subTest(endpoint=field), self.assertRaisesRegex(ValueError,"terminal ownership"):
                contract.validate(row,HEAD)
            row=sample(); e=next(e for e in row["species_rows"][2]["events"] if e["event"]=="quiet_sample")
            e[field]=1
            with self.subTest(quiet=field), self.assertRaisesRegex(ValueError,"quiet owner or motion"):
                contract.validate(row,HEAD)
        row=sample(); ev=row["species_rows"][2]["events"]; stop=next(i for i,e in enumerate(ev) if e["event"]=="after_stop")
        e=copy.deepcopy(ev[stop]);e["event"]="wild_before";e["time"]+=0.1
        end=copy.deepcopy(e);end["event"]="wild_after";end["time"]+=0.1
        ev[stop+1:stop+1]=[e,end]
        with self.assertRaisesRegex(ValueError,"quiet coverage or unexpected admission"):
            contract.validate(row,HEAD)

    def test_rejects_equal_null_or_noninteger_owner_identity(self):
        for bad in (None,"2",2.0,True):
            row=sample();ev=row["species_rows"][4]["events"]
            for e in ev:
                if e["event"] in ("before_disable","after_disable"):
                    e["detail"]["owner_generation"]=bad
            with self.subTest(bad=bad), self.assertRaisesRegex(ValueError,"malformed owner identity"):
                contract.validate(row,HEAD)
        for bad in (None,"1",1.0,True):
            row=sample();ev=row["species_rows"][5]["events"]
            for e in ev:
                if e["event"] in ("partial_before","partial_after"):
                    e["detail"]["owner_revision"]=bad
            with self.subTest(revision=bad), self.assertRaisesRegex(ValueError,"malformed owner identity"):
                contract.validate(row,HEAD)

    def test_rejects_equal_invalid_event_generation_and_lifetime(self):
        for bad in (None, "2", 2.0, True):
            row=sample()
            for e in row["species_rows"][5]["events"]:
                if e["event"] in ("partial_before","partial_after"):
                    e["generation"]=bad
            with self.subTest(generation=bad), self.assertRaisesRegex(ValueError,"event"):
                contract.validate(row,HEAD)
        row=sample();row["species_rows"][0]["id"]=True
        with self.assertRaisesRegex(ValueError,"case lifetime"):
            contract.validate(row,HEAD)

    def test_rejects_overlapping_lifetimes_or_missing_stop_boundary(self):
        row=sample()
        for e in row["species_rows"][2]["events"]: e["time"]-=100
        with self.assertRaisesRegex(ValueError,"overlapping case lifetimes"):
            contract.validate(row,HEAD)
        row=sample();ev=row["species_rows"][2]["events"]
        ev.pop(next(i for i,e in enumerate(ev) if e["event"]=="before_stop"))
        with self.assertRaisesRegex(ValueError,"expected exactly one before_stop"):
            contract.validate(row,HEAD)

    def test_rejects_partial_offset_in_setter_aligned_case(self):
        row=sample();ev=row["species_rows"][4]["events"]
        before=next(i for i,e in enumerate(ev) if e["event"]=="before_disable")
        a=copy.deepcopy(ev[before]);a.update(event="move_before",sx=0)
        b=copy.deepcopy(a);b.update(event="move_after",sx=2)
        ev[before:before]=[a,b]
        for e in ev[before+2:]:
            e["sx"]=2
        with self.assertRaisesRegex(ValueError,"aligned owner"):
            contract.validate(row,HEAD)

    def test_rejects_truncation_wrong_scope_and_bad_cleanup(self):
        for edit in ("truncated","scope","cleanup","overflow","missing_assertions","bounds","missing_geometry","wrong_tick"):
            row=sample()
            if edit=="truncated": row["species_rows"].pop()
            if edit=="scope": row["scope"]="native scheduler"
            if edit=="cleanup": row["species_rows"][-1]["completions"]=0
            if edit=="overflow": row["species_rows"][0]["events"]*=100
            if edit=="missing_assertions": row["species_checks"]=1
            if edit=="bounds": row["species_rows"][0]["events"][0]["bw"]=96
            if edit=="missing_geometry": del row["species_rows"][0]["events"][0]["bx"]
            if edit=="wrong_tick": row["species_rows"][0]["events"][0]["tick_lag"]=1
            with self.subTest(edit=edit), self.assertRaises(ValueError): contract.validate(row,HEAD)


class StageContracts(unittest.TestCase):
    def test_fixture_records_actual_geometry_without_literal_line_escapes(self):
        source=(HERE/"species_fallback_fixture.dm").read_text(encoding="utf-8")
        self.assertNotIn(chr(92)+"n\t", source)
        for token in ('"bx" = bound_x', '"by" = bound_y', '"bw" = bound_width',
                      '"bh" = bound_height', '"step_size" = step_size', '"locs" = locs.len',
                      '"map_x" = world.maxx', '"map_y" = world.maxy', '"icon_size" = world.icon_size'):
            self.assertIn(token,source)

    def test_staging_uses_fixed_preimages_and_never_runs_a_daemon(self):
        probe='''\t\t\thuman_subtile_fixture_headless()
"checks" = human_subtile_fixture_checks,
"scope" = "actual human/codec; headless authority adapter"
'''
        with tempfile.TemporaryDirectory() as temp:
            out=Path(temp); base=out/"stage"; (base/"tests/human_subtile").mkdir(parents=True)
            (base/"tests/human_subtile/probe.dm").write_text(probe,encoding="utf-8")
            (base/"tests/human_subtile/species_fallback_fixture.dm").write_text("fixture",encoding="utf-8")
            (base/"human_subtile.dme").write_text("base",encoding="utf-8")
            manifest={"dme":"stage/human_subtile.dme","stage_files":{}}
            class Adapter:
                def adapt(self,out,manifest,path,before,after):
                    p=out/"stage"/path
                    text=p.read_text(encoding="utf-8")
                    if text.count(before)!=1: raise ValueError("preimage")
                    p.write_text(text.replace(before,after),encoding="utf-8")
            stage.adapt(out,manifest,Adapter())
            self.assertFalse(manifest["native_executed"])
            self.assertIn("species_fallback_main()", (base/"tests/human_subtile/probe.dm").read_text())
            self.assertIn("species_fallback_fixture.dm",(base/"human_subtile.dme").read_text())
            with self.assertRaises(ValueError): stage.adapt(out,manifest,Adapter())


if __name__ == "__main__":
    unittest.main(verbosity=2)
