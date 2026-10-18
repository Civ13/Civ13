"""Independent structural oracle for native Help HTML; never executes HTML."""
from html.parser import HTMLParser


class HelpHTML(HTMLParser):
    allowed = {'html', 'body', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
               'p', 'br', 'pre', 'code', 'b', 'i', 'a'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []

    def handle_starttag(self, tag, attrs):
        if tag not in self.allowed:
            raise ValueError(f'Unexpected tag: {tag}')
        if tag == 'a':
            if len(attrs) != 1 or attrs[0][0] != 'href':
                raise ValueError('Unexpected link attributes')
            url = attrs[0][1]
            if not url.lower().startswith(('http://', 'https://')):
                raise ValueError('Unsafe link scheme')
            if any(ord(c) <= 32 or ord(c) == 127 or c in '\"\'<>\\' for c in url):
                raise ValueError('Unsafe link character')
        elif attrs:
            raise ValueError(f'Unexpected attributes on {tag}')
        if tag != 'br':
            self.stack.append(tag)

    def handle_endtag(self, tag):
        if not self.stack or self.stack.pop() != tag:
            raise ValueError(f'Unbalanced tag: {tag}')

    def handle_comment(self, data):
        raise ValueError('Unexpected comment')

    def handle_decl(self, decl):
        raise ValueError('Unexpected declaration')


def validate(case, rendered):
    for expected in case['contains']:
        if expected not in rendered:
            raise ValueError(f"{case['name']}: missing {expected!r}")
    for forbidden in case['absent']:
        if forbidden in rendered:
            raise ValueError(f"{case['name']}: forbidden {forbidden!r}")
    parser = HelpHTML()
    parser.feed(rendered)
    parser.close()
    if parser.stack:
        raise ValueError(f'Unclosed tags: {parser.stack}')
