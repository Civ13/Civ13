"""Synthetic offline provenance boundary, never a native compiler/receipt claim."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
HEAD='a'*40
def snapshot(provenance,head=HEAD):
    sources={p:(ROOT/p).read_bytes() for p in provenance.SOURCES}
    sources={p:d if p in provenance.ASSETS else d.replace(b'\r\n',b'\n') for p,d in sources.items()}
    return dict(head=head,tree='b'*40,sources=sources)

def fake_compile(root,provenance,head=HEAD):
    """Test-only injected producer evidence. No executable or native pixels."""
    inputs=provenance.validate_stage(root,head)
    (root/'fixture.dmb').write_bytes(b'offline fake compiled content, never executed')
    (root/'fixture.rsc').write_bytes(b'offline fake resources, never executed')
    log=b'DM compiler version 516.1688\nfixture.dmb - 0 errors, 0 warnings\n'
    command=[str(root/'dm.exe'),'-max_errors','0',str(root/'fixture.dme')]
    audit=dict(head=head,failed=False,phases=[dict(phase='compile',argv=command,cwd=str(root),accepted=True,
        owned_exit_evidence_complete=True,samples=[dict(total=1,retained=1,sockets=[])],
        final=dict(exit_code=0,total_processes=1,active_processes=0),
        cleanup=dict(all_retained_exited=True,total_assigned=1,errors=[],captured_unexpected=[],exits=[dict(exit_code=0)]))])
    raw=json.dumps(audit).encode();(root/'compile.log').write_bytes(log);(root/'compile-supervisor.json').write_bytes(raw)
    receipt=dict(schema=3,kind='root_tree_compile',head=head,input_binding=inputs,passed=True,exit_code=0,
        dme=str(root/'fixture.dme'),command=command,compile_only=True,runtime_executed=False,
        compiler_sha256=inputs['compiler_sha256'],artifacts=provenance.output_artifacts(root),
        compiler_log_sha256=hashlib.sha256(log).hexdigest(),supervisor_sha256=hashlib.sha256(raw).hexdigest())
    (root/'compile.receipt.json').write_text(json.dumps(receipt))
    return receipt
