"""Static scan of build costs against the materials a built object gives back.

Costs come from every RECIPE row in config/crafting/material_recipes_*.txt plus
the extra stack inputs in config/craft_needs.json. Refunds come from DM procs
on the built type or its ancestors that create /obj/item/stack/material stacks,
including hammer_action() component lists and the generic /obj/structure
hammer dismantle. Exclusive if/else branches count as their largest branch,
and `for (var/i=1, i<=N, ...)` loops multiply what they drop.
"""
from pathlib import Path
import functools
import json
import re

ROOT = Path(__file__).resolve().parents[2]
STACK = '/obj/item/stack/material/'

# A log saws into four planks (sawmill produce and cut_primitive_logs), so
# the two wood stacks compare in plank units. Every other stack only
# compares with itself.
WOOD_VALUE = {'wood': 4, 'woodplank': 1}


def uncomment(text):
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m[0].count('\n'), text, flags=re.S)
    out = []
    for line in text.splitlines():
        quote = False
        for i, ch in enumerate(line):
            if ch == '"':
                quote = not quote
            elif not quote and line.startswith('//', i):
                line = line[:i]
                break
        out.append(line.rstrip())
    return out


@functools.lru_cache(maxsize=None)
def dm_files():
    return tuple(_dm_files())


def _dm_files():
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        yield str(path.relative_to(ROOT)), tuple(uncomment(path.read_text(encoding='utf-8', errors='replace')))


def material_stacks():
    """{'/material/wood/soft': 'woodplank', ...} from the material datums,
    with subtypes inheriting their parent's stack_type as DM does."""
    explicit, paths = {}, set()
    # Most materials live in materials.dm; a feature may declare its own
    # (particle_board.dm), so every source file is read.
    lines = []
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        lines.extend(uncomment(path.read_text(encoding='utf-8', errors='replace')))
        lines.append('')
    current = None
    for line in lines:
        if line.startswith('/material'):
            current = line.strip()
            paths.add(current)
        elif line and not line[0].isspace():
            current = None
        elif current and line.strip().startswith('stack_type = ' + STACK):
            explicit[current] = line.split(STACK, 1)[1].strip()
    out = {}
    for path in paths:
        for a in ancestors(path):
            if a in explicit:
                out[path] = explicit[a]
                break
    return out


def stack_of(path):
    path = path.strip().strip('"')
    return path[len(STACK):] if path.startswith(STACK) else None


def craft_inputs():
    data = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
    out = {}
    for result, need in data.items():
        for item, count in (need.get('inputs') or {}).items():
            stack = stack_of(item)
            if stack:
                out.setdefault(result, {})[stack] = count
    return out


def recipe_costs():
    """{result type: [(recipe file, title, {stack: amount per built item})]}"""
    stacks = material_stacks()
    extra = craft_inputs()
    costs = {}
    for path in sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt')):
        stem = path.stem.replace('material_recipes_', '')
        for row in path.read_text(encoding='utf-8', errors='replace').splitlines():
            if 'RECIPE: ' not in row or '//' in row:
                continue
            cols = row.split('RECIPE: ', 1)[1].strip().split(',')
            if len(cols) < 7:
                continue
            material = cols[0].strip().rstrip('/')
            result = cols[2].strip()
            try:
                made = max(1.0, float(cols[5]))
                cost = {stacks.get(material, material): float(cols[3]) / made}
            except ValueError:
                continue
            for stack, count in extra.get(result, {}).items():
                cost[stack] = cost.get(stack, 0) + count / made
            costs.setdefault(result, []).append((stem, cols[1].strip(), cost))
    return costs


def crafted_refund_rule(costs):
    """Python mirror of crafted_refund_stack() in code/game/objects/dismantle_refund.dm."""
    def rule(path, fallback):
        rows = costs.get(path)
        if not rows:
            return fallback
        families, cheapest, cheapest_stack, planks = set(), None, None, False
        for _, _, cost in rows:
            stack, amount = next(iter(cost.items()))  # the recipe's own material comes first
            if stack.startswith('/'):
                return None  # a material with no stack: the DM proc treats it as mixed
            value = amount * WOOD_VALUE[stack] if stack in WOOD_VALUE else amount
            families.add('wood' if stack in WOOD_VALUE else stack)
            planks |= stack == 'woodplank'
            if cheapest is None or value < cheapest:
                cheapest, cheapest_stack = value, stack
        if len(families) > 1:
            return None
        if families == {'wood'}:
            if not planks and cheapest >= 4:
                return STACK + 'wood'
            return STACK + 'woodplank' if cheapest >= 1 else None
        return STACK + cheapest_stack if cheapest >= 1 else None
    return rule


NEW_CALL = re.compile(r'\bnew\s*\(?\s*(/obj/item/stack/material/[\w/]+|[A-Za-z_]\w*)\s*\)?\s*\(')
LOOP = re.compile(r'^for\s*\(\s*var/\w+\s*=\s*(?:1|TRUE)\s*,\s*\w+\s*<=\s*(\w+)\s*,')
HAMMER = re.compile(r'hammer_action\(\s*\w+\s*,\s*\w+\s*,\s*\d+\s*,\s*list\(([^)]*)\)\s*,\s*list\(([^)]*)\)\s*\)')
UNKNOWN = object()


def call_args(code, start):
    """Top-level comma-separated arguments of the call whose '(' ends at code[start-1]."""
    depth, parts, cur = 0, [], ''
    for ch in code[start:]:
        if ch == ')' and depth == 0:
            break
        if ch == ',' and depth == 0:
            parts.append(cur.strip())
            cur = ''
            continue
        depth += ch in '(['
        depth -= ch in ')]'
        cur += ch
    parts.append(cur.strip())
    return parts


class Context:
    """A built type: resolves its vars for conditions, loops and `new var(...)`."""

    def __init__(self, path, type_vars, refund_rule=None):
        self.path = path
        self.refund_rule = refund_rule or (lambda path, fallback: fallback)
        self.locals = {}
        self.vars = {}
        for a in reversed(ancestors(path)):
            self.vars.update(type_vars.get(a, {}))

    def value(self, token):
        token = token.strip()
        if token in ('TRUE', '1'):
            return 1
        if token in ('FALSE', '0', 'null'):
            return 0
        if re.fullmatch(r'\d+', token):
            return int(token)
        if re.fullmatch(r'"[^"]*"', token) or token.startswith('/'):
            return token.strip('"')
        if re.fullmatch(r'\w+', token) and token in self.locals:
            return self.locals[token]
        if re.fullmatch(r'(src\.)?\w+', token):
            name = token.split('.')[-1]
            if name in self.vars:
                return self.value(self.vars[name])
        return UNKNOWN

    def condition(self, code):
        """True/False when the condition only reads src's type and vars, else None."""
        m = re.match(r'(?:else\s+)?if\s*\((.*)\)\s*$', code)
        if not m:
            return None
        cond = m[1].strip()
        parts = [p.strip() for p in re.split(r'\|\|', cond)]
        results = []
        for part in parts:
            while part.startswith('(') and part.endswith(')'):
                part = part[1:-1].strip()
            negate = part.startswith('!') and not part.startswith('!=')
            if negate:
                part = part[1:].strip()
            r = None
            t = re.fullmatch(r'istype\(\s*src\s*,\s*(/[\w/]+)\s*\)', part)
            if t:
                r = self.path == t[1] or self.path.startswith(t[1] + '/')
            else:
                e = re.fullmatch(r'(\S+)\s*(==|!=)\s*(\S+)', part)
                if e:
                    a, b = self.value(e[1]), self.value(e[3])
                    if a is not UNKNOWN and b is not UNKNOWN:
                        r = (a == b) if e[2] == '==' else (a != b)
                elif re.fullmatch(r'(src\.)?\w+', part):
                    v = self.value(part)
                    if v is not UNKNOWN:
                        r = bool(v)
            if r is None:
                return None
            results.append((not r) if negate else r)
        return any(results)


REFUND_CALL = re.compile(r'^var/(?:[\w/]+/)?(\w+)\s*=\s*crafted_refund_stack\(\s*(?:src\.)?type\s*(?:,\s*([\w/]+))?\s*\)$')


def line_refund(code, ctx):
    """({stack: amount}, computed) for one statement."""
    drops, computed = {}, False
    m = REFUND_CALL.match(code)
    if m:  # code/game/objects/dismantle_refund.dm, mirrored by crafted_refund_stack()
        fallback = m[2] if m[2] and m[2] != 'null' else None
        ctx.locals[m[1]] = ctx.refund_rule(ctx.path, fallback) or 0
        return drops, computed
    for m in NEW_CALL.finditer(code):
        target = m[1]
        if not target.startswith('/'):
            target = ctx.value(target)
            if target is UNKNOWN or not isinstance(target, str):
                continue
        stack = stack_of(target)
        if not stack:
            continue
        args = call_args(code, m.end())
        amount = ctx.value(args[1]) if len(args) > 1 and args[1] else 1
        if not isinstance(amount, int):
            computed = True
            continue
        drops[stack] = drops.get(stack, 0) + amount
    m = HAMMER.search(code)
    if m:
        comps = [stack_of(c) for c in m[1].split(',') if c.strip()]
        qtys = [ctx.value(q) for q in m[2].split(',') if q.strip()]
        for stack, qty in zip(comps, qtys):
            if not stack:
                continue
            if isinstance(qty, int):
                drops[stack] = drops.get(stack, 0) + qty
            else:
                computed = True
    return drops, computed


def merge_max(a, b):
    """Largest of two exclusive outcomes, compared per stack."""
    out = dict(a)
    for k, v in b.items():
        out[k] = max(out.get(k, 0), v)
    return out


def merge_sum(a, b):
    out = dict(a)
    for k, v in b.items():
        out[k] = out.get(k, 0) + v
    return out


COMPUTED = '?'  # pseudo stack for drops whose amount is computed at runtime


def deletes_src(code):
    return 'qdel(src)' in code.replace(' ', '') or bool(HAMMER.search(code))


class Stmt:
    def __init__(self, code):
        self.code = code
        self.children = []


def parse(body, i=0, indent=None):
    """Indentation tree of statements; returns (statements, next index)."""
    if indent is None:
        indent = body[0][0] if body else 0
    out = []
    while i < len(body):
        ind, code = body[i]
        if ind < indent:
            break
        if ind > indent:  # wrapped expression line
            i += 1
            continue
        stmt = Stmt(code)
        i += 1
        if i < len(body) and body[i][0] > indent:
            stmt.children, i = parse(body, i, body[i][0])
        out.append(stmt)
    return out, i


# An outcome is (kept, pending, deletes, terminates): drops followed by a
# deletion of src, drops not yet followed by one, whether src is deleted on
# this path, and whether the path returns.
EMPTY = ({}, {}, False, False)


def then(a, b):
    """Outcome a followed by outcome b."""
    if a[3]:
        return a
    kept = merge_sum(merge_sum(a[0], b[0]), a[1] if b[2] else {})
    pending = merge_sum(b[1], {} if b[2] else a[1])
    return kept, pending, a[2] or b[2], b[3]


def either(outcomes):
    """Largest of exclusive outcomes."""
    kept, pending = {}, {}
    for o in outcomes:
        kept = merge_max(kept, o[0])
        pending = merge_max(pending, o[1])
    return kept, pending, all(o[2] for o in outcomes), all(o[3] for o in outcomes)


def scaled(o, times):
    def scale(part):
        out = {}
        for k, v in part.items():
            if isinstance(times, int):
                out[k] = v * times
            else:
                out[k] = v
                out[COMPUTED] = 1
        return out
    return scale(o[0]), scale(o[1]), o[2], o[3]


def run(stmts, ctx):
    """Outcome of a statement list. Exclusive if/else branches and switch
    cases count as their largest reachable alternative; a branch that
    returns does not continue into the code after it; branches decided by
    src's type or vars are taken or skipped exactly."""
    groups, k = [], 0
    while k < len(stmts):
        if re.match(r'if\s*\(', stmts[k].code):
            chain = [stmts[k]]
            k += 1
            while k < len(stmts) and re.match(r'else\b', stmts[k].code):
                chain.append(stmts[k])
                k += 1
            groups.append(('if', chain))
        else:
            groups.append(('stmt', stmts[k]))
            k += 1
    rest = EMPTY
    for kind, item in reversed(groups):
        if kind == 'if':
            outcomes, decided = [], False
            for branch in item:
                if branch.code.startswith('else') and not branch.code.startswith('else if'):
                    cond = True
                else:
                    cond = ctx.condition(branch.code)
                if decided or cond is False:
                    continue
                outcomes.append(then(line(branch.code, ctx), run(branch.children, ctx)))
                if cond is True:
                    decided = True
            if not decided:
                outcomes.append(EMPTY)  # no branch taken
            rest = either([o if o[3] else then(o, rest) for o in outcomes])
        else:
            rest = then(statement(item, ctx), rest)
    return rest


def line(code, ctx):
    drops, computed = line_refund(code, ctx)
    if computed:
        drops[COMPUTED] = drops.get(COMPUTED, 0) + 1
    if deletes_src(code):
        return drops, {}, True, False
    return {}, drops, False, bool(re.match(r'return\b', code))


def statement(stmt, ctx):
    code = stmt.code
    if re.match(r'switch\s*\(', code):
        return either([then(line(c.code, ctx), run(c.children, ctx)) for c in stmt.children] + [EMPTY])
    child = run(stmt.children, ctx)
    loop = LOOP.match(code)
    if loop:
        child = scaled(child, ctx.value(loop[1]))
    return then(line(code, ctx), child)


def proc_refund(body, ctx):
    """({stack: amount}, computed) dropped on paths that delete src."""
    stmts, _ = parse(body)
    kept = dict(run(stmts, ctx)[0])
    computed = kept.pop(COMPUTED, 0) > 0
    return kept, computed


def type_info():
    """{type: {var: raw value}} from type blocks (assignments and var/ declarations)."""
    type_vars = {}
    for _, lines in dm_files():
        current = None
        for line in lines:
            if line and not line[0].isspace():
                current = None
                m = re.fullmatch(r'(/obj[\w/]*)', line.strip())
                if m:
                    current = m[1]
                continue
            if current and line.startswith('\t') and not line.startswith('\t\t'):
                m = re.fullmatch(r'\t(?:var/(?:[\w/]+/)?)?(\w+)\s*=\s*(.+?)\s*', line)
                if m:
                    type_vars.setdefault(current, {})[m[1]] = m[2]
    return type_vars


def procs():
    """{(owner, proc name): [(file, body, mentions hammer, calls parent)]} for column-0 procs.

    DM lets several files define the same proc on one type, so each
    definition is kept."""
    found = {}
    for file, lines in dm_files():
        current = None

        def finish():
            if current:
                owner, name, body = current
                hammer = any('TOOL_HAMMER' in c or '/obj/item/weapon/hammer' in c for _, c in body)
                parent = any('..(' in c for _, c in body)
                found.setdefault((owner, name), []).append((file, body, hammer, parent))
        for line in lines:
            if line and not line[0].isspace():
                finish()
                current = None
                m = re.match(r'(/obj[\w/]*?)/(?:proc/|verb/)?(\w+)\(', line)
                if m:
                    current = (m[1], m[2], [])
                continue
            if current is not None and line.strip():
                current[2].append((len(line) - len(line.lstrip('\t')), line.strip()))
        finish()
    return found


def ancestors(path):
    parts = path.split('/')
    return ['/'.join(parts[:n]) for n in range(len(parts), 1, -1)]


def refunds_for(path, table, type_vars, by_name=None, refund_rule=None):
    """[(file, proc owner, proc, drops, computed)] that can drop stacks from a built `path`."""
    if by_name is None:
        by_name = {}
        for owner, name in table:
            by_name.setdefault(name, set()).add(owner)
    ctx = Context(path, type_vars, refund_rule)
    chain = ancestors(path)
    out = []
    for name, owners in by_name.items():
        for a in chain:  # the nearest definition handles src
            if a not in owners:
                continue
            if a == '/obj/structure' and name == 'attackby' and generic_unreachable(path, chain, table, ctx):
                break
            for file, body, _, _ in table[(a, name)]:
                drops, computed = proc_refund(body, ctx)
                if drops or computed:
                    out.append((file, a, name, drops, computed))
            break
    return out


def generic_unreachable(path, chain, table, ctx):
    """The generic /obj/structure hammer dismantle is not reached from `path`."""
    disassemblable = ctx.value('not_disassemblable')
    if disassemblable is UNKNOWN or disassemblable:
        return True
    for o in chain:
        if o == '/obj/structure':
            return False
        for _, _, hammer, parent in table.get((o, 'attackby'), ()):
            if hammer or not parent:
                return True
    return False


def compare(cost, drops):
    """Problems where `drops` is worth more than `cost`."""
    problems = []
    wood_cost = sum(cost.get(s, 0) * v for s, v in WOOD_VALUE.items())
    wood_back = sum(drops.get(s, 0) * v for s, v in WOOD_VALUE.items())
    if wood_back > wood_cost + 1e-9:
        problems.append(f'wood worth {wood_back:g} planks back for {wood_cost:g} spent')
    for stack, amount in drops.items():
        if stack in WOOD_VALUE:
            continue
        if amount > cost.get(stack, 0) + 1e-9:
            problems.append(f'{amount:g} {stack} back for {cost.get(stack, 0):g} spent')
    return problems


def scan():
    costs = recipe_costs()
    table = procs()
    type_vars = type_info()
    by_name = {}
    for owner, name in table:
        by_name.setdefault(name, set()).add(owner)
    rule = crafted_refund_rule(costs)
    report = []
    for path, rows in sorted(costs.items()):
        for file, owner, name, drops, computed in refunds_for(path, table, type_vars, by_name, rule):
            for stem, title, cost in rows:
                for problem in compare(cost, drops):
                    report.append((path, owner, name, file, stem, title, problem))
    return report
