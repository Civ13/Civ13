using Civ13.Launcher;
using Civ13.Launcher.Social;

internal static class WindowsProviderTests {
    private static int assertions;
    private static void Check(bool value, string message) { assertions++; if (!value) throw new InvalidOperationException(message); }
    private static CompanionExecutable Image() => new("C:\\approved\\companion.exe", new string('a', 64));
    private static CompanionLaunchTicket Ticket(int n = 1) => new(new Guid(n, 0, 0, new byte[8]), new(ServerCatalog.Candidates("Civ13.com")[0], "42"));
    private static void Fault(Task task, string message) {
        Check(task.IsCompleted, "Unexpected real asynchronous work in injected test.");
        try { task.GetAwaiter().GetResult(); throw new Exception(message); } catch (Exception e) when (e is IOException or InvalidOperationException or ArgumentException or OperationCanceledException) { assertions++; }
    }
    private sealed class ImageGuard(List<string> events, bool fail) : IDisposable {
        internal int Closes;
        public void Dispose() { Closes++; events.Add("image-close"); if (fail) throw new IOException("Injected image close."); }
    }
    private sealed class Pipes(List<string> events) : ICompanionPipePair {
        internal readonly MemoryStream Input = new(), Output = new();
        internal bool IsReady = true, FailClose, FailChildClose, IsClosed;
        internal int Closes, ChildCloses;
        public bool Ready => IsReady;
        public Stream FromChild => Input;
        public Stream ToChild => Output;
        public bool Closed => IsClosed;
        public void CloseChildEnds() { ChildCloses++; events.Add("child-ends-close"); if (FailChildClose) throw new IOException("Injected child handles."); }
        public void Dispose() { if (Closes != 0) return; Closes++; events.Add("pipes-close"); Input.Dispose(); Output.Dispose(); if (FailClose || FailChildClose) throw new IOException("Injected pipe close."); IsClosed = true; }
    }
    private sealed class Child(List<string> events) : ICompanionOwnedChild {
        internal bool Exited, FailResume, FailTerminate, FailClose, SettleOnKill, CloseWithoutProof;
        internal int Resumes, Kills, Closes;
        internal Action? BeforeResume;
        public bool HasExited => Exited;
        public bool Closed { get; private set; }
        public void ContainAndResume(CancellationToken cancellation) { Resumes++; events.Add("contain-resume"); BeforeResume?.Invoke(); cancellation.ThrowIfCancellationRequested(); if (FailResume) throw new IOException("Injected containment."); }
        public void Terminate() { Kills++; events.Add("terminate"); if (FailTerminate) throw new IOException("Injected termination."); if (SettleOnKill) Exited = true; }
        public void Dispose() { Closes++; events.Add("process-close"); Check(Exited, "Live process handles disposed."); if (FailClose) throw new IOException("Injected process close."); Closed = !CloseWithoutProof; }
    }
    private sealed class Platform : ICompanionWindowsPlatform {
        internal readonly List<string> Events = [];
        internal Pipes Pipes;
        internal Child Child;
        internal ImageGuard? Guard;
        internal bool FailVerify, FailCreate, FailImageClose;
        internal Action? DuringPipes, DuringCreate;
        internal TaskCompletionSource<ICompanionPipePair>? PendingPipes;
        internal Task<ICompanionProcessLease>? LastStart;
        internal Platform() { Pipes = new(Events); Child = new(Events); }
        public IDisposable LockVerifiedImage(CompanionExecutable image) {
            Events.Add("verify-lock"); if (FailVerify) throw new IOException("Injected identity failure."); Guard = new(Events, FailImageClose); return Guard;
        }
        public Task<ICompanionPipePair> CreatePipesAsync(CancellationToken cancellation) {
            Events.Add("pipes-connect"); DuringPipes?.Invoke(); return PendingPipes?.Task ?? Task.FromResult<ICompanionPipePair>(Pipes);
        }
        public ICompanionOwnedChild CreateSuspended(CompanionExecutable image, CompanionLaunchTicket ticket, ICompanionPipePair pipes) {
            Check(ReferenceEquals(pipes, Pipes), "Different pipe capability reached spawn."); Events.Add("create-suspended"); DuringCreate?.Invoke(); if (FailCreate) throw new IOException("Injected create failure."); return Child;
        }
        internal WindowsCompanionFactory Factory() => new(Image(), TimeProvider.System, this, true, work => LastStart = work());
    }
    private static void SchemaAndDisabled() {
        foreach (var path in new[] { "https://example/x.exe", "\\\\server\\x.exe", "C:\\x.exe --token value", "C:\\a\\..\\x.exe", "C:\\x.exe:stream", "C:\\x%TEMP%.exe", "C:\\x\".exe" }) {
            try { _ = new CompanionExecutable(path, new string('a', 64)); throw new Exception("Unsafe image path accepted."); } catch (ArgumentException) { assertions++; }
        }
        try { _ = new CompanionExecutable("C:\\x.exe", "not-a-hash"); throw new Exception("Bad hash accepted."); } catch (ArgumentException) { assertions++; }
        var plan = CompanionLaunchPlan.Create(Image(), Ticket(), "C:\\Windows", "C:\\private-temp");
        Check(plan.CommandLine == "\"C:\\approved\\companion.exe\" --social-peer-v1 Civ13.com 1714 42", "Command plan changed public profile fields.");
        Check(!plan.CommandLine.Contains(Ticket().Session.ToString(), StringComparison.OrdinalIgnoreCase), "Launch ticket exposed in arguments.");
        Check(plan.EnvironmentBlock == "SystemRoot=C:\\Windows\0TEMP=C:\\private-temp\0TMP=C:\\private-temp\0WINDIR=C:\\Windows\0\0", "Environment was not a strict allowlist.");
        Check(!plan.EnvironmentBlock.Contains("PATH=") && !plan.EnvironmentBlock.Contains("TOKEN="), "Parent environment leaked.");
        Check(WindowsCompanionPlatform.Layout == (112, 24, 144, 24), "Windows x64 interop layout mismatch.");
        var disabled = new WindowsCompanionFactory(Image(), TimeProvider.System);
        Fault(disabled.StartAsync(Ticket(), CancellationToken.None), "Public OS factory enabled.");
        // Every concrete OS entry point refuses before file/process/pipe APIs.
        var os = new WindowsCompanionPlatform();
        try { os.LockVerifiedImage(Image()); throw new Exception("Native image inspection enabled."); } catch (InvalidOperationException) { assertions++; }
        Fault(os.CreatePipesAsync(CancellationToken.None), "Native pipe creation enabled.");
        try { os.CreateSuspended(Image(), Ticket(), new Platform().Pipes); throw new Exception("Native process creation enabled."); } catch (InvalidOperationException) { assertions++; }
    }
    private static void SuccessAndOwnership() {
        var os = new Platform(); var factory = os.Factory();
        var lease = factory.StartAsync(Ticket(), CancellationToken.None).GetAwaiter().GetResult();
        Check(os.Events.SequenceEqual(new[] { "verify-lock", "pipes-connect", "create-suspended", "contain-resume", "child-ends-close", "image-close" }), "Suspended ownership/resume ordering changed.");
        Check(lease.Session == Ticket().Session && lease.WireVersion == 1 && lease.Channel.IsOpen, "Valid lease not exposed.");
        Fault(factory.StartAsync(Ticket(2), CancellationToken.None), "Concurrent child was launched.");
        Check(os.Child.Resumes == 1 && os.Pipes.Output.Length == 0, "Factory launched twice or synthesized Hello.");
        var stop = CompanionWire.Encode(CompanionOp.Stop, 1, []);
        Check(lease.Channel.TryWrite(stop) && os.Pipes.Output.ToArray().SequenceEqual(stop), "Provider framing changed bytes.");
        lease.RequestStop(); lease.RequestStop(); Check(!lease.Channel.IsOpen && os.Pipes.Closes == 1, "Cooperative stop was not idempotent.");
        Check(!lease.ResourcesSettled, "Live child was declared settled.");
        try { lease.Dispose(); throw new Exception("Disposed a live child."); } catch (InvalidOperationException) { assertions++; }
        lease.RequestTermination(); lease.RequestTermination(); Check(os.Child.Kills == 1, "Owned kill request repeated.");
        os.Child.Exited = true; Check(lease.ResourcesSettled, "Exited child and closed I/O stayed held."); lease.Dispose(); lease.Dispose();
        Check(os.Child.Closes == 1, "Owned process handles closed twice.");
        Fault(factory.StartAsync(Ticket(2), new CancellationToken(true)), "Precancelled attempt created work.");
        Check(os.Events.Count(x => x == "create-suspended") == 1, "Precancelled launch reached OS.");
        os.Pipes = new(os.Events); os.Child = new(os.Events);
        var fresh = factory.StartAsync(Ticket(2), CancellationToken.None).GetAwaiter().GetResult();
        Check(fresh.Session != lease.Session && os.Events.Count(x => x == "create-suspended") == 2, "Explicit reconnect did not create fresh owned resources.");
        fresh.RequestStop(); os.Child.Exited = true; fresh.Dispose();
    }
    private static void FailureStages() {
        for (var stage = 0; stage < 7; stage++) {
            var os = new Platform(); var factory = os.Factory();
            os.FailVerify = stage == 0; os.Pipes.IsReady = stage != 1; os.FailCreate = stage == 2;
            os.Child.FailResume = stage == 3; os.Pipes.FailChildClose = stage == 4; os.FailImageClose = stage == 5;
            os.Child.FailTerminate = stage == 6; if (stage == 6) os.Child.FailResume = true;
            var pending = factory.StartAsync(Ticket(), CancellationToken.None);
            if (stage < 3) {
                Fault(pending, "Pre-child failure was not reported after cleanup.");
                Check(os.Child.Resumes == 0 && os.Child.Kills == 0, "Pre-child failure mutated a process.");
            } else {
                var lease = pending.GetAwaiter().GetResult();
                Check(!lease.Channel.IsOpen && !lease.ResourcesSettled && os.Child.Kills == 1, "Post-create failure hid its live resource.");
                Fault(factory.StartAsync(Ticket(2), CancellationToken.None), "Retry overlapped failed live child.");
                os.Child.Exited = true;
                if (stage is 4 or 5 or 6) Check(!lease.ResourcesSettled, "Unknown close/termination outcome lost quarantine.");
                else { Check(lease.ResourcesSettled, "Known cleanup did not settle."); lease.Dispose(); }
            }
        }
        foreach (var processClose in new[] { false, true }) {
            var os = new Platform(); os.Child.FailClose = processClose; os.Pipes.FailClose = !processClose; var factory = os.Factory();
            var lease = factory.StartAsync(Ticket(), CancellationToken.None).GetAwaiter().GetResult(); lease.RequestStop(); os.Child.Exited = true;
            if (processClose) { try { lease.Dispose(); throw new Exception("Process close failure ignored."); } catch (IOException) { assertions++; } }
            Check(!lease.ResourcesSettled, "Unknown cleanup was called settled.");
            Fault(factory.StartAsync(Ticket(2), CancellationToken.None), "Unknown cleanup allowed reconnect.");
        }
        {
            var os = new Platform(); os.Child.CloseWithoutProof = true; var factory = os.Factory();
            var lease = factory.StartAsync(Ticket(), CancellationToken.None).GetAwaiter().GetResult(); lease.RequestStop(); os.Child.Exited = true;
            try { lease.Dispose(); throw new Exception("Missing handle proof accepted."); } catch (IOException) { assertions++; }
            Check(!lease.ResourcesSettled, "Unproven handle release became settled."); Fault(factory.StartAsync(Ticket(2), CancellationToken.None), "Missing close proof released factory admission.");
        }
        {
            // The platform can return pre-process ownership (job/stderr handles)
            // after failed creation. A failed close still retains admission.
            var os = new Platform(); os.Child.Exited = true; os.Child.FailResume = true; os.Child.CloseWithoutProof = true; var factory = os.Factory();
            Fault(factory.StartAsync(Ticket(), CancellationToken.None), "Partial handle ownership was accepted.");
            Check(os.Child.Closes == 1 && os.Child.Kills == 0, "Pre-process handles were hidden or terminated as a child.");
            Fault(factory.StartAsync(Ticket(2), CancellationToken.None), "Unproven pre-process cleanup released admission.");
        }
    }
    private static void CancellationAndHost() {
        foreach (var afterCreate in new[] { false, true }) {
            var os = new Platform(); using var cancel = new CancellationTokenSource();
            if (afterCreate) os.DuringCreate = cancel.Cancel; else os.DuringPipes = cancel.Cancel;
            var task = os.Factory().StartAsync(Ticket(), cancel.Token);
            if (afterCreate) { var lease = task.GetAwaiter().GetResult(); Check(os.Child.Resumes == 0 && os.Child.Kills == 1 && !lease.Channel.IsOpen, "Cancelled suspended child resumed or was lost."); os.Child.Exited = true; lease.Dispose(); }
            else { Fault(task, "Cancelled pipe stage created a child."); Check(!os.Events.Contains("create-suspended"), "Cancellation before create was ignored."); }
        }
        {
            var os = new Platform(); os.Child.FailResume = true; os.Child.SettleOnKill = true;
            Fault(os.Factory().StartAsync(Ticket(), CancellationToken.None), "Known killed child did not finish pre-fault cleanup.");
            Check(os.Child.Closes == 1 && os.Child.Kills == 1, "Immediate exit proof did not release owned handles.");
        }
        {
            var os = new Platform(); using var cancel = new CancellationTokenSource(); os.Child.BeforeResume = cancel.Cancel;
            var lease = os.Factory().StartAsync(Ticket(), cancel.Token).GetAwaiter().GetResult();
            Check(os.Child.Kills == 1 && !lease.Channel.IsOpen, "Cancellation at resume boundary lost its owned child."); os.Child.Exited = true; lease.Dispose();
        }
        var delayed = new Platform { PendingPipes = new(TaskCreationOptions.RunContinuationsAsynchronously) };
        var clock = new TestClock(); var factory = delayed.Factory(); var host = new CompanionProcessHost(Ticket().Profile, factory, clock, () => Ticket().Session);
        host.SetEnabled(true); Check(host.Begin(), "Host did not begin injected provider."); clock.Now = 3000; host.Pump();
        Check(host.Failure == CompanionHostFailure.StartTimeout && !host.IsSettled && !host.Begin(), "Host lost delayed provider ownership.");
        delayed.PendingPipes.SetResult(delayed.Pipes);
        // Asynchronous continuation may settle on the pool; bounded wait only on
        // fake work, no OS/API calls or real-time timeout is used for semantics.
        Check(SpinWait.SpinUntil(() => delayed.LastStart!.IsCompleted, 1000), "Injected cleanup did not finish.");
        host.Pump(); Check(host.IsSettled && !delayed.Events.Contains("create-suspended"), "Late cancelled provider created a process.");
        Func<Task<ICompanionProcessLease>>? work = null;
        var scheduled = new TaskCompletionSource<ICompanionProcessLease>(); var fake = new Platform();
        var queued = new WindowsCompanionFactory(Image(), clock, fake, true, run => { work = run; return scheduled.Task; });
        using var cancelled = new CancellationTokenSource(); var admission = queued.StartAsync(Ticket(), cancelled.Token);
        Check(fake.Events.Count == 0, "Image hashing ran on admission thread."); cancelled.Cancel(); Fault(work!(), "Cancelled queued startup was not cleaned.");
        Check(fake.Events.Count == 0, "Cancelled queued startup inspected an image.");
        scheduled.SetException(new IOException("Injected scheduler propagated cleanup.")); Fault(admission, "Queued failure did not settle.");
    }
    private sealed class TestClock : TimeProvider { internal long Now; public override long TimestampFrequency => 1000; public override long GetTimestamp() => Now; }
    internal static int Run() { assertions = 0; SchemaAndDisabled(); SuccessAndOwnership(); FailureStages(); CancellationAndHost(); return assertions; }
}
