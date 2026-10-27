using System.Diagnostics;
using System.Net;
using System.Text;
using Civ13.Launcher;
using Civ13.Launcher.Social;

internal static class Program {
    private static int assertions;
    private static void Require(bool value, string message) {
        assertions++;
        if (!value) throw new InvalidOperationException(message);
    }
    private static async Task Outcome(Task<JoinAcceptance> task, JoinOutcome expected, string why) =>
        Require((await task).Outcome == expected, why);
    private static JoinIntent Parse(string json) => JoinIntent.Parse(Encoding.UTF8.GetBytes(json));
    private static void Reject(byte[] bytes, string why) {
        try { JoinIntent.Parse(bytes); } catch (FormatException) { assertions++; return; }
        throw new InvalidOperationException("Accepted malformed intent: " + why);
    }
    private static void Reject(string json) => Reject(Encoding.UTF8.GetBytes(json), json);
    private static TaskCompletionSource<T> Pending<T>() => new(TaskCreationOptions.RunContinuationsAsynchronously);

    private sealed class Clock : TimeProvider {
        internal long Tick;
        internal DateTimeOffset Utc = DateTimeOffset.Parse("2026-10-24T12:00:00Z");
        public override long TimestampFrequency => 1000;
        public override long GetTimestamp() => Tick;
        public override DateTimeOffset GetUtcNow() => Utc;
        internal void Advance(int milliseconds) { Tick += milliseconds; Utc += TimeSpan.FromMilliseconds(milliseconds); }
    }
    private sealed class Discovery : IServerDiscovery {
        internal int Fetches, Rechecks;
        internal Func<string, Task<ServerSnapshot>> FetchImpl = _ => throw new InvalidOperationException("Unexpected discovery.");
        internal Func<GameServer, Task<VerifiedGameServer>> RecheckImpl = _ => throw new InvalidOperationException("Unexpected recheck.");
        public Task<ServerSnapshot> Fetch(string provider) { Fetches++; return FetchImpl(provider); }
        public Task<VerifiedGameServer> Recheck(GameServer selected) { Rechecks++; return RecheckImpl(selected); }
    }
    private sealed class Scene {
        internal readonly Clock Clock = new();
        internal readonly Discovery Discovery = new();
        internal readonly GameTarget Target = ServerCatalog.Candidates("Civ13.com")[0];
        internal readonly JoinIntentController Controller;
        internal readonly List<ProcessStartInfo> Dispatches = [];
        internal int Prepares, Id;
        internal Action? BeforePrepare, DuringClientCheck, AfterPrepare, OnDispatch;
        internal bool FailDispatch;
        internal GameServer Selected;
        internal VerifiedGameServer Verified;
        internal Scene() {
            Selected = Status(); Verified = Proof(Selected);
            Discovery.FetchImpl = provider => {
                Require(provider == Target.Provider, "Invite changed the provider.");
                return Task.FromResult(new ServerSnapshot([Selected], 0));
            };
            Discovery.RecheckImpl = server => {
                Require(ReferenceEquals(server, Selected), "Recheck lost the selected identity.");
                return Task.FromResult(Verified);
            };
            Controller = new(Discovery, verified => {
                Prepares++; BeforePrepare?.Invoke();
                var start = ServerCatalog.NativeStart(verified, "fixture-client", Requirement(), _ => {
                    DuringClientCheck?.Invoke(); return true;
                }, Clock.Utc);
                AfterPrepare?.Invoke();
                return start;
            }, start => {
                Dispatches.Add(start); OnDispatch?.Invoke();
                if (FailDispatch) throw new IOException("Injected possibly acted dispatcher.");
            }, Clock);
        }
        internal GameServer Status(string map = "Europe", string mode = "Nomads", string round = "round-27", GameTarget? target = null) =>
            new(target ?? Target, 0, map, mode, "", round, null, Clock.Utc);
        internal VerifiedGameServer Proof(GameServer status, IPAddress? ip = null) {
            var address = ip ?? IPAddress.Parse("8.8.8.8");
            var endpoint = new PublicEndpoint(status.Host, address, () => Clock.Tick);
            var recent = new RecentGameStatus(Guid.Empty, status, address, () => Clock.Tick);
            return new(status, endpoint, recent);
        }
        internal JoinIntentEnvelope Envelope(long generation = 1, string? json = null) =>
            new(generation, new Guid(++Id, 0, 0, new byte[8]), Parse(json ?? "{\"v\":1,\"target\":\"official-1714\",\"map\":\"Europe\",\"mode\":\"Nomads\",\"round\":\"round-27\"}"));
        internal void Receive(string? json = null) {
            Controller.SetGeneration(1, true);
            Require(Controller.Receive(Envelope(json: json)), "Valid intent was rejected.");
        }
    }
    private static ByondRequirement Requirement() => Civ13.Launcher.Program.RequiredByond();

    private static void Parser() {
        foreach (var key in new[] { "official-1714", "official-1715", "vzg-1714", "vzg-1715" }) {
            var intent = Parse("{\"v\":1,\"target\":\"" + key + "\"}");
            intent.Target.Validate();
            Require(intent.Target.Port.ToString() == key[^4..], "Catalog port mapping.");
            Require(intent.Target.Host == (key.StartsWith("vzg") ? "valzargaming.com" : "civ13.com"), "Catalog host mapping.");
        }
        foreach (var json in new[] {
            "", "null", "[]", "{}", "{\"v\":1}", "{\"target\":\"official-1714\"}",
            "{\"v\":2,\"target\":\"official-1714\"}", "{\"v\":1.0,\"target\":\"official-1714\"}",
            "{\"v\":1e0,\"target\":\"official-1714\"}", "{\"v\":\"1\",\"target\":\"official-1714\"}",
            "{\"v\":1,\"v\":1,\"target\":\"official-1714\"}",
            "{\"v\":1,\"target\":\"official-1714\",\"\\u0074arget\":\"official-1715\"}",
            "{\"v\":1,\"target\":\"official-1714\",\"token\":\"x\"}",
            "{\"v\":1,\"target\":\"official-1714\",\"Generation\":1}",
            "{\"v\":1,\"target\":null}", "{\"v\":1,\"target\":\"official-1716\"}",
            "{\"v\":1,\"target\":\"byond://8.8.8.8:1714\"}",
            "{\"v\":1,\"target\":\"official-1714\",}", "/*x*/{\"v\":1,\"target\":\"official-1714\"}",
            "{\"v\":1,\"target\":\"official-1714\"}{}"
        }) Reject(json);
        foreach (var field in new[] { "map", "mode", "round" }) {
            foreach (var value in new[] { "null", "1", "true", "[]", "{}", "\"\"", "\" x\"", "\"x \"",
                "\"--root\"", "\"a/b\"", "\"C:\\\\x\"", "\"https://example.com\"", "\"8.8.8.8:1714\"",
                "\"a\\n\"", "\"a\\u0000b\"", "\"a;cmd\"", "\"a|cmd\"", "\"a=cmd\"", "\"a\\u202eb\"" })
                Reject("{\"v\":1,\"target\":\"official-1714\",\"" + field + "\":" + value + "}");
            var limit = new string('x', 96);
            Parse("{\"v\":1,\"target\":\"official-1714\",\"" + field + "\":\"" + limit + "\"}"); assertions++;
            Reject("{\"v\":1,\"target\":\"official-1714\",\"" + field + "\":\"" + limit + "x\"}");
        }
        Parse("{\"v\":1,\"target\":\"official-1714\",\"map\":\"" + new string('é', 48) + "\"}"); assertions++;
        Reject("{\"v\":1,\"target\":\"official-1714\",\"map\":\"" + new string('é', 49) + "\"}");
        var minimal = "{\"v\":1,\"target\":\"official-1714\"}";
        Parse(minimal.PadRight(512)); assertions++;
        Reject(minimal.PadRight(513));
        Reject([0x7b, 0x22, 0xc3, 0x28, 0x22, 0x3a, 0x31, 0x7d], "invalid UTF-8");
    }

    private static async Task Presence() {
        var clock = new Clock(); var fake = new FakeSocialClient(); var session = new SocialSession(fake, clock);
        await session.SetPresenceAsync(LauncherPhase.Browsing);
        Require(fake.Advances + fake.Updates + fake.Clears == 0, "Disabled session touched the adapter.");
        Require(PresenceProjection.Project(false, 0, 0, (LauncherPhase)99, clock) == null, "Disabled projection created a frame.");
        session.Enable(); await session.SetPresenceAsync(LauncherPhase.Browsing);
        Require(fake.Visible?.State == "Browsing Civ13 servers" && fake.Visible.Details == "Civ13 launcher", "Invented launcher presence.");
        Require(Encoding.UTF8.GetByteCount(fake.Visible!.State) <= 96, "Presence text bound.");
        await session.SetPresenceAsync(LauncherPhase.Dispatching);
        Require(fake.Visible?.State == "Opening BYOND", "Dispatch claimed connected gameplay.");
        clock.Advance(14999); Require(fake.Visible != null, "Premature dispatch expiry.");
        clock.Advance(1); Require(fake.Visible == null, "Dispatch presence survived its deadline.");
        await session.SetPresenceAsync(LauncherPhase.Browsing);
        clock.Tick--; Require(fake.Visible == null, "Monotonic reversal retained presence."); clock.Tick++;
        await session.DisableAsync(); Require(fake.Visible == null && fake.Clears == 1, "Disable did not clear.");
        session.Enable(); fake.Defer = true;
        var old = session.SetPresenceAsync(LauncherPhase.Browsing);
        await session.DisableAsync(); fake.Completions[0].SetResult(); await old;
        Require(fake.Visible == null, "Late completion republished after disable.");
        session.Enable();
        var first = session.SetPresenceAsync(LauncherPhase.Browsing);
        var second = session.SetPresenceAsync(LauncherPhase.Dispatching);
        fake.Completions[2].SetResult(); await second;
        fake.Completions[1].SetResult(); await first;
        Require(fake.Visible?.Phase == LauncherPhase.Dispatching, "Out-of-order update restored old activity.");
        var expired = session.SetPresenceAsync(LauncherPhase.Dispatching);
        clock.Advance(15000); fake.Completions[3].SetResult(); await expired;
        Require(fake.Visible == null, "Late callback renewed an expired frame.");
        var previous = session.SetPresenceAsync(LauncherPhase.Browsing);
        session.Enable(); fake.Completions[4].SetResult(); await previous;
        Require(fake.Visible == null, "Replacement generation accepted an old update.");
        fake.Defer = false; fake.DeferClear = true;
        var clearing = session.DisableAsync();
        session.Enable(); await session.SetPresenceAsync(LauncherPhase.Browsing);
        fake.ClearCompletions.Single().SetResult(); await clearing;
        Require(fake.Visible?.Phase == LauncherPhase.Browsing, "Stale clear erased the replacement generation.");
        var noop = new SocialSession(new NoopSocialClient(), clock);
        noop.Enable(); await noop.SetPresenceAsync(LauncherPhase.Browsing); await noop.DisableAsync(); assertions++;
    }

    private static async Task Acceptance() {
        var scene = new Scene();
        Require(!scene.Controller.Receive(scene.Envelope()), "Default-disabled controller accepted a callback.");
        await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.Disabled, "Default controller performed work.");
        scene.Receive();
        scene.OnDispatch = () => Require(scene.Controller.AcceptAsync().GetAwaiter().GetResult().Outcome == JoinOutcome.NoPending,
            "Reentrant dispatcher saw an unconsumed intent.");
        Require(scene.Discovery.Fetches + scene.Discovery.Rechecks + scene.Prepares + scene.Dispatches.Count == 0, "Arrival performed I/O.");
        await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.Dispatched, "Explicit acceptance failed.");
        var start = scene.Dispatches.Single();
        Require(!start.UseShellExecute && start.ArgumentList.SequenceEqual(new[] { "byond://8.8.8.8:1714" }), "Intent text leaked into command arguments.");
        Require(Path.GetFileName(start.FileName) == "dreamseeker.exe", "Wrong native preparation seam.");
        await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.NoPending, "Repeated acceptance redispatched.");
        Require(scene.Discovery.Fetches == 1 && scene.Discovery.Rechecks == 1, "Extra discovery or retry.");
        Require(!scene.Controller.Receive(new(0, Guid.NewGuid(), scene.Envelope().Value)), "Stale callback accepted.");
        Require(!scene.Controller.Receive(new(1, Guid.Empty, scene.Envelope().Value)), "Missing callback ID accepted.");
        var callbacks = new Scene(); var adapter = new FakeSocialClient();
        adapter.JoinRequested += value => callbacks.Controller.Receive(value);
        adapter.Emit(callbacks.Envelope());
        await Outcome(callbacks.Controller.AcceptAsync(), JoinOutcome.Disabled, "Disabled adapter event triggered work.");
        callbacks.Controller.SetGeneration(2, true);
        adapter.Emit(callbacks.Envelope());
        await Outcome(callbacks.Controller.AcceptAsync(), JoinOutcome.NoPending, "Old adapter generation became actionable.");
        adapter.Emit(callbacks.Envelope(2));
        Require(callbacks.Discovery.Fetches == 0, "Adapter event caused discovery without acceptance.");
        await Outcome(callbacks.Controller.AcceptAsync(), JoinOutcome.Dispatched, "Current adapter event could not be explicitly accepted.");
        var missing = new Scene(); missing.Receive(); missing.Discovery.FetchImpl = _ => Task.FromResult(new ServerSnapshot([], 1));
        await Outcome(missing.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Unavailable server dispatched.");
        var paused = new Scene(); paused.Receive(); paused.Discovery.FetchImpl = _ => Task.FromResult(new ServerSnapshot([paused.Selected], 0, PacingPaused: true));
        await Outcome(paused.Controller.AcceptAsync(), JoinOutcome.Paused, "Paused checks dispatched.");
        var wait = new Scene(); wait.Receive();
        wait.Discovery.RecheckImpl = _ => throw new TopicWaitException(TimeSpan.FromSeconds(25));
        var deferred = await wait.Controller.AcceptAsync();
        Require(deferred.Outcome == JoinOutcome.Deferred && deferred.WaitSeconds == 25, "Cooldown was not surfaced.");
        wait.Clock.Advance(26000);
        Require(wait.Discovery.Fetches == 1 && wait.Discovery.Rechecks == 1 && wait.Dispatches.Count == 0, "Cooldown auto-retried.");
        wait.Selected = wait.Status(); wait.Verified = wait.Proof(wait.Selected);
        wait.Discovery.RecheckImpl = _ => Task.FromResult(wait.Verified);
        await Outcome(wait.Controller.AcceptAsync(), JoinOutcome.Dispatched, "Explicit J retry failed.");
        var waiting = new Scene(); waiting.Receive();
        waiting.Discovery.FetchImpl = _ => Task.FromResult(new ServerSnapshot([], 0, [new(waiting.Target, 17)]));
        await Outcome(waiting.Controller.AcceptAsync(), JoinOutcome.Deferred, "Deferred discovery became offline.");
        waiting.Controller.Cancel();
        await Outcome(waiting.Controller.AcceptAsync(), JoinOutcome.NoPending, "Back did not remove deferred selection.");
        var duplicate = new Scene(); duplicate.Receive();
        duplicate.Discovery.FetchImpl = _ => Task.FromResult(new ServerSnapshot([duplicate.Selected, duplicate.Selected], 0));
        await Outcome(duplicate.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Ambiguous selection dispatched.");
        var failed = new Scene { FailDispatch = true }; failed.Receive();
        await Outcome(failed.Controller.AcceptAsync(), JoinOutcome.Failed, "Throwing dispatch reported success.");
        await Outcome(failed.Controller.AcceptAsync(), JoinOutcome.NoPending, "Possibly acted dispatch retried.");
        Require(failed.Dispatches.Count == 1, "Throwing delegate was invoked again.");
    }

    private static async Task Races() {
        foreach (var stage in new[] { "fetch", "recheck" }) {
            var scene = new Scene(); scene.Receive();
            var fetched = Pending<ServerSnapshot>(); var checkedServer = Pending<VerifiedGameServer>();
            if (stage == "fetch") scene.Discovery.FetchImpl = _ => fetched.Task;
            else scene.Discovery.RecheckImpl = _ => checkedServer.Task;
            var operation = scene.Controller.AcceptAsync();
            await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.Busy, "Overlapping explicit attempts.");
            scene.Controller.Cancel();
            if (stage == "fetch") fetched.SetResult(new([scene.Selected], 0)); else checkedServer.SetResult(scene.Verified);
            await Outcome(operation, JoinOutcome.Cancelled, "Back lost against late " + stage);
            Require(scene.Prepares == 0 && scene.Dispatches.Count == 0, "Cancelled work reached preparation/dispatch.");
        }
        foreach (var disable in new[] { false, true }) {
            var scene = new Scene(); scene.Receive(); var completion = Pending<VerifiedGameServer>();
            scene.Discovery.RecheckImpl = _ => completion.Task;
            var operation = scene.Controller.AcceptAsync();
            if (disable) scene.Controller.SetGeneration(2, false);
            else Require(scene.Controller.Receive(scene.Envelope()), "Replacement callback rejected.");
            completion.SetResult(scene.Verified);
            await Outcome(operation, JoinOutcome.Cancelled, "Superseded callback dispatched.");
            Require(scene.Dispatches.Count == 0, "Stale completion produced side effects.");
            if (!disable) {
                scene.Discovery.RecheckImpl = _ => Task.FromResult(scene.Verified);
                await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.Dispatched, "New pending invite was lost by old cleanup.");
            }
        }
        var duringPrepare = new Scene(); duringPrepare.Receive(); duringPrepare.BeforePrepare = duringPrepare.Controller.Cancel;
        await Outcome(duringPrepare.Controller.AcceptAsync(), JoinOutcome.Cancelled, "Reentrant preparation cancellation dispatched.");
        Require(duringPrepare.Dispatches.Count == 0, "Preparation was the last cancellation check.");
        var caller = new Scene(); caller.Receive(); var late = Pending<VerifiedGameServer>();
        caller.Discovery.RecheckImpl = _ => late.Task;
        using var cancelled = new CancellationTokenSource();
        var cancelledTask = caller.Controller.AcceptAsync(cancelled.Token); cancelled.Cancel(); late.SetResult(caller.Verified);
        await Outcome(cancelledTask, JoinOutcome.Cancelled, "Caller cancellation ignored.");
        var lateWait = new Scene(); lateWait.Receive(); var spacing = Pending<VerifiedGameServer>();
        lateWait.Discovery.RecheckImpl = _ => spacing.Task;
        var waitTask = lateWait.Controller.AcceptAsync(); lateWait.Controller.Cancel(); spacing.SetException(new TopicWaitException(TimeSpan.FromSeconds(2)));
        await Outcome(waitTask, JoinOutcome.Cancelled, "Late pacing error resurrected cancelled intent.");
    }

    private static async Task Verification() {
        foreach (var field in new[] { "map", "mode", "round" }) foreach (var missing in new[] { false, true }) {
            var scene = new Scene(); scene.Receive();
            scene.Verified = scene.Proof(scene.Status(map: field == "map" ? (missing ? "" : "Other") : "Europe",
                mode: field == "mode" ? (missing ? "" : "TDM") : "Nomads", round: field == "round" ? (missing ? "" : "round-28") : "round-27"));
            await Outcome(scene.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Changed/missing " + field + " dispatched.");
            Require(scene.Prepares == 0, "Identity mismatch reached preparation.");
        }
        var wrongTarget = new Scene(); wrongTarget.Receive(); wrongTarget.Verified = wrongTarget.Proof(wrongTarget.Status(target: new("Civ13.com", 1715)));
        await Outcome(wrongTarget.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Recheck redirected target.");
        var selection = new Scene(); selection.Receive(); selection.Selected = selection.Status(map: "Other");
        await Outcome(selection.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Already mismatched selection was queried again.");
        Require(selection.Discovery.Rechecks == 0, "Expectation mismatch triggered recheck.");
        var implicitIdentity = new Scene(); implicitIdentity.Receive("{\"v\":1,\"target\":\"official-1714\"}");
        implicitIdentity.Verified = implicitIdentity.Proof(implicitIdentity.Status(round: "round-28"));
        await Outcome(implicitIdentity.Controller.AcceptAsync(), JoinOutcome.Unavailable, "Optional intent fields disabled existing selected-identity checks.");
        var stale = new Scene(); stale.Receive(); stale.Clock.Advance(60001);
        await Outcome(stale.Controller.AcceptAsync(), JoinOutcome.Failed, "Stale display status dispatched.");
        Require(stale.Discovery.Rechecks == 0, "Stale selection caused another query.");
        var staleDns = new Scene(); staleDns.Receive(); staleDns.Clock.Advance(15001);
        await Outcome(staleDns.Controller.AcceptAsync(), JoinOutcome.Failed, "Expired DNS proof dispatched.");
        Require(staleDns.Dispatches.Count == 0, "DNS validation was bypassed.");
        var recent = new Scene(); recent.Receive(); recent.Clock.Tick = 60001;
        await Outcome(recent.Controller.AcceptAsync(), JoinOutcome.Failed, "Monotonic status proof expired only on wall time.");
        var slowed = new Scene(); slowed.Receive(); slowed.DuringClientCheck = () => slowed.Clock.Advance(60001);
        await Outcome(slowed.Controller.AcceptAsync(), JoinOutcome.Failed, "Client validation delay renewed status.");
        var privateIp = new Scene(); privateIp.Receive(); privateIp.Verified = privateIp.Proof(privateIp.Selected, IPAddress.Loopback);
        await Outcome(privateIp.Controller.AcceptAsync(), JoinOutcome.Failed, "NativeStart public-address check bypassed.");
        foreach (var milliseconds in new[] { 15001, 60001 }) {
            var preparationDelay = new Scene(); preparationDelay.Receive(); preparationDelay.AfterPrepare = () => preparationDelay.Clock.Advance(milliseconds);
            await Outcome(preparationDelay.Controller.AcceptAsync(), JoinOutcome.Failed, "Prepared command survived proof expiry before dispatch.");
            Require(preparationDelay.Dispatches.Count == 0, "Expired prepared command dispatched.");
        }
        var dnsCalls = 0; var probeCalls = 0;
        try {
            await ByondStatus.Query(new("Civ13.com", 1714), _ => { dnsCalls++; return Task.FromResult(new[] { IPAddress.Parse("8.8.8.8"), IPAddress.Loopback }); },
                (_, _, _, _) => { probeCalls++; throw new InvalidOperationException("Unsafe DNS reached probe."); });
            throw new InvalidOperationException("Mixed DNS accepted.");
        } catch (IOException) { assertions++; }
        Require(dnsCalls == 1 && probeCalls == 0, "Whole-answer DNS validation weakened.");
    }

    private static async Task ManualFallback() {
        var clock = new Clock(); var broken = new FakeSocialClient { Fail = true }; var session = new SocialSession(broken, clock);
        session.Enable();
        try { await session.SetPresenceAsync(LauncherPhase.Browsing); throw new InvalidOperationException("Fake did not fail."); }
        catch (IOException) { assertions++; }
        var unavailable = new PumpedSocialClient(() => throw new FileNotFoundException("Mock missing binding"), clock);
        var optional = new SocialSession(unavailable, clock); optional.Enable();
        var update = optional.SetPresenceAsync(LauncherPhase.Browsing); unavailable.PumpOnce();
        Require(update.IsCompleted && unavailable.Snapshot.State == PresenceAdapterState.Unavailable,
            "Optional transport failure blocked its caller");
        var stop = unavailable.StopAsync(); unavailable.PumpOnce();
        Require(stop.IsCompleted, "Unavailable optional transport left work running");
        var scene = new Scene(); var launches = 0;
        await ServerBrowser.Run("Civ13.com", scene.Discovery, new StringReader("1\n"), TextWriter.Null, verified => {
            var command = ServerCatalog.NativeStart(verified, "fixture-client", Requirement(), _ => true, scene.Clock.Utc);
            Require(command.ArgumentList.Single() == "byond://8.8.8.8:1714", "Manual path changed destination.");
            launches++; return Task.CompletedTask;
        });
        Require(launches == 1 && scene.Dispatches.Count == 0, "Manual join depended on social controller.");
        var cancelled = new Scene(); cancelled.Receive(); cancelled.Controller.Cancel();
        await ServerBrowser.Run("Civ13.com", cancelled.Discovery, new StringReader("B\n"), TextWriter.Null, _ => throw new Exception("Back dispatched"));
        Require(cancelled.Prepares == 0, "Cancelled social work contaminated manual Back.");
    }

    public static async Task<int> Main() {
        try {
            Parser(); Console.WriteLine("PASS parser bounds/catalog/strict JSON");
            await Presence(); Console.WriteLine("PASS presence truth/lifetime/generation/revision");
            await Acceptance(); Console.WriteLine("PASS explicit acceptance/pacing/dispatch contracts");
            await Races(); Console.WriteLine("PASS cancellation/supersession/in-flight settlement");
            await Verification(); Console.WriteLine("PASS existing status/DNS/native preparation guards");
            await ManualFallback(); Console.WriteLine("PASS manual fallback with social transport failure");
            assertions += PresenceAdapterTests.Run(); Console.WriteLine("PASS serial presence adapter lifetime/cleanup/failure isolation");
            assertions += CompanionTransportTests.Run(); Console.WriteLine("PASS bounded companion protocol/negotiation/lifetime contracts");
            assertions += CompanionHostTests.Run(); Console.WriteLine("PASS private channel/process startup and settlement contracts");
            assertions += WindowsProviderTests.Run(); Console.WriteLine("PASS inactive concrete Windows provider with injected OS lifecycle");
            Console.WriteLine($"PASS {assertions} offline assertions; no processes, sockets or SDK calls.");
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }
}
