"""Bounded offline candidate/repair harness with injected candidate factories.
surface_generator.py is the separate first SURFACE backend; no native adapter runs.
"""
from copy import deepcopy
from .validator import validate, canonical_hash


def evaluate(seed_ids, candidate_factory, *, candidate_budget, repair_budget=0, repair=None):
    if not 1 <= candidate_budget <= 1024 or not 0 <= repair_budget <= 3:
        raise ValueError("candidate budget 1..1024; repair budget 0..3")
    if len(seed_ids)!=len(set(seed_ids)) or any(not isinstance(s,str) for s in seed_ids):
        raise ValueError("unique string seed ids required")
    audit=[]
    for attempt,seed in enumerate(seed_ids[:candidate_budget]):
        doc=deepcopy(candidate_factory(seed));original=canonical_hash(doc)
        identity_keys=("schema","seed","algorithm_version","content_version","profile_version","profile","active_layer","width","height")
        identity={k:deepcopy(doc.get(k)) for k in identity_keys} if isinstance(doc,dict) else {}
        def check(candidate):
            reasons=validate(candidate)
            if not isinstance(candidate,dict) or candidate.get("seed")!=seed:
                reasons.append({"code":"SEED_IDENTITY","detail":"candidate seed differs from requested seed"})
            if isinstance(candidate,dict) and any(candidate.get(k)!=v for k,v in identity.items()):
                reasons.append({"code":"REPAIR_IDENTITY","detail":"repair changed immutable generation identity"})
            return reasons
        reasons=check(doc); initial_reasons=deepcopy(reasons);repairs=[]
        for repair_index in range(repair_budget):
            if not reasons or repair is None:break
            previous=canonical_hash(doc)
            prior_reasons=deepcopy(reasons)
            proposal=repair(deepcopy(doc),deepcopy(reasons),repair_index)
            if proposal is None:break
            doc=deepcopy(proposal)
            reasons=check(doc)
            repairs.append({"index":repair_index,"before":previous,"after":canonical_hash(doc),
                            "trigger_reasons":prior_reasons,"remaining_reasons":deepcopy(reasons)})
        audit.append({"attempt":attempt,"seed":seed,"input_hash":original,"output_hash":canonical_hash(doc),
                      "accepted":not reasons,"initial_reasons":initial_reasons,"reasons":deepcopy(reasons),"repairs":repairs})
        if not reasons:
            return {"status":"ACCEPTED_OFFLINE_IR","seed":seed,"document":doc,"audit":audit}
    return {"status":"BUDGET_EXHAUSTED","seed":None,"document":None,"audit":audit}
