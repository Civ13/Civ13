# OpenDream compiler warning inventory

The pinned local compiler reported 103 warnings before the source cleanup and
64 afterward. Native BYOND 516.1681 compiled the updated game with zero errors
and zero warnings. Counts depend on the compiler revision and source checkout.

The remaining OD2800 warnings identify engine features, not redundant DM syntax:

| Count | Missing engine feature | Impact to investigate |
| --- | --- | --- |
| 46 | `set src = view()` | OpenDream substitutes range selection; visibility and obstruction behavior needs engine parity. |
| 10 | `set instant` | Instant verb scheduling is unavailable, including movement and ping verbs. |
| 1 | `icon.Crop()` | Flattened icons may retain unwanted bounds. |
| 5 | `shell()` | Legacy Python hooks and chat-overlay helpers cannot execute through this API. |
| 2 | `run()` | Legacy admin log-opening verbs cannot launch external programs through this API. |

Do not suppress these diagnostics or replace visibility checks with range checks
just to obtain a clean build. Engine compatibility changes need focused native
parity checks. External execution requires explicit process/security boundaries.
This inventory does not establish graphical or live-server acceptance.
