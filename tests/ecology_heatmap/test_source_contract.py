"""OFFLINE SOURCE CONTRACTS ONLY. Does not execute or compile DreamMaker."""
from pathlib import Path
import ast
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
DM=ROOT/'code/modules/ecology/activity_heatmap.dm'

def contracts(source):
    errors=[]
    required={
      'no_persistence':'should_save = FALSE',
      'bounded_snapshot':'occupied_cells.len > 256',
      'unknown_on_incomplete':'if (complete != TRUE || !islist(occupied_cells)',
      'capacity_guard':'if (cells.len + additional > cell_limit)',
      'epoch_reset':'\tepoch++\n\tcells = list()\n\tlast_bucket = -1\n\tcoverage_valid = TRUE',
      'finite_range':'return isnum(value) && value >= low && value <= high',
      'score_cap':'cells[key] = list(min(1, score + sample_increment), now)',
      'unknown_not_zero':'return null // UNKNOWN is distinct from numeric zero.',
      'clock_guard':'now < last_time',
    }
    for name,token in required.items():
        if token not in source: errors.append(name)
    # These are intentionally syntactic contracts, not a DM parser.
    body=source[source.index('/datum/ecology_activity_heatmap/proc/sample('):source.index('/datum/ecology_activity_heatmap/proc/pressure(')]
    if body.find('complete != TRUE') > body.find('bucket == last_bucket'):
        errors.append('complete_before_dedup')
    if body.find('cells.len + additional > cell_limit') > body.find('cells[key] = list('):
        errors.append('validate_before_scores')
    for name,end in [('sample','pressure'),('pressure','reset_epoch')]:
        proc=source.split('/datum/ecology_activity_heatmap/proc/'+name+'(',1)[1].split('/datum/ecology_activity_heatmap/proc/'+end+'(',1)[0]
        gate='if (isnull(expected_epoch) || expected_epoch != epoch)'
        if 'expected_epoch = null)' not in proc or gate not in proc or proc.find(gate)>proc.find('accept_time(now)'):
            errors.append(name+'_epoch_binding')
    return errors


class SourceContracts(unittest.TestCase):
    def test_exact_ci_registration_and_dependencies(self):
        tree=ast.parse((ROOT/'scripts/ci_baseline.py').read_text())
        suites=next(node.value for node in tree.body if isinstance(node,ast.Assign)
                    and any(isinstance(t,ast.Name) and t.id=='SUITES' for t in node.targets))
        row=next(value for key,value in zip(suites.keys,suites.values)
                 if isinstance(key,ast.Constant) and key.value=='ecology_heatmap')
        spec=ast.literal_eval(row)
        self.assertEqual(spec['files'],('tests/ecology_heatmap/test_source_contract.py',))
        self.assertIn('code/modules/ecology/activity_heatmap.dm',spec['paths'])
        self.assertIn('tests/ecology_heatmap/',spec['paths'])
        # DME is intentionally shared/unmapped, preserving all-suite fallback.
        self.assertNotIn('civ13.dme',spec['paths'])
        # Registry edits already trigger all reviewed suites via CI_PATHS.
        self.assertIn("'scripts/ci_baseline.py'",(ROOT/'scripts/ci_baseline.py').read_text())

    def test_reviewed_imports_and_no_runner_calls(self):
        source=Path(__file__).read_text()
        tree=ast.parse(source)
        imports={node.module if isinstance(node,ast.ImportFrom) else alias.name
                 for node in ast.walk(tree) if isinstance(node,(ast.Import,ast.ImportFrom))
                 for alias in node.names}
        self.assertEqual(imports,{'pathlib','ast','re','unittest'})
        self.assertFalse(any(isinstance(node,ast.Call) and isinstance(node.func,ast.Name)
                             and node.func.id in {'eval','exec','__import__','open'}
                             for node in ast.walk(tree)))

    def test_required_contracts(self):
        self.assertEqual(contracts(DM.read_text()),[])

    def test_dme_includes_candidate_exactly_once(self):
        text=(ROOT/'civ13.dme').read_text()
        self.assertEqual(text.count('#include "code\\modules\\ecology\\activity_heatmap.dm"'),1)

    def test_no_activation_or_game_operations(self):
        text=DM.read_text()
        code='\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//'))
        for token in ['world.','client','ckey','/mob','/process','spawn(', 'sleep(', 'new ', 'qdel(', 'del(', 'register(']:
            self.assertNotIn(token,code)
        self.assertTrue(all(line.startswith('/datum/ecology_activity_heatmap') for line in code.splitlines() if line.startswith('/')))

    def test_all_fields_runtime_excluded(self):
        text=DM.read_text()
        fields=re.findall(r'var/tmp/(?:list/)?(\w+)\s*=',text)
        exclusion=text.split('/datum/ecology_activity_heatmap/persistence_runtime_var(key)',1)[1].split('/datum/ecology_activity_heatmap/Destroy()',1)[0]
        self.assertEqual(len(fields),10)
        for field in fields:
            self.assertIn('"'+field+'"',exclusion)
        self.assertIn('return ..()',exclusion)

    def test_bounded_policy_and_coordinates(self):
        text=DM.read_text()
        for token in ['max_cells, 1, 4096','interval, 1, 3600','half_life, 1, 86400','increment, 0.0001, 1','row.len != 3','row[1], 1, 4096','row[2], 1, 65535','row[3], 1, 65535','value == round(value)']:
            self.assertIn(token,text)

    def test_lifecycle_and_caller_clock(self):
        text=DM.read_text()
        self.assertIn('proc/accept_time(now)',text)
        self.assertIn('epoch >= 1000000',text)
        self.assertIn('cells = null\n\treturn ..()',text)
        self.assertIn('complete = FALSE',text)
        self.assertNotIn('world.time',text)

    def test_snapshot_dedup_and_no_global_scan(self):
        text=DM.read_text()
        for token in ['if (staged[key])','staged[key] = TRUE','if (!cells[key])','for (var/key in staged)']:
            self.assertIn(token,text)
        self.assertNotIn(' in cells)',text)

    def test_epoch_binding_precedes_mutation(self):
        text=DM.read_text()
        for name,end,result in [('sample','pressure','FALSE'),('pressure','reset_epoch','null')]:
            proc=text.split('/datum/ecology_activity_heatmap/proc/'+name+'(',1)[1].split('/datum/ecology_activity_heatmap/proc/'+end+'(',1)[0]
            self.assertIn('expected_epoch = null)',proc)
            self.assertIn('if (isnull(expected_epoch) || expected_epoch != epoch)\n\t\treturn '+result,proc)
            self.assertLess(proc.index('expected_epoch != epoch'),proc.index('accept_time(now)'))

    def test_epoch_binding_mutations(self):
        text=DM.read_text()
        for name,end in [('sample','pressure'),('pressure','reset_epoch')]:
            start=text.index('/datum/ecology_activity_heatmap/proc/'+name+'(')
            stop=text.index('/datum/ecology_activity_heatmap/proc/'+end+'(')
            block=text[start:stop]
            for before,after in [('isnull(expected_epoch) || expected_epoch != epoch','FALSE'),('expected_epoch = null)','expected_epoch = 0)')]:
                with self.subTest(proc=name,mutation=before):
                    changed=text[:start]+block.replace(before,after)+text[stop:]
                    self.assertIn(name+'_epoch_binding',contracts(changed))

    def test_source_mutation_controls(self):
        text=DM.read_text()
        changes=[
          ('should_save = FALSE','should_save = TRUE','no_persistence'),
          ('occupied_cells.len > 256','occupied_cells.len > 999999','bounded_snapshot'),
          ('complete != TRUE','FALSE','unknown_on_incomplete'),
          ('cells.len + additional > cell_limit','FALSE','capacity_guard'),
          ('value >= low && value <= high','TRUE','finite_range'),
          ('min(1, score + sample_increment)','score + sample_increment','score_cap'),
          ('return null // UNKNOWN is distinct from numeric zero.','return 0','unknown_not_zero'),
          ('now < last_time','FALSE','clock_guard'),
        ]
        for before,after,expected in changes:
            with self.subTest(control=expected):
                self.assertEqual(text.count(before),1)
                self.assertIn(expected,contracts(text.replace(before,after)))

if __name__=='__main__':
    unittest.main()
