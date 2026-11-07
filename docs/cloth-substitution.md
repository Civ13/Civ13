# Woolcloth as a cloth ingredient

Finished woolcloth sheets can replace ordinary cloth sheets one for one in
cloth recipes and material requirements. This is a one-way recipe substitution,
not a type alias or conversion. Ordinary cloth does not unlock wool-specific
recipes. Raw wool, cotton, retted fabric, rags, leather and other materials are
not substitutes.

## Covered paths

- Every selected faction/map material catalog offers its cloth recipes when
  crafting from woolcloth. Identical existing wool rows are not duplicated;
  distinct wool products, costs and gates remain. Research, skill and era gates,
  primary quantities and existing primary crafting discounts remain in effect.
- Railway works offices accept both textiles toward the same 40-cloth project
  requirement. Separate deliveries may be mixed; excess stays in the input stack.
- Armor carriers accept a complete ordinary-cloth or woolcloth stack in their
  cloth slot. Leather remains a separate paid input. The staged bench retains
  its existing single-complete-stack-per-input rule.
- Automobile and rover workshops accept mixed textile deposits. The wool share
  is retained under `stock["woolcloth"]` within the existing saved stock list,
  so unloading returns each original material. Construction spends ordinary
  cloth first. Old saves without that key contain only ordinary cloth.
- Private Extraction workshops accept the exact woolcloth type in both the
  physical selection and durable payment planner. The equipment codec preserves
  its type and quantity; exact-total payment and quarantine rules are unchanged.
- Paintings accept mixed held cloth stacks for their secondary requirement,
  paying three sheets per requested batch. Doge clothing, fiendish headdresses,
  turban helmets and plague-doctor masks retain their original secondary
  gold/bone/iron/herb costs, scaled per batch. Both inputs are retained and
  revalidated after waiting, before either is consumed. Cancellation, moved or
  depleted inputs, new output occupancy, research loss and save admission abort
  the textile action without payment. The plague clothing medical gate remains.
- Flag construction, priest-helmet cloth domes, money-printer feedstock and sail
  patching accept woolcloth at their original quantities. Priest helmets require
  all three sheets; existing gold/silver helmet transformations remain separate.
  Sail repair retains the selected material through its wait and pays before
  increasing sail health.

Ordinary stack crafting still consumes one primary stack. Use an adequate cloth
or woolcloth stack; this does not introduce cross-material stack merging or
multi-stack primary crafting. Splitting and moving wool keep its wool identity.

Clothing repair already handles both textiles with different repair strengths;
that behavior remains unchanged. Upholstery keeps actual material properties.
Trade posts, barter/economy classifications, loot, acquisition and non-consuming
smoke signals are not recipe substitutions and are unchanged.

## Verification

`python3 scripts/check-recipes.py --cloth-only` compiles the real game types and
runs bounded recipe, debit, split, project, armor, workshop refund, equipment
codec, medical-gate and helmet checks. It uses isolated startup and temporary
storage, inert character startup/skills/HUD and a simple stack output for batch
payment tests. Office/workshop persistence checks exercise custom entry export
and import through native disk savefiles. The ordinary recipe runner also calls
the cloth fixture. Both modes reload every faction catalog explicitly.

`python3 -m unittest discover -s tests/cloth_substitution -v` runs offline source
projections, the wrong-material mutation and guarded integration checks. Existing
crafting UI, grinder, joinery and atlas fixtures are updated for the explicit
textile gate while preserving their previous assertions. The catalog row check
now supplies the tablet press's required calendar year as well as its research
requirements.

These checks do not establish connected-client UI acceptance, full-world restart,
real railway travel, car construction/power, or every output constructor. No live
server, player save or deployment is used.
