"""Offline comparison primitives. Similarity does not waive geography invariants."""
from collections import Counter
from .validator import validate


def fraction_distance(reference_counts, candidate_counts):
    """Half-L1 distance (0 identical proportions, 1 disjoint classes)."""
    for counts in [reference_counts,candidate_counts]:
        if not counts or any(type(v) is not int or v<0 for v in counts.values()) or sum(counts.values())<=0:
            raise ValueError("nonnegative counts and positive totals required")
    rt,ct=sum(reference_counts.values()),sum(candidate_counts.values())
    labels=set(reference_counts)|set(candidate_counts)
    return sum(abs(reference_counts.get(k,0)/rt-candidate_counts.get(k,0)/ct) for k in labels)/2


def compare_semantic_ir(reference,candidate):
    """Exact comparison of modeled semantics, excluding seed/version identity.
    This compares prototype IR only. It is not exact DMM/atom reconstruction.
    """
    rerrors,cerrors=validate(reference),validate(candidate)
    if rerrors or cerrors:
        return {"status":"INVARIANT_REJECTED","exact_ir":None,"fraction_distance":None}
    geometry=("width","height","active_layer")
    if any(reference[k]!=candidate[k] for k in geometry) or set(reference["layers"])!=set(candidate["layers"]):
        return {"status":"INCOMPARABLE_GEOMETRY","exact_ir":False,"fraction_distance":None}
    fields=("profile","active_layer","width","height","layers","ports","rivers","lakes","starts","portals")
    exact=all(reference[k]==candidate[k] for k in fields)
    def counts(d):
        return Counter(c["terrain"] for row in d["layers"][d["active_layer"]]["cells"] for c in row)
    return {"status":"COMPARED_OFFLINE_IR","exact_ir":exact,
            "fraction_distance":fraction_distance(counts(reference),counts(candidate)),
            "structural_acceptance":"UNAVAILABLE_WITHOUT_FROZEN_REFERENCE_ANNOTATIONS"}
