# NanoUI ownership regression

Run with a verified Python interpreter:

```text
run.py --byond-bin <516.1681-bin> --evidence-dir <temporary-evidence-directory>
run.py --byond-bin <516.1681-bin> --baseline --evidence-dir <temporary-evidence-directory>
```

The native fixture extracts production NanoUI variable declarations, the full constructor, close, reinitialise and initial-data setter. Only close's browser send is replaced with an injected adapter. Browser opening, the NanoUI manager and asset transport are isolated adapters; this does not start Civ13, attach a client or display an interface. The native world closes its listening port at startup, uses temporary storage and deletes its generated build/runtime files.

Five waves of 100 independently constructed/closed child UIs run under one live master. The fixed master retains zero closed children in every wave. The immutable baseline `f556e39b93fc97f41020b2d8c5f2abed63fab497` retains 100, 200, 300, 400 and 500 children. Its control exits successfully only when the exact expected independent-close ownership failure occurs and no engine error or unexpected assertion occurs. Success for that control means the historical defect was detected.

Further checks cover reciprocal constructor attachment, manager adapter deregistration, closing every sibling and grandchild once, clearing automatic updates and topic state, repeated close, and same-datum reinitialise with a replacement template/data. Closing historically clears the parent relationship; reopening that datum preserves this existing behavior.

The production fix removes an independently closed UI from its master's child list before clearing `master_ui`. Master closure iterates a copy so children's detach operations cannot alter the sibling traversal.

Optional evidence records the production source, adapted extracted source, fixture, compiler/runtime logs, SHA256 hashes, tested commit and checkout dirtiness. Native BYOND 516.1681 reports zero compiler errors/warnings and no runtime errors for both fixed and baseline runs. These checks establish retained ownership and call behavior, not browser rendering, user acceptance, full-server memory or OOM remediation.
