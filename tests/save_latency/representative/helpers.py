"""Load selected immutable existing helpers without their historical CLI/imports."""
import ast
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import struct
import subprocess
from urllib.parse import urlencode


def functions(data, names, **bindings):
    tree = ast.parse(data.decode('utf-8-sig'))
    nodes = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in names]
    if {node.name for node in nodes} != set(names) or len(nodes) != len(names):
        raise ValueError('Unsupported frozen helper functions')
    module = ast.Module(body=nodes, type_ignores=[])
    namespace = dict(contextmanager=contextmanager, hashlib=hashlib, json=json,
                     Path=Path, struct=struct, subprocess=subprocess, urlencode=urlencode, **bindings)
    exec(compile(module, 'immutable-full-map-helpers', 'exec'), namespace)
    return {name: namespace[name] for name in names}


class DeadlineConnection:
    def __init__(self, connection, deadline, clock):
        self.connection, self.deadline, self.clock = connection, deadline, clock

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.connection.close()

    def operation(self, name, *args):
        remaining = self.deadline - self.clock()
        if remaining <= 0:
            raise TimeoutError('Whole-query deadline expired')
        self.connection.settimeout(remaining)
        return getattr(self.connection, name)(*args)

    def recv(self, count):
        return self.operation('recv', count)

    def sendall(self, data):
        return self.operation('sendall', data)


def query(data, connect, clock, port, token, action, session, timeout):
    if timeout <= 0:
        raise TimeoutError('Query budget exhausted')
    deadline = clock() + timeout

    class SocketBoundary:
        @staticmethod
        def create_connection(address, timeout):
            remaining = deadline - clock()
            if address != ('127.0.0.1', port) or remaining <= 0:
                raise ValueError('Only the allocated loopback endpoint is admitted')
            return DeadlineConnection(connect(address, min(timeout, remaining)), deadline, clock)

    selected = functions(data, ('read_exact', 'request'), socket=SocketBoundary)
    return selected['request'](port, token, action, session)
