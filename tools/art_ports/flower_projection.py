"""Small fail-closed interpreter for the reviewed flower/radiation DM subset.

This executes selected production source bodies against injected scalar fields.
Parent construction/loading, native resource equality, saves and rendering are
adapters, not BYOND evidence. Unknown syntax stops the projection.
"""
import ast
import copy
import json
import re


FLOWERS = '/obj/structure/wild/flowers'


def block(source, header):
    match = re.search('^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError('Missing source block: ' + header)
    return match[1]


def defaults(source, typename):
    result = {'radiation': 0}
    for owner in ('/obj/structure/wild', FLOWERS, typename):
        for line in block(source, owner).splitlines():
            match = re.fullmatch(r'\t(?:var/)?(\w+) = (.*?)(?:\s*//.*)?', line)
            if not match:
                continue
            value = match[2]
            if value in ('TRUE', 'FALSE'):
                value = value == 'TRUE'
            elif value.startswith(('"', "'")):
                value = ast.literal_eval(value)
            elif re.fullmatch(r'-?\d+(?:\.\d+)?', value):
                value = float(value) if '.' in value else int(value)
            else:
                continue
            result[match[1]] = value
    return result


class Projection:
    def __init__(self, wild, radiation, typename, roll=3):
        self.initial = defaults(wild, typename)
        self.fields = copy.deepcopy(self.initial)
        self.roll = roll
        self.draws = []
        self.parent_calls = []
        self.methods = {
            (FLOWERS, 'New'): block(wild, FLOWERS).split('\tNew()\n', 1)[1],
            (FLOWERS, 'restore_fixed_flower_appearance'): block(wild, FLOWERS + '/proc/restore_fixed_flower_appearance()'),
            (FLOWERS, 'rad_act'): block(wild, FLOWERS + '/rad_act(amount)'),
            (FLOWERS, 'after_load'): block(wild, FLOWERS + '/after_load()'),
            ('/obj/structure/wild', 'rad_act'): block(radiation, '/obj/structure/wild/rad_act(amount)'),
        }

    def value(self, expression, local):
        expression = expression.strip()
        if expression.startswith('"') and expression.endswith('"') and '[' in expression:
            return re.sub(r'\[([^\[\]]+)\]', lambda m: str(self.value(m[1], local)),
                          json.loads(expression))
        expression = expression.replace('&&', ' and ').replace('||', ' or ')
        expression = re.sub(r'!(?!=)', ' not ', expression).strip()

        def evaluate(node):
            if isinstance(node, ast.Constant):
                return node.value
            if isinstance(node, ast.Name):
                if node.id in local:
                    return local[node.id]
                return self.fields[node.id]
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                name = node.func.id
                if name == 'initial' and len(node.args) == 1 and isinstance(node.args[0], ast.Name):
                    return self.initial[node.args[0].id]
                args = [evaluate(arg) for arg in node.args]
                if name == 'findtext' and len(args) == 2:
                    return args[0].find(args[1]) + 1
                if name == 'rand' and len(args) == 2:
                    self.draws.append(tuple(args))
                    if not args[0] <= self.roll <= args[1]:
                        raise ValueError('Injected roll outside source bounds')
                    return self.roll
            if isinstance(node, ast.UnaryOp):
                if isinstance(node.op, ast.Not):
                    return not evaluate(node.operand)
                if isinstance(node.op, ast.USub):
                    return -evaluate(node.operand)
            if isinstance(node, ast.BoolOp):
                if isinstance(node.op, ast.And):
                    return all(evaluate(v) for v in node.values)
                if isinstance(node.op, ast.Or):
                    return any(evaluate(v) for v in node.values)
            if isinstance(node, ast.BinOp):
                left, right = evaluate(node.left), evaluate(node.right)
                if isinstance(node.op, ast.Add):
                    return left + right
                if isinstance(node.op, ast.Div):
                    return left / right
            if isinstance(node, ast.Compare) and len(node.ops) == 1:
                left, right = evaluate(node.left), evaluate(node.comparators[0])
                operations = {ast.Eq: lambda: left == right, ast.NotEq: lambda: left != right,
                              ast.LtE: lambda: left <= right, ast.GtE: lambda: left >= right,
                              ast.Gt: lambda: left > right}
                if type(node.ops[0]) in operations:
                    return operations[type(node.ops[0])]()
            raise ValueError('Unsupported DM expression: ' + expression)

        return evaluate(ast.parse(expression, mode='eval').body)

    def invoke(self, method, amount=None, parent_only=False):
        owner = '/obj/structure/wild' if parent_only else FLOWERS
        self.execute(self.methods[(owner, method)], owner, method, {'amount': amount})

    def execute(self, body, owner, method, local):
        lines = []
        for line in body.splitlines():
            text = line.strip()
            if text and not text.startswith('//'):
                lines.append((len(line) - len(line.lstrip('\t')), text))
        if not lines:
            return

        def run(start, stop, indent):
            i = start
            while i < stop:
                depth, text = lines[i]
                if depth != indent:
                    raise ValueError('Unsupported DM indentation')
                if text.startswith('if (') or text.startswith('if('):
                    condition = text[text.index('(') + 1:-1]
                    end = i + 1
                    while end < stop and lines[end][0] > indent:
                        end += 1
                    has_else = end < stop and lines[end] == (indent, 'else')
                    alternate_end = end + 1
                    if has_else:
                        while alternate_end < stop and lines[alternate_end][0] > indent:
                            alternate_end += 1
                    chosen = self.value(condition, local)
                    if chosen and run(i + 1, end, indent + 1):
                        return True
                    if not chosen and has_else and run(end + 1, alternate_end, indent + 1):
                        return True
                    i = alternate_end if has_else else end
                    continue
                if text == 'return':
                    return True
                if text in ('..()', '. = ..()'):
                    self.parent_calls.append((owner, method))
                    if owner == FLOWERS and method == 'rad_act':
                        self.invoke(method, local['amount'], parent_only=True)
                elif text == 'restore_fixed_flower_appearance()':
                    self.execute(self.methods[(FLOWERS, 'restore_fixed_flower_appearance')],
                                 FLOWERS, 'restore_fixed_flower_appearance', local)
                elif text == 'update_icon()':
                    # Production /obj/proc/update_icon is a no-op; native icon effects
                    # and all parent New()/after_load() behavior remain unexecuted.
                    pass
                else:
                    match = re.fullmatch(r'(\w+) (\+=|=) (.*)', text)
                    if not match:
                        raise ValueError('Unsupported DM statement: ' + text)
                    value = self.value(match[3], local)
                    self.fields[match[1]] = self.fields[match[1]] + value if match[2] == '+=' else value
                i += 1
            return False

        run(0, len(lines), min(d for d, _ in lines))
