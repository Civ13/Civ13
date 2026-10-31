"""Pure case selection for the isolated benchmark; never launches processes.

Diagnostic cases narrow the approved grid and omit baseline comparisons. They
cannot replace the final full matrix or establish comparative memory acceptance.
"""

DIAGNOSTIC_CASES = ((64, 1024), (512, 16384), (2048, 1024), (2048, 16384))


def select_case_plan(full_cases, diagnostic_subset=False):
    """Return fresh cases and honest receipt labels, without resource changes."""
    full = [dict(case) for case in full_cases]
    if diagnostic_subset:
        selected = [dict(count=count, payload=payload, baseline=0)
                    for count, payload in DIAGNOSTIC_CASES]
        if any(case not in full for case in selected):
            raise ValueError('Diagnostic case is outside the approved full matrix')
    else:
        selected = full
    return dict(
        cases=selected,
        benchmark_mode='diagnostic_subset' if diagnostic_subset else 'full_matrix',
        comparative=not diagnostic_subset,
        interpretation=('Candidate-only diagnostic subset; not comparative memory '
                        'evidence or full-matrix acceptance. Run the full matrix '
                        'after an actual fix.' if diagnostic_subset else
                        'Paired same-head baseline/candidate matrix; passing alone '
                        'does not establish memory acceptance.'),
    )
