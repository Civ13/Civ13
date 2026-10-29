using Civ13.Launcher.Social;

internal static class PresenceAdapterTests {
    private static int checks;
    private static void Check(bool value, string why) {
        checks++;
        if (!value) throw new InvalidOperationException("Presence adapter: " + why);
    }
    private sealed class Clock : TimeProvider {
        internal long Tick;
        public override long TimestampFrequency => 1000;
        public override long GetTimestamp() => Tick;
    }
    private sealed class Transport : IDiscordPresenceTransport {
        internal readonly List<LauncherPresence> Publications = [];
        internal readonly List<Action<PresenceTransportResult>> Callbacks = [];
        internal readonly List<string> Calls = [];
        internal readonly List<int> Threads = [];
        internal int Clears, Disposals;
        internal LauncherPresence? Visible;
        internal string? ThrowAt;
        internal Action? OnPublish, OnClear;
        private void Record(string operation) {
            Calls.Add(operation); Threads.Add(Environment.CurrentManagedThreadId);
            if (ThrowAt == operation) throw new IOException("Injected transport exception, not a native call.");
        }
        public void Publish(LauncherPresence activity, Action<PresenceTransportResult> completion) {
            Record("publish"); Publications.Add(activity); Callbacks.Add(completion); OnPublish?.Invoke();
        }
        public void Clear() { Clears++; Record("clear"); Visible = null; OnClear?.Invoke(); }
        public void RunCallbacks() => Record("pump");
        public void Dispose() { Disposals++; Record("dispose"); }
        internal void Complete(int index, PresenceTransportResult result = PresenceTransportResult.Accepted) {
            if (result == PresenceTransportResult.Accepted) Visible = Publications[index];
            Callbacks[index](result);
        }
    }
    private sealed class Scene : IDisposable {
        internal readonly Clock Clock = new();
        internal readonly Transport Native = new(); // A pure fake, never a DLL/client.
        internal readonly PumpedSocialClient Client;
        internal int Factories;
        internal Func<IDiscordPresenceTransport>? Factory;
        internal Scene(int timeoutMilliseconds = 5000) => Client = new(() => {
            Factories++;
            return Factory?.Invoke() ?? Native;
        }, Clock, TimeSpan.FromMilliseconds(timeoutMilliseconds));
        internal PresenceFrame Frame(long generation = 1, long revision = 1, LauncherPhase phase = LauncherPhase.Browsing) =>
            PresenceProjection.Project(true, generation, revision, phase, Clock)!;
        internal Task Begin(LauncherPhase phase = LauncherPhase.Browsing) {
            Client.AdvanceGeneration(1);
            var task = Client.UpdateAsync(Frame(phase: phase), CancellationToken.None);
            Client.PumpOnce(); return task;
        }
        internal void Success(int index = 0) { Native.Complete(index); Client.PumpOnce(); }
        public void Dispose() {
            var stop = Client.StopAsync();
            // Every fake callback is finite. No timer/sleep/native cancellation is
            // used to settle the worker and all task-owned operations at teardown.
            for (var i = 0; i < Native.Callbacks.Count; i++) Native.Callbacks[i](PresenceTransportResult.Accepted);
            Client.PumpOnce();
            Check(stop.IsCompletedSuccessfully, "teardown left a pending action");
        }
    }

    private static void DisabledAndMapping() {
        using var s = new Scene();
        s.Client.PumpOnce();
        Check(s.Client.Snapshot.State == PresenceAdapterState.Disabled && s.Factories == 0, "default disabled loaded a transport");
        Check(s.Client.UpdateAsync(s.Frame(), CancellationToken.None).IsCompleted, "disabled update stayed pending");
        s.Client.AdvanceGeneration(1); s.Client.PumpOnce();
        Check(s.Factories == 0, "enable alone constructed a native client");
        var update = s.Client.UpdateAsync(s.Frame(), CancellationToken.None);
        Check(!update.IsCompleted && s.Native.Calls.Count == 0, "producer executed transport work");
        s.Client.PumpOnce();
        Check(s.Factories == 1 && s.Native.Publications.Single() == new LauncherPresence("Civ13 launcher", "Browsing Civ13 servers"), "mapping invented gameplay/session data");
        Check(s.Client.Snapshot.State == PresenceAdapterState.Publishing, "invocation falsely reported publication");
        s.Native.Complete(0);
        Check(s.Client.Snapshot.State == PresenceAdapterState.Publishing && !update.IsCompleted, "callback mutated adapter outside the pump");
        s.Client.PumpOnce();
        Check(update.IsCompletedSuccessfully && s.Client.Snapshot.State == PresenceAdapterState.Accepted, "successful callback not observed");
        s.Native.Callbacks[0](PresenceTransportResult.Failed); s.Client.PumpOnce();
        Check(s.Client.Snapshot.Failure == PresenceAdapterFailure.None, "duplicate callback changed the accepted result");
        Check(s.Native.Threads.Distinct().Count() == 1, "transport calls left the pump thread");
    }
    private static void CoalescingAndGenerations() {
        using var s = new Scene(); s.Client.AdvanceGeneration(1);
        var tasks = Enumerable.Range(1, 1000).Select(i => s.Client.UpdateAsync(s.Frame(revision: i,
            phase: i == 1000 ? LauncherPhase.Dispatching : LauncherPhase.Browsing), CancellationToken.None)).ToArray();
        Check(tasks[..^1].All(t => t.IsCompleted) && !tasks[^1].IsCompleted, "pending queue did not coalesce/settle superseded work");
        Check(s.Client.Snapshot is { Pending: true, InFlight: false } && s.Factories == 0, "pending admission performed native work");
        s.Client.PumpOnce();
        Check(s.Native.Publications.Count == 1 && s.Native.Publications[0].State == "Opening BYOND", "coalesced update was not the newest");
        var next = s.Client.UpdateAsync(s.Frame(revision: 1001), CancellationToken.None);
        s.Client.PumpOnce();
        Check(s.Native.Publications.Count == 1, "new publish overlapped an unresolved native callback");
        s.Success();
        Check(tasks[^1].IsCompleted && s.Native.Clears == 1 && s.Native.Publications.Count == 2, "old completion was not cleared before new work");
        s.Success(1); Check(next.IsCompletedSuccessfully, "newest request did not settle");
        var obsolete = s.Client.UpdateAsync(s.Frame(revision: 1002), CancellationToken.None); s.Client.PumpOnce();
        s.Client.AdvanceGeneration(2);
        var clear = s.Client.ClearAsync(2, new CancellationToken(true));
        Check(obsolete.IsCompleted && !clear.IsCompleted && s.Native.Clears == 1, "generation change called clear or waited on caller cancellation");
        s.Client.PumpOnce(); Check(!clear.IsCompleted, "clear completed before old native operation settled");
        s.Success(2);
        Check(clear.IsCompletedSuccessfully && s.Native.Visible == null && s.Native.Disposals == 1, "late old publication survived opt-out");
        Check(s.Client.Snapshot.State == PresenceAdapterState.ClearIssued, "void clear was misreported as publication");
        var secondTransport = new Transport(); s.Factory = () => secondTransport;
        s.Client.AdvanceGeneration(3);
        var current = s.Client.UpdateAsync(s.Frame(3), CancellationToken.None); s.Client.PumpOnce();
        Check(s.Factories == 2 && secondTransport.Publications.Count == 1, "explicit new session could not recreate after clean opt-out");
        s.Native.Callbacks[2](PresenceTransportResult.Failed); secondTransport.Complete(0); s.Client.PumpOnce();
        Check(current.IsCompleted && s.Client.Snapshot.State == PresenceAdapterState.Accepted, "old client's late callback poisoned replacement");
    }
    private static void ExpiryAndCancellation() {
        using var s = new Scene(30000); var update = s.Begin(LauncherPhase.Dispatching);
        s.Clock.Tick = 14000; s.Success();
        Check(update.IsCompleted && s.Native.Visible?.State == "Opening BYOND", "fresh dispatch was rejected");
        s.Clock.Tick = 14999; s.Client.PumpOnce(); Check(s.Native.Clears == 0, "dispatch expired early");
        s.Clock.Tick = 15000; s.Client.PumpOnce();
        Check(s.Native.Clears == 1 && s.Native.Visible == null, "original monotonic expiry was extended by callback time");
        s.Client.PumpOnce(); Check(s.Native.Clears == 1, "expired presence clear repeated automatically");
        s.Client.AdvanceGeneration(2); using var cancel = new CancellationTokenSource();
        var pending = s.Client.UpdateAsync(s.Frame(2), cancel.Token); cancel.Cancel(); s.Client.PumpOnce();
        Check(pending.IsCompleted && s.Native.Publications.Count == 1, "cancelled pending work published");
        using var inFlightCancel = new CancellationTokenSource();
        var inFlight = s.Client.UpdateAsync(s.Frame(2, 2), inFlightCancel.Token); s.Client.PumpOnce();
        inFlightCancel.Cancel(); s.Client.PumpOnce();
        Check(inFlight.IsCompleted && s.Client.Snapshot.InFlight && s.Native.Clears == 1, "logical cancellation abandoned the in-flight native call");
        s.Success(1); Check(s.Native.Clears == 2 && s.Native.Visible == null, "late cancelled publication remained visible");
        s.Client.AdvanceGeneration(3);
        var stale = s.Frame(3, phase: LauncherPhase.Dispatching); s.Clock.Tick += 15000;
        Check(s.Client.UpdateAsync(stale, CancellationToken.None).IsCompleted, "expired input stayed pending");
        s.Client.PumpOnce(); Check(s.Native.Publications.Count == 2, "expired input reached transport");
    }
    private static void TimeoutAndFailures() {
        using (var late = new Scene(2000)) {
            var update = late.Begin(); late.Clock.Tick = 2000; late.Native.Complete(0); late.Client.PumpOnce();
            Check(update.IsCompleted && late.Client.Snapshot.Failure == PresenceAdapterFailure.CallbackTimeout,
                "a success callback observed at/after the deadline escaped timeout");
            Check(late.Native.Visible == null, "timed-out success was not followed by cleanup");
        }
        using (var s = new Scene(2000)) {
            var update = s.Begin(); s.Clock.Tick = 1999; s.Client.PumpOnce();
            Check(!update.IsCompleted && s.Native.Disposals == 0, "callback timed out early");
            s.Clock.Tick = 2000; s.Client.PumpOnce();
            Check(update.IsCompleted && s.Client.Snapshot is { State: PresenceAdapterState.Unavailable, Failure: PresenceAdapterFailure.CallbackTimeout }, "stuck callback did not degrade");
            Check(s.Native.Clears == 1 && s.Native.Disposals == 1, "timeout did not attempt bounded cleanup");
            var calls = s.Native.Calls.Count; s.Client.AdvanceGeneration(2);
            s.Client.UpdateAsync(s.Frame(2), CancellationToken.None); s.Native.Callbacks[0](PresenceTransportResult.Accepted); s.Client.PumpOnce();
            Check(s.Native.Calls.Count == calls && s.Factories == 1, "faulted adapter retried or trusted late success");
        }
        using (var s = new Scene()) {
            var update = s.Begin(); s.Clock.Tick = -1; s.Client.PumpOnce();
            Check(update.IsCompleted && s.Client.Snapshot.Failure == PresenceAdapterFailure.ClockReversed, "clock reversal continued an operation");
        }
        using (var s = new Scene()) {
            s.Factory = () => throw new FileNotFoundException("Mock missing approved package; no file was opened.");
            var update = s.Begin();
            Check(update.IsCompleted && s.Client.Snapshot.Failure == PresenceAdapterFailure.TransportUnavailable, "missing binding escaped to gameplay caller");
            Check(s.Native.Calls.Count == 0, "missing binding caused transport calls");
        }
        foreach (var failAt in new[] { "publish", "pump", "clear", "dispose" }) {
            using var s = new Scene();
            if (failAt == "publish") s.Native.ThrowAt = failAt;
            var update = s.Begin();
            if (failAt == "pump") { s.Native.ThrowAt = failAt; s.Client.PumpOnce(); }
            if (failAt is "clear" or "dispose") {
                s.Success(); s.Native.ThrowAt = failAt;
                s.Client.ClearAsync(1, CancellationToken.None); s.Client.PumpOnce();
            }
            Check(update.IsCompleted && s.Client.Snapshot.Failure == PresenceAdapterFailure.TransportFailed, "transport " + failAt + " escaped/degraded incorrectly");
            Check(s.Native.Disposals == 1, "dispose retried after failure");
            if (failAt == "clear") Check(s.Native.Clears == 1, "uncertain clear was automatically retried");
        }
        foreach (var result in new[] { PresenceTransportResult.Unavailable, PresenceTransportResult.Failed, (PresenceTransportResult)0 }) {
            using var s = new Scene(); var update = s.Begin(); s.Native.Complete(0, result); s.Client.PumpOnce();
            Check(update.IsCompleted && s.Client.Snapshot.State == PresenceAdapterState.Unavailable, "failed/unknown completion reported publication");
        }
    }
    private static void ReentrancyAndStop() {
        using (var s = new Scene()) {
            s.Factory = () => { s.Client.AdvanceGeneration(2); return s.Native; };
            var update = s.Begin();
            Check(update.IsCompleted && s.Native.Publications.Count == 0, "factory reentry dispatched an obsolete frame");
        }
        using (var s = new Scene()) {
            s.Native.OnPublish = () => { s.Client.AdvanceGeneration(2); s.Client.ClearAsync(2, CancellationToken.None); };
            var update = s.Begin(); s.Client.PumpOnce();
            Check(update.IsCompleted && s.Native.Clears == 0, "producer reentry performed cross-thread cleanup");
            s.Success(); Check(s.Native.Clears == 1 && s.Native.Disposals == 1, "reentrant disable lost old-operation cleanup");
        }
        using (var s = new Scene()) {
            var update = s.Begin(); s.Success();
            s.Native.OnClear = () => { s.Native.OnClear = null; s.Client.AdvanceGeneration(2); s.Client.UpdateAsync(s.Frame(2), CancellationToken.None); };
            s.Client.ClearAsync(1, CancellationToken.None); s.Client.PumpOnce();
            Check(s.Native.Publications.Count == 2 && s.Native.Disposals == 0, "late old clear disposed the newly admitted session");
            s.Success(1); Check(s.Client.Snapshot.State == PresenceAdapterState.Accepted, "new session did not survive clear reentry");
        }
        using (var s = new Scene()) {
            var update = s.Begin(); var stop = s.Client.StopAsync();
            Check(!stop.IsCompleted && ReferenceEquals(stop, s.Client.StopAsync()), "stop abandoned or multiplied in-flight work");
            Check(s.Client.UpdateAsync(s.Frame(revision: 2), CancellationToken.None).IsCompleted, "stop accepted new work");
            s.Success();
            Check(update.IsCompleted && stop.IsCompleted && s.Client.Snapshot.State == PresenceAdapterState.Disposed, "stop did not settle");
            Check(s.Native.Calls.TakeLast(2).SequenceEqual(new[] { "clear", "dispose" }), "stop did not clear before disposal");
            var count = s.Native.Calls.Count; s.Client.PumpOnce(); Check(s.Native.Calls.Count == count, "disposed adapter called transport");
        }
        using (var s = new Scene()) {
            s.Native.OnPublish = s.Client.PumpOnce;
            var update = s.Begin();
            Check(update.IsCompleted && s.Client.Snapshot.State == PresenceAdapterState.Unavailable, "reentrant pump was allowed");
        }
    }
    private static void ThreadOwnership() {
        using var s = new Scene(); s.Client.PumpOnce();
        Exception? rejected = null;
        var wrong = new Thread(() => { try { s.Client.PumpOnce(); } catch (InvalidOperationException e) { rejected = e; } });
        wrong.Start(); wrong.Join();
        Check(rejected != null && s.Factories == 0, "pump thread ownership was not enforced before native work");
        s.Client.AdvanceGeneration(1); Task? update = null;
        var producer = new Thread(() => update = s.Client.UpdateAsync(s.Frame(), CancellationToken.None));
        producer.Start(); producer.Join();
        Check(update != null && s.Native.Calls.Count == 0, "producer thread called transport");
        s.Client.PumpOnce();
        var callback = new Thread(() => s.Native.Complete(0)); callback.Start(); callback.Join();
        s.Client.PumpOnce();
        Check(update!.IsCompleted && s.Native.Threads.All(id => id == Environment.CurrentManagedThreadId), "transport or completion escaped serial pump");
    }
    public static int Run() {
        checks = 0;
        DisabledAndMapping(); CoalescingAndGenerations(); ExpiryAndCancellation();
        TimeoutAndFailures(); ReentrancyAndStop(); ThreadOwnership();
        return checks;
    }
}
