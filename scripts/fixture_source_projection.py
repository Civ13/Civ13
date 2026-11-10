"""Shared source projection for the small faction and research fixtures.

Callers retain their own file reading, controls and execution policies.
"""
import re


def apply_control(text, path, control, controls):
    if control:
        target, old, new = controls[control]
        if target == path:
            if text.count(old) != 1:
                raise RuntimeError(f'Control target missing or ambiguous: {control}')
            text = text.replace(old, new, 1)
    return text


def proc_text(source, signature):
    start = source.index(signature)
    body = source.index('\n', start) + 1
    end = re.compile(r'^\S', re.M).search(source, body)
    return source[start:end.start() if end else len(source)]
