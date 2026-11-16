# Tiki torch dismantling

An unlit tiki torch hit with a hammer or any blade comes apart, after a short
wait, into a tool handle and two sheets of the material its pole was made of
(logs for wood, bundles for bamboo). Lit torches and mapped unlimited fixtures
refuse. A lump of animal fat also refuels a tiki torch.

Offline source checks: `python3 -m unittest tests.test_light_fuel`

Native probe (after `bash scripts/cloud_byond_setup.sh` on Linux):

```bash
python3 tests/ecology_spawning/run_linux.py . tests/tiki_torch_dismantle/probe.dm 300
```
