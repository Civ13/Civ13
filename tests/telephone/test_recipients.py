"""Offline legacy telephone characterization with inert view/output/timer boundaries."""
from collections import Counter
import heapq
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/modules/1713/telephone.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'telephone_before.txt'
BASE = '/obj/item/weapon/telephone'
FIELDS = ('ringing', 'ringingnum', 'origincall', 'connected', 'phonenumber',
          'wireless', 'loc', 'contacts', 'ring', 'visible_message')


class DMList:
    """Only list/associative operations used by these production bodies."""
    def __init__(self, *values):
        self.values = list(values)
        self.assoc = {}

    @property
    def len(self):
        return len(self.values)

    def __bool__(self):
        return True  # A non-null DM list remains truthy when empty.

    def __iter__(self):
        return iter(self.values)

    def Find(self, value):
        return self.values.index(value) + 1 if value in self.values else 0

    def __iadd__(self, value):
        self.values.append(value)
        return self

    def __getitem__(self, key):
        return self.values[key - 1] if isinstance(key, int) else self.assoc.get(key)

    def __setitem__(self, key, value):
        if key not in self.assoc:
            self.values.append(key)
        self.assoc[key] = value


class Human:
    type = '/mob/living/human'

    def __init__(self, network, name, number):
        self.network, self.name, self.uid = network, name, name + '#' + str(number)
        self.stat, self.default_language, self.on_hear = 0, 'Common', None

    def __str__(self):
        return self.name

    def hear_phone(self, msg, verbage, language, speaker, origin, destination):
        self.network.trace.append(('heard', self.network.now, self.uid, msg, verbage,
                                   language, speaker.uid, origin.name, destination.name))
        if self.on_hear:
            self.on_hear(destination)


class Phone:
    type = BASE

    def __init__(self, network, name, number, owner):
        self.network, self.name, self.phonenumber, self.loc = network, name, number, owner
        self.ringing = self.ringingnum = self.connected = False
        self.origincall, self.wireless, self.contacts = None, True, DMList()

    def __str__(self):
        return self.name

    def visible_message(self, message):
        self.network.trace.append(('visible', self.network.now, self.name, message))


class Network:
    def __init__(self, text, deletion_policy='retained-mock-reference'):
        self.text, self.now, self.sequence, self.literal = text, 0, 0, 0
        self.queue, self.trace, self.humans, self.phones, self.views = [], [], [], [], {}
        self.next_number, self.list_allocations = 0, 0
        self.deletion_policy, self.withdrawn = deletion_policy, set()
        self.dial = self.bind('/proc/ring_phone', 'target,origin,originphone,user=None')

    def human(self, name):
        h = Human(self, name, len(self.humans))
        self.humans.append(h)
        return h

    def phone(self, name, number, owner):
        p = Phone(self, name, number, owner)
        self.phones.append(p)
        for name, declaration, args in (
            ('ring', BASE + '/proc/ring', 'origin=None'),
            ('ringproc', BASE + '/proc/ringproc', 'origin,ocall'),
            ('broadcast', BASE + '/proc/broadcast', 'msg,speaker,verbage="says"'),
            ('attack_self', BASE + '/attack_self', 'user')):
            f = self.bind(declaration, args, p)
            setattr(p, name, lambda *a, _f=f: _f(p, *a))
        ring = p.ring
        def traced_ring(origin=None):
            self.trace.append(('ring', self.now, p.name, origin))
            return ring(origin)
        p.ring = traced_ring
        return p

    def defer(self, delay, callback, owner):
        self.sequence += 1
        due = self.now + delay
        heapq.heappush(self.queue, (due, self.sequence, owner, callback))
        self.trace.append(('scheduled', self.now, owner, due))

    def advance(self, until):
        while self.queue and self.queue[0][0] <= until:
            self.now, _, owner, callback = heapq.heappop(self.queue)
            self.trace.append(('callback', self.now, owner))
            callback()
        self.now = until

    def view(self, radius, human):
        self.trace.append(('view', self.now, human.uid, radius))
        return list(self.views.get(human, []))

    def make_list(self, *values):
        self.list_allocations += 1
        return DMList(*values)

    def typed_iter(self, values, kind):
        matched = [v for v in values if v and
                   (isinstance(v, DMList) if kind == '/list' else getattr(v, 'type', '').startswith(kind))]
        if self.deletion_policy == 'omit-withdrawn-at-yield':
            return (v for v in matched if v not in self.withdrawn)
        return matched

    def withdraw(self, value):
        # Explicit adversarial reference policy, not a simulation of native
        # qdel, reference nulling, GC, or associative object-key deletion.
        self.withdrawn.add(value)
        self.trace.append(('withdraw', self.now, str(value)))

    def bind(self, declaration, args, phone=None):
        body = extract(self.text, declaration)
        locals_ = set(re.findall(r'\bvar/(?:\w+/)*(\w+)\b', body))
        locals_.update(arg.split('=')[0] for arg in args.split(','))
        env = dict(CONSCIOUS=0, human_mob_list=self.humans, world=self.phones,
                   list=self.make_list, view=self.view, range=lambda radius, loc: [],
                   typed_iter=self.typed_iter,
                   dd_hasprefix=lambda text, prefix: text.startswith(prefix),
                   ishuman=lambda value: isinstance(value, Human),
                   to_chat=lambda user, msg: self.trace.append(('chat', self.now, user.uid if user else None, msg)),
                   playsound=lambda loc, sample, volume, *rest: self.trace.append(
                       ('sound', self.now, str(loc), sample, volume, rest)),
                   getFlatIcon=lambda obj: '<icon:' + obj.name + '>',
                   sanitize_integer=lambda value, **kw: max(kw['min'], min(kw['max'], int(value))),
                   ring_phone=lambda *a: self.dial(*a))
        def read_number(user, prompt):
            self.trace.append(('input', self.now, user.uid, prompt))
            return self.next_number
        env['read_number'] = read_number
        env['defer'] = lambda delay, callback: self.defer(delay, callback, phone.name)
        def qualify(code):
            if phone:
                code = re.sub(r'(?<![\w./])src\b', 'self', code)
                for field in FIELDS:
                    code = re.sub(r'(?<![\w./])' + field + r'\b', 'self.' + field, code)
            return code
        # Prompts and native icon formatting are inert output boundaries. Keep
        # literal text outside the generic adapter's operator substitutions.
        body, inputs = re.subn(r'input\(([^\n]*)\) as num', r'read_number(\1)', body)
        self.assert_input_count(declaration, inputs)
        def literal(match):
            raw = match[0][1:-1].replace('\\icon', '')
            parts = re.split(r'\[([^\[\]]+)\]', raw)
            name = '_phone_text_' + str(self.literal)
            self.literal += 1
            if len(parts) == 1:
                env[name] = raw
                return name
            def render(*values, _parts=parts):
                result = _parts[0]
                for value, tail in zip(values, _parts[2::2]):
                    result += ('' if value is None else str(value)) + tail
                return result
            env[name] = render
            return name + '(' + ','.join(qualify(expr) for expr in parts[1::2]) + ')'
        body = re.sub(r'"(?:[^"\\]|\\.)*"', literal, body)
        body = qualify(body)
        counter = [0]
        def timers(lines):
            result, index = [], 0
            while index < len(lines):
                line = lines[index]
                match = re.fullmatch(r'(\t*)spawn\((\d+)\)', line)
                if not match:
                    result.append(line);index += 1;continue
                depth, delay = len(match[1]), match[2]
                end = index + 1
                while end < len(lines) and (not lines[end].strip() or
                        len(lines[end]) - len(lines[end].lstrip('\t')) > depth):
                    end += 1
                block = lines[index + 1:end]
                used = set(re.findall(r'\b\w+\b', '\n'.join(block))) & locals_
                captures = ','.join(name + '=' + name for name in sorted(used))
                callback = '_callback_' + str(counter[0]);counter[0] += 1
                result.append('\t' * depth + 'def ' + callback + '(' + captures + '):')
                result.extend(timers(block))
                result.append('\t' * depth + 'defer(' + delay + ',' + callback + ')')
                index = end
            return result
        body = '\n'.join(timers(body.splitlines()))
        return project(declaration + '(' + args + ')\n' + body + '\n', declaration,
                       ('self,' if phone else '') + args, env)

    @staticmethod
    def assert_input_count(declaration, count):
        if count != (1 if declaration == BASE + '/attack_self' else 0):
            raise AssertionError('Telephone input boundary drift')

    def state(self):
        return [(p.name, p.ringing, p.ringingnum, p.connected,
                 p.origincall.name if p.origincall else None) for p in self.phones]


class TelephoneCharacterization(unittest.TestCase):
    def setUp(self):
        self.before = BEFORE.read_text()
        self.after = SOURCE.read_text()

    def recipients(self, text, wake=False):
        n = Network(text);speaker=n.human('speaker');a=n.human('same name');b=n.human('same name');c=n.human('sleeping')
        source=n.phone('source',1001,speaker);linked=n.phone('linked',2002,a);other=n.phone('other',3003,b)
        linked.origincall=source
        n.views[a]=[source,linked,other];n.views[b]=[linked];n.views[c]=[source]
        c.stat=1
        n.humans[:]=[c,a,a,b,c,speaker]
        if wake:a.on_hear=lambda destination:setattr(c,'stat',0)
        source.broadcast('hello',speaker,'whispers')
        return n

    def test_recipient_multiset_and_order_match_preimage(self):
        for wake in [False,True]:
            old=self.recipients(self.before,wake);new=self.recipients(self.after,wake)
            self.assertEqual(new.trace,old.trace)
            heard=[event for event in new.trace if event[0]=='heard']
            self.assertEqual([e[-1] for e in heard],['source','linked','linked'])
            self.assertEqual(len(set(e[2] for e in heard)),2)  # Same name, distinct human identities.
            self.assertEqual(Counter(e[2] for e in heard).most_common()[0][1],2)
            self.assertEqual([e[2] for e in new.trace if e[0]=='view'],['same name#1','same name#2','speaker#0'])

    def test_emote_returns_before_seen_list_or_view_or_delivery(self):
        for text in [self.before,self.after]:
            n=Network(text);h=n.human('human');p=n.phone('phone',1001,h);n.views[h]=[p]
            n.list_allocations=0;p.broadcast('*waves',h)
            self.assertEqual(n.trace,[]);self.assertEqual(n.list_allocations,0)

    def test_null_and_unrelated_registry_entries_preserve_typed_recipient_filtering(self):
        results=[]
        for text in [self.before,self.after]:
            n=Network(text);h=n.human('listener');p=n.phone('source',1001,h)
            n.humans[:]=[None,object(),p,h,None,h]
            n.views[h]=[None,object(),h,p]
            p.broadcast('message',h)
            self.assertEqual([e[2] for e in n.trace if e[0]=='view'],[h.uid])
            self.assertEqual([e[-1] for e in n.trace if e[0]=='heard'],['source'])
            results.append(n.trace)
        self.assertEqual(*results)

    def test_deletion_during_delivery_parity_under_explicit_mock_reference_policies(self):
        for policy in ['retained-mock-reference','omit-withdrawn-at-yield']:
            results=[]
            for text in [self.before,self.after]:
                n=Network(text,deletion_policy=policy);a=n.human('first');b=n.human('second')
                p=n.phone('source',1001,a);q=n.phone('future candidate',2002,b);q.origincall=p
                n.humans[:]=[a,b,a];n.views[a]=[p,q];n.views[b]=[p,q]
                def invalidate(destination):
                    n.withdraw(a);n.withdraw(q)
                a.on_hear=invalidate
                p.broadcast('message',b)
                heard=[e for e in n.trace if e[0]=='heard']
                self.assertEqual(len(heard),4 if policy=='retained-mock-reference' else 2)
                results.append(n.trace)
            self.assertEqual(*results)

    def test_empty_unconscious_and_empty_view_inputs_do_not_deliver(self):
        for mode in ['empty','unconscious','empty-view']:
            results=[]
            for text in [self.before,self.after]:
                n=Network(text);h=n.human('listener');p=n.phone('source',1001,h)
                n.views[h]=[p]
                if mode=='empty':n.humans.clear()
                if mode=='unconscious':h.stat=1
                if mode=='empty-view':n.views[h]=[]
                p.broadcast('message',h)
                self.assertFalse(any(e[0]=='heard' for e in n.trace))
                results.append(n.trace)
            self.assertEqual(*results)

    def test_phone_match_is_evaluated_live_for_each_delivery(self):
        traces=[]
        for text in [self.before,self.after]:
            n=Network(text);h=n.human('listener');p=n.phone('source',1001,h);q=n.phone('linked',2002,h)
            q.origincall=p;n.views[h]=[p,q]
            h.on_hear=lambda destination:setattr(q,'origincall',None)
            p.broadcast('message',h);traces.append(n.trace)
        self.assertEqual(*traces)
        self.assertEqual([e[-1] for e in traces[1] if e[0]=='heard'],['source'])

    def call(self,text):
        n=Network(text);a=n.human('caller');b=n.human('callee');c=n.human('redialer')
        p=n.phone('first',1001,a);q=n.phone('second',2002,b);r=n.phone('third',3003,c)
        n.next_number=2002;p.attack_self(a)
        return n,a,b,c,p,q,r

    def test_original_callback_schedule_and_timeout_are_preserved(self):
        traces=[]
        for text in [self.before,self.after]:
            n,a,b,c,p,q,r=self.call(text);n.advance(200);traces.append((n.trace,n.state()))
            self.assertEqual([(e[1],e[3]) for e in n.trace if e[0]=='ring'],[(0,1001),(40,1001),(80,1001),(120,1001),(160,1001)])
            self.assertFalse(q.ringing);self.assertFalse(q.ringingnum);self.assertIsNone(q.origincall)
        self.assertEqual(*traces)

    def test_answer_and_hangup_preserve_messages_and_reciprocal_state(self):
        results=[]
        for text in [self.before,self.after]:
            n,a,b,c,p,q,r=self.call(text);n.advance(5);q.attack_self(b)
            self.assertEqual((p.connected,q.connected),(2002,1001))
            self.assertIs(p.origincall,q);self.assertIs(q.origincall,p)
            n.advance(10);q.attack_self(b)
            self.assertFalse(p.connected);self.assertFalse(q.connected)
            self.assertIsNone(p.origincall);self.assertIsNone(q.origincall)
            n.advance(200);results.append((n.trace,n.state()))
        self.assertEqual(*results)

    def test_answer_hangup_messages_are_once_and_follow_peer_location(self):
        for grounded in [False,True]:
            results=[]
            for text in [self.before,self.after]:
                n,a,b,c,p,q,r=self.call(text)
                if grounded:p.loc='world turf'
                n.advance(5);q.attack_self(b);n.advance(10);q.attack_self(b)
                messages=[e for e in n.trace if e[0] in ['chat','visible']]
                for phrase in ['You pick up the phone.','Someone picks up the phone.',
                               'You hang up the phone.','Someone hangs up the phone.']:
                    matched=[e for e in messages if phrase in e[-1]]
                    self.assertEqual(len(matched),1)
                    expected='visible' if grounded and phrase.startswith('Someone') else 'chat'
                    self.assertEqual(matched[0][0],expected)
                results.append((n.trace,n.state()))
            self.assertEqual(*results)

    def test_duplicate_dial_numbers_preserve_recipient_multiset_and_busy_early_return(self):
        for busy in [False,True]:
            results=[]
            for text in [self.before,self.after]:
                n=Network(text);a=n.human('caller');b=n.human('callee')
                p=n.phone('source',1001,a);q=n.phone('first match',2002,b);r=n.phone('second match',2002,b)
                if busy:q.connected=9999
                n.next_number=2002;p.attack_self(a);n.advance(0)
                ringing=[e[2] for e in n.trace if e[0]=='ring']
                self.assertEqual(ringing,[] if busy else ['first match','second match'])
                results.append((n.trace,n.state()))
            self.assertEqual(*results)

    def test_outgoing_cancel_does_not_silently_change_legacy_remote_ring_semantics(self):
        results=[]
        for text in [self.before,self.after]:
            n,a,b,c,p,q,r=self.call(text);n.advance(5);p.attack_self(a)
            self.assertFalse(p.ringing)
            self.assertTrue(q.ringing)  # Legacy caller is not linked until answer.
            n.advance(40);results.append((n.trace,n.state()))
        self.assertEqual(*results)

    def test_rapid_redial_preserves_old_callback_origin_and_deadline_quirk(self):
        results=[]
        for text in [self.before,self.after]:
            n,a,b,c,p,q,r=self.call(text);n.advance(5);q.attack_self(b)
            n.advance(10);q.attack_self(b)
            n.advance(20);n.next_number=2002;r.attack_self(c)
            n.advance(40)
            self.assertIn(('ring',40,'second',1001),n.trace)
            n.advance(200)
            self.assertFalse(q.ringing)  # Old timeout can terminate the newer unanswered call.
            self.assertIsNone(q.origincall)
            results.append((n.trace,n.state()))
        self.assertEqual(*results)

    def test_call_state_and_ring_procedures_remain_exactly_unchanged(self):
        for declaration in [BASE+'/proc/ringproc',BASE+'/proc/ring',BASE+'/attack_self','/proc/ring_phone']:
            # Fixture separators may add blank lines after a complete procedure.
            self.assertEqual(extract(self.after,declaration).rstrip(),extract(self.before,declaration).rstrip())

    def test_omission_controls_detect_duplicate_humans_and_collapsed_phone_deliveries(self):
        expected=self.recipients(self.after,True).trace
        mutants=[self.after.replace('tried_mobs[hearer] = TRUE','tried_mobs[hearer] = FALSE',1),
                 self.after.replace(' || src == phone','',1),
                 self.after.replace('speaker, src, phone)\n','speaker, src, phone)\n\t\t\t\t\tbreak\n',1)]
        for mutant in mutants:
            self.assertNotEqual(self.recipients(mutant,True).trace,expected)


if __name__ == '__main__':
    unittest.main()
