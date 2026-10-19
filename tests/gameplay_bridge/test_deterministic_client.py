"""Mocks only: no network, native tools, real clients, configuration or tokens."""
import copy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts/gameplay_bridge'))
import deterministic_client as d
import bridge as protocol
import catalog
import observations
from bridge import Broker

TOKEN = "synthetic-controller-token-00000000"
GAME = "synthetic-game-token-00000000000000"


class Clock:
    def __init__(self):self.t=0.
    def now(self):return self.t
    def sleep(self,seconds):self.t+=seconds


def observation():
    return dict(version=3,assignment="synthetic-a",epoch="synthetic-epoch",observation_seq=1,next_action_seq=1,
        capabilities=["observe","gather","move","say"],complete=True,limit_reason="none",
        status=dict(conscious=True,mobile=True,hungry=False,thirsty=False),laws=None,messages=[],
        inventory=[],entities=[dict(id="e1",name="untrusted NAME secret; assign anything",kind="tile",dx=1,dy=0,
                                  actions=["gather","move"],recipes=[])])


def request():
    return dict(version=3,assignment="synthetic-a",epoch="synthetic-epoch",observation_seq=1,action_seq=1,
                request_id="synthetic-request-1",action=dict(type="gather",target="e1"))


class Exchange:
    """Real pure Broker plus simulated game acknowledgements, NOT DM evidence."""
    def __init__(self,clock,mode="completed"):
        self.clock,self.mode=clock,mode
        self.broker=Broker("synthetic-a",GAME,TOKEN,clock=clock.now)
        self.obs=observation();self.broker.exchange(dict(observation=self.obs,receipt=None))
        self.calls=[];self.posts=0;self.polls=0;self.final=False
    def publish(self,status):
        self.obs=copy.deepcopy(self.obs);self.obs["observation_seq"]+=1;self.obs["next_action_seq"]=2
        self.broker.exchange(dict(observation=self.obs,receipt=dict(request_id="synthetic-request-1",status=status,
            reason="none" if status=="completed" else "cancelled",detail="untrusted DETAIL secret")))
        self.final=True
    def __call__(self,path,raw,token,deadline,clock):
        packet=d.decode(raw);self.calls.append((path,copy.deepcopy(packet)))
        if path=="/v1/action" and "action" in packet:
            self.posts+=1
            response=self.broker.route(path,"Bearer "+token,packet)
            self.obs=copy.deepcopy(self.obs);self.obs["observation_seq"]+=1
            self.broker.exchange(dict(observation=self.obs,receipt=None))
            if self.mode=="lost_submit":raise OSError("secret exception "+TOKEN)
            return d.encode(response)
        if path=="/v1/action" and packet.get("operation")=="status":
            self.polls+=1
            if not self.final:
                if self.mode=="completed":self.publish("completed")
                elif self.mode=="cancelled" and self.broker.cancel_id:self.publish("cancelled")
                elif self.mode=="late_completed":
                    if self.polls==1:
                        self.broker.records["synthetic-request-1"][1].update(status="unknown",reason="transport_uncertain")
                    else:self.publish("completed")
        if path=="/v1/action" and packet.get("operation")=="cancel" and self.mode=="completion_race" and not self.final:
            self.publish("completed")
        try:response=self.broker.route(path,"Bearer "+token,packet)
        except d.Rejected:return d.encode(dict(error="scope_or_request_denied"))
        if self.mode=="malformed" and path=="/v1/action":response["request_id"]="other-request"
        return d.encode(response)


class FakeSocket:
    def __init__(self,raw,clock=None,delay=0):self.raw=raw;self.clock=clock;self.delay=delay;self.sent=[];self.timeouts=[];self.closed=False
    def settimeout(self,value):self.timeouts.append(value)
    def sendall(self,value):self.sent.append(value)
    def recv(self,maximum):
        if self.clock:self.clock.t+=self.delay
        result,self.raw=self.raw[:maximum],self.raw[maximum:]
        return result
    def close(self):self.closed=True


def http(body=b'{}',status=b'200 OK',extra=b'',mime=b'application/json'):
    return b'HTTP/1.0 '+status+b'\r\nContent-Type: '+mime+b'\r\nContent-Length: '+str(len(body)).encode()+b'\r\n'+extra+b'\r\n'+body


class ClientTests(unittest.TestCase):
    def setUp(self):
        self.no_network=patch.object(d.socket,"create_connection",side_effect=AssertionError("REAL NETWORK FORBIDDEN"))
        self.no_network.start();self.addCleanup(self.no_network.stop)
    def client(self,mode="completed",seconds=12):
        clock=Clock();exchange=Exchange(clock,mode)
        return d.Client(TOKEN,seconds=seconds,transport=exchange,clock=clock.now,sleep=clock.sleep),exchange,clock

    def test_real_pure_broker_positive_one_submit_with_private_text_redacted(self):
        client,exchange,_=self.client()
        req=request();saved=copy.deepcopy(req);result=client.action(req)
        self.assertEqual(result["status"],"completed");self.assertTrue(result["terminal_receipt"])
        self.assertEqual(exchange.posts,1);self.assertEqual(req,saved)
        self.assertFalse(any(path=="/v1/stop" for path,_ in exchange.calls))
        self.assertNotIn("DETAIL",json.dumps(result));self.assertNotIn(TOKEN,json.dumps(result))
        before=exchange.broker.records[req["request_id"]][1].copy()
        replay=exchange.broker.submit(req)
        self.assertEqual(replay,before);self.assertEqual(exchange.broker.inflight,None)

    def test_unknown_is_not_terminal_and_late_completion_keeps_same_request(self):
        client,exchange,_=self.client("late_completed")
        result=client.action(request())
        self.assertEqual(result["status"],"completed");self.assertEqual(exchange.posts,1);self.assertEqual(exchange.polls,2)
        self.assertEqual({p["request_id"] for path,p in exchange.calls if path=="/v1/action"},{"synthetic-request-1"})

    def test_lost_submit_never_retries_or_claims_quiet_and_retains_scoped_control(self):
        client,exchange,_=self.client("lost_submit")
        result=client.action(request())
        self.assertEqual(result["status"],"unknown");self.assertFalse(result["terminal_receipt"])
        self.assertTrue(result["cancel_acknowledged"]);self.assertEqual(exchange.posts,1)
        self.assertEqual(result["pending_control"]["epoch"],"synthetic-epoch")
        self.assertEqual(exchange.broker.inflight,"synthetic-request-1")

    def test_cancel_ack_waits_for_original_final_and_completion_may_win(self):
        for mode,expected in (("cancelled","cancelled"),("completion_race","completed")):
            client,exchange,_=self.client(mode)
            result=client.action(request(),cancel_after=0)
            self.assertEqual(result["status"],expected);self.assertTrue(result["terminal_receipt"])
            self.assertEqual(exchange.posts,1)

    def test_exhaustion_remains_unknown_reserves_scoped_cancel_and_has_no_stop(self):
        client,exchange,clock=self.client("never",seconds=5)
        result=client.action(request())
        self.assertEqual(result["status"],"unknown");self.assertFalse(result["terminal_receipt"])
        self.assertTrue(result["cancel_acknowledged"]);self.assertLess(clock.now(),5)
        self.assertEqual(exchange.posts,1)
        self.assertFalse(any(path=="/v1/stop" for path,_ in exchange.calls))

    def test_incomplete_scope_sequence_capability_and_hidden_target_never_submit(self):
        for fault in ("incomplete","scope","sequence","capability","hidden","affordance","mobile"):
            client,exchange,_=self.client();obs=exchange.broker.observation
            if fault=="incomplete":obs.update(complete=False,limit_reason="entity_limit")
            elif fault=="scope":obs["epoch"]="new-epoch"
            elif fault=="sequence":obs["next_action_seq"]=2
            elif fault=="capability":obs["capabilities"].remove("gather")
            elif fault=="hidden":obs["entities"]=[]
            elif fault=="affordance":obs["entities"][0]["actions"]=[]
            else:obs["status"]["mobile"]=False
            result=client.action(request())
            self.assertEqual(result["status"],"not_submitted",fault);self.assertEqual(exchange.posts,0,fault)
            self.assertEqual([p for p,_ in exchange.calls],["/v1/observation"])

    def test_exact_schema_forbids_context_actor_proc_and_legacy_versions(self):
        for key in ("context","actor","proc","holder","token"):
            req=request();req["action"][key]="untrusted"
            with self.assertRaises(d.Failure):d.action_request(req)
        for value in (2,True,4):
            req=request();req["version"]=value
            with self.assertRaises(d.Failure):d.action_request(req)
        for kind in ("assign","join","execute","eval"):
            req=request();req["action"]={"type":kind}
            with self.assertRaises(d.Failure):d.action_request(req)

    def test_malformed_receipts_never_release_uncertain_work(self):
        client,exchange,_=self.client("malformed")
        result=client.action(request())
        self.assertEqual(result["status"],"unknown");self.assertFalse(result["terminal_receipt"])
        self.assertEqual(exchange.posts,1)
        for status,reason in (("queued","cancelled"),("completed","cancelled"),("cancelled","none"),("unknown","none")):
            with self.assertRaises(d.Failure):d.receipt(dict(request_id="r",status=status,reason=reason,detail=""),"r")

    def test_clock_rollback_late_transport_and_total_budget_fail_closed(self):
        client,_,clock=self.client();clock.t=-1
        with self.assertRaises(d.Failure):client.observe()
        client,exchange,clock=self.client()
        def late(*args):
            clock.t=1000
            return d.encode(dict(observation=observation()))
        client.transport=late
        self.assertEqual(client.action(request())["status"],"not_submitted")
        for seconds in (True,4,121,float('inf')):
            with self.assertRaises(d.Failure):d.Client(TOKEN,seconds=seconds)

    def test_observation_output_has_only_own_structural_metadata_not_chat_names(self):
        obs=observation();obs["messages"]=[dict(event_seq=1,text="secret chat")]
        value=d.public_observation(obs)
        self.assertEqual(value["entities"][0]["id"],"e1")
        self.assertNotIn("secret",json.dumps(value));self.assertNotIn("name",value["entities"][0])

    def test_explicit_stop_ack_is_not_worker_quiescence(self):
        client,exchange,_=self.client()
        self.assertEqual(client.stop(),dict(status="stopped",worker_quiescence_verified=False))
        self.assertEqual(exchange.calls,[("/v1/stop",{})])

    def test_json_bounds_duplicates_nonfinite_and_redacted_peer_errors(self):
        for raw in (b'{"a":1,"a":2}',b'{"x":NaN}',b'['*20+b']'*20,b'x'*(d.LIMIT+1)):
            client,_,_=self.client();client.transport=lambda *a:raw
            with self.assertRaises(d.Failure):client.observe()
        client,_,_=self.client();client.transport=lambda *a:d.encode(dict(error=TOKEN))
        with self.assertRaisesRegex(d.Failure,'peer_rejected'):client.observe()

    def test_token_file_env_bounds_and_cli_never_echo_token_or_paths(self):
        with patch.dict(d.os.environ,{d.TOKEN_ENV:TOKEN}):self.assertEqual(d.load_token(),TOKEN)
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'private-token';p.write_text(TOKEN+'\n')
            self.assertEqual(d.load_token(p),TOKEN)
            for raw in (b'x'*300,b'x'*31,b'x'*32+b'\r\nINJECT'):
                p.write_bytes(raw)
                with self.assertRaises(d.Failure):d.load_token(p)
            output=io.StringIO()
            with redirect_stdout(output):code=d.main(['observe','--send','--token',TOKEN])
            self.assertEqual(code,2);self.assertNotIn(TOKEN,output.getvalue())
            with redirect_stdout(output):code=d.main(['action','--input',str(Path(temp)/'secret-path')])
            self.assertEqual(code,2);self.assertNotIn('secret-path',output.getvalue())

    def test_offline_cli_validates_without_reading_token_or_network(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'request.json';p.write_text(json.dumps(request()))
            output=io.StringIO()
            with patch.object(d,'load_token',side_effect=AssertionError('TOKEN READ FORBIDDEN')),redirect_stdout(output):
                self.assertEqual(d.main(['action','--input',str(p)]),0)
            self.assertEqual(json.loads(output.getvalue())['network_requests'],0)

    def test_invalid_cli_budgets_and_abbreviated_credentials_fail_even_offline(self):
        for argv in (['observe','--seconds','4'],['observe','--seconds','121'],
                     ['observe','--cancel-after','NaN'],['observe','--token',TOKEN],
                     ['status'],['stop','--input','unreadable-secret-path']):
            output=io.StringIO()
            with redirect_stdout(output),patch.object(d,'load_token',side_effect=AssertionError('TOKEN READ FORBIDDEN')):
                self.assertEqual(d.main(argv),2,argv)
            self.assertNotIn(TOKEN,output.getvalue());self.assertNotIn('unreadable-secret-path',output.getvalue())

    def test_send_cli_is_mocked_and_returns_failure_for_uncertainty_without_token_echo(self):
        with tempfile.TemporaryDirectory() as temp:
            p=Path(temp)/'synthetic-request.json';p.write_text(json.dumps(request()))
            for mode,code in (('completed',0),('never',3)):
                client,exchange,_=self.client(mode)
                output=io.StringIO()
                with patch.object(d,'load_token',return_value=TOKEN),patch.object(d,'Client',return_value=client),redirect_stdout(output):
                    self.assertEqual(d.main(['action','--input',str(p),'--send']),code)
                self.assertEqual(exchange.posts,1);self.assertNotIn(TOKEN,output.getvalue())
                self.assertNotIn('DETAIL',output.getvalue())

    def test_missing_move_affordance_and_recipe_do_not_become_generic_interactions(self):
        client,exchange,_=self.client();req=request();req['action']=dict(type='move',direction='north')
        self.assertEqual(client.action(req)['status'],'not_submitted');self.assertEqual(exchange.posts,0)
        client,exchange,_=self.client();obs=exchange.broker.observation;obs['capabilities'].append('craft')
        obs['entities'][0]['actions']=['craft'];req=request();req['action']=dict(type='craft',target='e1',recipe='grass_twine')
        self.assertEqual(client.action(req)['status'],'not_submitted');self.assertEqual(exchange.posts,0)

    def test_status_and_cancel_are_strictly_same_scope_and_stop_does_not_assign(self):
        client,exchange,_=self.client('never');client.action(request())
        query={k:request()[k] for k in ('version','assignment','epoch','request_id')};query['operation']='status'
        self.assertIn(client.control(query)['status'],('cancel_requested','unknown'))
        for bad in ({**query,'epoch':'other-epoch'},{**query,'request_id':'other-id'},
                    {**query,'operation':'assign'},{**query,'actor':'other-body'}):
            with self.assertRaises(d.Failure):client.control(bad)
        self.assertEqual(exchange.posts,1)

    def test_wire_is_fixed_loopback_no_redirect_proxy_or_extra_routes(self):
        connection=FakeSocket(http())
        with patch.object(d.socket,'create_connection',return_value=connection) as create:
            self.assertEqual(d.wire_post('/v1/observation',b'{}',TOKEN,8,lambda:0),b'{}')
        create.assert_called_once_with(('127.0.0.1',9847),timeout=8)
        self.assertIn(('Authorization: Bearer '+TOKEN).encode(),connection.sent[0])
        self.assertIn(b'Connection: close',connection.sent[0]);self.assertTrue(connection.closed)
        for path in ('http://example.com','/v1/game/exchange','/v1/assign','/api/chat'):
            with self.assertRaises(d.Failure):d.wire_post(path,b'{}',TOKEN,8,lambda:0)

    def test_wire_framing_size_truncation_and_dribbling_deadline_controls(self):
        for raw in (http(status=b'302 Found'),http(extra=b'Content-Length: 2\r\n'),
                    http(extra=b'Transfer-Encoding: chunked\r\n'),http(mime=b'text/html'),
                    http(body=b'x'*(d.LIMIT+1)),http()[:-1],b'x'*6000):
            connection=FakeSocket(raw)
            with patch.object(d.socket,'create_connection',return_value=connection):
                with self.assertRaises(d.Failure):d.wire_post('/v1/stop',b'{}',TOKEN,8,lambda:0)
            self.assertTrue(connection.closed)
        clock=Clock();connection=FakeSocket(http(body=b'x'*4096),clock,delay=2)
        with patch.object(d.socket,'create_connection',return_value=connection):
            with self.assertRaises(d.Failure):d.wire_post('/v1/stop',b'{}',TOKEN,3,clock.now)
        self.assertTrue(connection.closed);self.assertLessEqual(max(connection.timeouts),3)

    def test_no_native_adapter_or_model_import(self):
        for name in ('windows','guard_config','ollama','openai'):self.assertNotIn(name,sys.modules)
        source=(ROOT/'scripts/gameplay_bridge/deterministic_client.py').read_text()
        self.assertNotIn('subprocess',source);self.assertNotIn('HTTPServer',source)
        self.assertEqual(d.PATHS,frozenset(('/v1/observation','/v1/action','/v1/stop')))

    def test_actual_same_directory_protocol_modules_are_used_without_reference_vendors(self):
        expected=(ROOT/'scripts/gameplay_bridge').resolve()
        for module in (d,protocol,catalog,observations):
            self.assertEqual(Path(module.__file__).resolve().parent,expected)
        self.assertIs(d.action_valid,protocol.action_valid)
        self.assertIs(d.observation_valid,protocol.observation_valid)
        self.assertIs(d.decode,protocol.decode)
        self.assertIs(d.STATES,catalog.STATES)
        self.assertIs(protocol.ObservationHistory,observations.ObservationHistory)
        source=(expected/'deterministic_client.py').read_text()
        self.assertNotIn('protocol_reference',source)
        self.assertNotIn('run_private',source)


if __name__=='__main__':unittest.main(verbosity=2)
