# Crop diagnostics regression

Run `pwsh -NoProfile -File tests/plant_diagnostics/run.ps1 -ByondBin <516.1681-bin>`.
The runner extracts the production farming_diagnostics proc without rewriting its body.
The temporary BYOND world tests skill boundaries, water/soil thresholds, dead/static plants,
water-independent crops and read-only behavior. It does not launch game systems or make
network calls. Temporary compiler/runtime outputs are removed, including on failure.
The full game compile checks integration with examine; the isolated fixture does not
prove live chat rendering or whole-game memory performance.
