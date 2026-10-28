"""Small fail-closed source projection. Not DM, native callbacks or a savefile."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'code/modules/1713/primitive_woodworking.dm'


def block(text, signature):
    start = text.index(signature)
    end = re.search(r'\n/[^/*]', text[start+len(signature):])
    return text[start:start+len(signature)+end.start()] if end else text[start:]


def expr(value, fields=()):
    parts = re.split(r'("[^"\n]*")', value)
    for i in range(0,len(parts),2):
        part = parts[i]
        part = re.sub(r'(?<![\w])/(?:\w+/)*\w+',lambda m:repr(m[0]),part)
        part = part.replace('&&',' and ').replace('||',' or ')
        part = re.sub(r'!(?!=)','not ',part)
        for word in fields:
            part = re.sub(r'(?<![\w.])'+word+r'\b','self.'+word,part)
        part = re.sub(r'\bsrc\b','self',part)
        part = re.sub(r'(?<![\w.])(valid|commit|release)\(',r'self.\1(',part)
        part = part.replace('source:onfire','source.onfire').replace('source:splitting_in_progress','source.splitting_in_progress')
        parts[i]=part
    value=''.join(parts).replace('TRUE','True').replace('FALSE','False').replace('null','None')
    if ' ? ' in value:
        cond,other=value.split(' ? ',1)
        yes,no=other.split(' : ',1)
        value=f'({yes} if {cond} else {no})'
    return value


def compile_body(text, signature, args, env, fields=()):
    lines=['def projected('+args+'):']
    for raw in block(text,signature).splitlines()[1:]:
        line=raw.split('//',1)[0].rstrip()
        if not line.strip():
            continue
        depth=len(line)-len(line.lstrip('\t'))
        if not depth:
            raise AssertionError('Unexpected non-body source: '+line)
        line=line.strip()
        if line == '..()':
            line='parent_new()'
        if line.startswith('var/'):
            left,right=line.split(' = ',1)
            line=left.rsplit('/',1)[-1]+' = '+right
        if line.startswith('if ('):
            if not line.endswith(')'):
                raise AssertionError(line)
            line='if '+expr(line[4:-1],fields)+':'
        elif line=='else':
            line='else:'
        elif line.startswith('else if ('):
            line='elif '+expr(line[9:-1],fields)+':'
        elif line.startswith('return '):
            line='return '+expr(line[7:],fields)
        elif line.startswith('new '):
            match=re.fullmatch(r'new ([\w/]+)\((.*)\)',line)
            if not match:
                raise AssertionError(line)
            kind=match[1]
            line='construct('+expr(kind,fields)+', '+expr(match[2],fields)+')'
        else:
            # Assignment / function or method call only. Unknown DM syntax fails compilation.
            if ' = ' in line:
                left,right=line.split(' = ',1)
                line=expr(left,fields)+' = '+expr(right,fields)
            else:
                line=expr(line,fields)
        lines.append('    '*depth+line)
    compiled='\n'.join(lines)+'\n'
    namespace=dict(env)
    exec(compile(compiled,'<projected '+signature+'>','exec'),namespace)
    return namespace['projected'],namespace
