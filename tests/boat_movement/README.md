# Constructed boat movement regression

Baseline master 0d38999d5f9f987a944493f11c456537f39ac2f6, Windows BYOND 516.1681: a NORTH-facing 2x3 ship with its axis in the northwest frame rotates an item on the adjacent water tile (outside the deck) when do_matrix(NORTH,EAST,"right") executes. The isolated probe extracts production movement/rotation procedures and uses no-op audiovisual effects and temporary world state.

Run tests/boat_movement/run.ps1 -ByondBin <BYOND-bin> -Revision <baseline-sha> -Baseline. Runtime output shows PASS rectangular quarter turn and FAIL object outside deck stays put. Full-game replication: assemble a rectangular hull with axis in the top-left frame, place an item beside the narrow hull inside its square turning area, lift anchor and turn right while moving. The item should stay outside the boat.

Investigation in progress: passenger/cargo membership, placeholder footprint, shoreline/boundary preflight and repeated turns. Gameplay screenshots and movement video remain required; fixture output is not full-game acceptance.
