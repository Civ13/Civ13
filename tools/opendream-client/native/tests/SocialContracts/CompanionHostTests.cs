using Civ13.Launcher;
using Civ13.Launcher.Social;

internal static class CompanionHostTests {
    private static int assertions;
    private static void Check(bool value, string message) { assertions++; if (!value) throw new InvalidOperationException(message); }
    private sealed class Clock : TimeProvider {
        internal long Now;
        public override long TimestampFrequency => 1000;
        public override long GetTimestamp() => Now;
    }
    private sealed class Io(bool readable) : Stream {
        internal int Reads, Writes, Disposals;
        internal Memory<byte> ReadBuffer;
        internal ReadOnlyMemory<byte> WriteBuffer { get; private set; }
        internal TaskCompletionSource<int>? ReadTask;
        internal TaskCompletionSource? WriteTask;
        internal bool ThrowWrite, ThrowDispose;
        public override bool CanRead => readable;
        public override bool CanWrite => !readable;
        public override bool CanSeek => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellation = default) {
            Reads++; ReadBuffer = buffer; ReadTask = new(TaskCreationOptions.RunContinuationsAsynchronously); return new(ReadTask.Task);
        }
        public override ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellation = default) {
            Writes++; WriteBuffer = buffer;
            if (ThrowWrite) throw new IOException("Injected write failure.");
            WriteTask = new(TaskCreationOptions.RunContinuationsAsynchronously); return new(WriteTask.Task);
        }
        internal void Deliver(byte[] bytes) { bytes.CopyTo(ReadBuffer); ReadTask!.SetResult(bytes.Length); }
        protected override void Dispose(bool disposing) { if (disposing) { Disposals++; if (ThrowDispose) throw new IOException("Injected stream close."); } }
        public override void Flush() => throw new InvalidOperationException("No synchronous I/O.");
        public override int Read(byte[] b, int o, int c) => throw new InvalidOperationException("No synchronous I/O.");
        public override void Write(byte[] b, int o, int c) => throw new InvalidOperationException("No synchronous I/O.");
        public override long Seek(long o, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
    }
    private sealed class Channel : ICompanionPresenceChannel {
        internal bool Open = true;
        internal int Writes, Disposals;
        public bool IsOpen => Open;
        public bool TryWrite(ReadOnlySpan<byte> frame) { if (!Open) return false; Writes++; return true; }
        public int Read(Span<byte> output) => 0;
        public void Dispose() { if (Open) { Open = false; Disposals++; } }
    }
    private sealed class Child(Guid id, ICompanionPresenceChannel channel) : ICompanionProcessLease {
        public Guid Session { get; } = id;
        public int WireVersion { get; init; } = 1;
        public ICompanionPresenceChannel Channel { get; } = channel;
        public bool HasExited { get; set; }
        internal bool Settled, ThrowStop, ThrowTerminate, ThrowDispose;
        internal int Stops, Terminations, Disposals;
        public bool ResourcesSettled => Settled && (Channel is not BoundedStreamCompanionChannel io || io.IsSettled);
        public void RequestStop() { Stops++; Channel.Dispose(); if (ThrowStop) throw new IOException("Injected stop."); }
        public void RequestTermination() { Terminations++; if (ThrowTerminate) throw new IOException("Injected terminate."); }
        public void Dispose() { Disposals++; if (ThrowDispose) throw new IOException("Injected disposal."); Channel.Dispose(); }
    }
    private sealed class Factory : ICompanionProcessFactory {
        internal int Starts;
        internal CompanionLaunchTicket? Ticket;
        internal CancellationToken Token;
        internal TaskCompletionSource<ICompanionProcessLease> Task = Pending();
        internal bool Throw;
        internal static TaskCompletionSource<ICompanionProcessLease> Pending() => new(TaskCreationOptions.RunContinuationsAsynchronously);
        public Task<ICompanionProcessLease> StartAsync(CompanionLaunchTicket ticket, CancellationToken token) {
            Starts++; Ticket = ticket; Token = token; if (Throw) throw new IOException("Injected start."); return Task.Task;
        }
    }
    private static CompanionProfile Profile() => new(ServerCatalog.Candidates("Civ13.com")[0], "42");
    private static CompanionProcessHost Host(Factory factory, Clock clock) {
        var next = 0;
        return new(Profile(), factory, clock, () => new Guid(++next, 0, 0, new byte[8]));
    }
    private static byte[] Frame(CompanionOp op, ulong id = 1) => CompanionWire.Encode(op, id, []);
    private static void Channels() {
        var clock = new Clock(); var input = new Io(true); var output = new Io(false);
        var channel = new BoundedStreamCompanionChannel(input, output, clock);
        Check(input.Reads == 0 && output.Writes == 0, "Channel construction performed I/O.");
        var bytes = Frame(CompanionOp.Stop);
        Check(channel.TryWrite(bytes), "Whole frame not admitted."); bytes[0] = 0;
        Check(output.WriteBuffer.Span[0] == (byte)'C', "Caller mutation changed admitted bytes.");
        Check(!channel.TryWrite(Frame(CompanionOp.Pulse, 2)) && output.Writes == 1, "Backpressure admitted a second frame.");
        clock.Now = 249; Check(channel.IsOpen, "Write deadline was premature."); output.WriteTask!.SetResult();
        Check(channel.TryWrite(Frame(CompanionOp.Pulse, 2)) && output.Writes == 2, "Settled slot was not reusable.");
        var sink = new byte[20];
        for (var n = 0; n < 100; n++) Check(channel.Read(sink) == 0, "Idle input fabricated bytes.");
        Check(input.Reads == 1, "Idle polls allocated additional reads.");
        var ready = CompanionWire.Encode(CompanionOp.Ready, 1, CompanionWire.Profile(Profile()));
        input.Deliver(ready);
        Check(channel.Read(sink) == 20 && sink.AsSpan().SequenceEqual(ready.AsSpan(0, 20)), "Header delivery changed bytes.");
        var rest = new byte[276]; var count = channel.Read(rest);
        Check(rest.AsSpan(0, count).SequenceEqual(ready.AsSpan(20)) && input.Reads == 1, "Fragmented payload was lost or overread.");
        channel.Dispose(); Check(!channel.IsOpen && !channel.IsSettled, "Closed pending write was called settled.");
        output.WriteTask!.SetResult(); Check(channel.IsSettled, "Late write did not settle the old channel.");
        channel.Dispose(); Check(input.Disposals == 1 && output.Disposals == 1, "Stream close repeated.");

        foreach (var kind in new[] { 0, 1, 2, 3 }) {
            clock = new(); input = new(true); output = new(false); channel = new(input, output, clock);
            Check(channel.TryWrite(Frame(CompanionOp.Stop)), "Write admission failed.");
            if (kind == 0) { clock.Now = 250; }
            if (kind == 1) { output.WriteTask!.SetResult(); clock.Now = 250; }
            if (kind == 2) output.WriteTask!.SetException(new IOException("Injected async failure."));
            if (kind == 3) clock.Now = -1;
            Check(!channel.IsOpen && !channel.TryWrite(Frame(CompanionOp.Stop, 2)) && output.Writes == 1, "Failure/deadline allowed replay.");
            output.WriteTask!.TrySetResult(); Check(channel.IsSettled, "Closed write stayed unsettled after completion.");
        }
        clock = new(); input = new(true); output = new(false) { ThrowWrite = true }; channel = new(input, output, clock);
        Check(channel.TryWrite(Frame(CompanionOp.Stop)) && !channel.IsOpen && output.Writes == 1, "Attempted synchronous failure was retryable.");
        foreach (var countValue in new[] { 0, 277, -1 }) {
            input = new(true); output = new(false); channel = new(input, output, clock); channel.Read(sink);
            input.ReadTask!.SetResult(countValue); Check(channel.Read(sink) == 0 && !channel.IsOpen, "Invalid read/EOF remained open.");
        }
        input = new(true); output = new(false); channel = new(input, output, clock);
        var malformed = Frame(CompanionOp.Stop); malformed[4] = 2;
        try { channel.TryWrite(malformed); throw new Exception("Bad header accepted."); } catch (FormatException) { assertions++; }
        Check(output.Writes == 0, "Invalid outgoing header reached stream."); channel.Dispose();
        input = new(true); output = new(false); channel = new(input, output, clock); channel.Read(sink);
        input.ReadTask!.SetException(new IOException("Injected async read failure."));
        Check(channel.Read(sink) == 0 && !channel.IsOpen && channel.IsSettled, "Read fault was not terminal and observed.");
        input = new(true) { ThrowDispose = true }; output = new(false); channel = new(input, output, clock);
        channel.Dispose(); channel.Dispose(); Check(!channel.IsSettled && input.Disposals == 1 && output.Disposals == 1, "Unknown stream close was replayed or declared settled.");
    }
    private static void Startup() {
        var clock = new Clock(); var factory = new Factory(); var host = Host(factory, clock);
        Check(!host.Begin() && factory.Starts == 0, "Default-disabled host launched.");
        host.SetEnabled(true); Check(factory.Starts == 0, "Enabling launched a child.");
        Check(!host.Begin(new CancellationToken(true)) && factory.Starts == 0, "Precancelled launch ran.");
        Check(host.Begin() && !host.Begin() && factory.Starts == 1, "Repeated startup overlapped.");
        var child = new Child(factory.Ticket!.Session, new Channel()); factory.Task.SetResult(child); host.Pump();
        Check(host.State == CompanionHostState.Running && host.Channel == child.Channel, "Valid child not adopted.");
        Check(!host.Begin() && factory.Starts == 1 && ((Channel)child.Channel).Writes == 0, "Running host relaunched or sent a handshake itself.");
        host.Stop(); host.Stop(); host.Pump(); Check(child.Stops == 1 && host.Channel == null, "Stop repeated or exposed closing channel.");
        clock.Now = 750; host.Pump(); host.Pump(); Check(child.Terminations == 1 && host.State == CompanionHostState.Quarantined, "Shutdown deadline did not terminate exactly once.");
        Check(!host.Begin(), "Reconnect overlapped old resources."); child.HasExited = child.Settled = true; host.Pump();
        Check(host.IsSettled && child.Disposals == 1, "Exited child was not reaped.");
        factory.Task = Factory.Pending(); var old = factory.Ticket.Session;
        Check(host.Begin() && factory.Starts == 2 && factory.Ticket!.Session != old, "Explicit reconnect reused a launch ticket.");
        host.SetEnabled(false); var late = new Child(factory.Ticket!.Session, new Channel()) { HasExited = true, Settled = true };
        factory.Task.SetResult(late); host.Pump(); Check(host.IsSettled && host.State == CompanionHostState.Disabled && late.Stops == 1, "Late launch after opt-out escaped cleanup.");

        foreach (var wrongVersion in new[] { false, true }) {
            clock = new(); factory = new(); host = Host(factory, clock); host.SetEnabled(true); host.Begin();
            child = new(wrongVersion ? factory.Ticket!.Session : Guid.NewGuid(), new Channel()) { WireVersion = wrongVersion ? 2 : 1, HasExited = true, Settled = true };
            factory.Task.SetResult(child); host.Pump(); Check(host.Failure == CompanionHostFailure.WrongPeer && host.Channel == null && child.Stops == 1 && child.Disposals == 1, "Wrong peer/version was exposed.");
        }
        factory = new() { Throw = true }; host = Host(factory, new()); host.SetEnabled(true);
        Check(!host.Begin() && host.IsSettled && host.Failure == CompanionHostFailure.StartFailed, "Synchronous failure held a resource.");
        factory = new(); host = Host(factory, new()); host.SetEnabled(true); host.Begin(); factory.Task.SetException(new IOException("Injected factory fault.")); host.Pump();
        Check(host.IsSettled && host.Failure == CompanionHostFailure.StartFailed, "Faulted startup did not settle.");
    }
    private static void CancellationAndQuiescence() {
        var clock = new Clock(); var factory = new Factory(); var host = Host(factory, clock); host.SetEnabled(true); host.Begin();
        clock.Now = 3000; host.Pump();
        Check(factory.Token.IsCancellationRequested && !host.IsSettled && !host.Begin() && host.Failure == CompanionHostFailure.StartTimeout, "Startup timeout abandoned or retried uncertain work.");
        var child = new Child(factory.Ticket!.Session, new Channel()) { Settled = true, HasExited = true }; factory.Task.SetResult(child); host.Pump();
        Check(host.IsSettled && child.Stops == 1 && child.Disposals == 1, "Timed-out late child leaked.");
        using var cancelled = new CancellationTokenSource(); factory = new(); host = Host(factory, new()); host.SetEnabled(true); host.Begin(cancelled.Token); cancelled.Cancel(); host.Pump();
        Check(factory.Token.IsCancellationRequested && !host.IsSettled && host.Failure == CompanionHostFailure.Cancelled, "External cancellation was lost.");
        child = new(factory.Ticket!.Session, new Channel()) { Settled = true, HasExited = true }; factory.Task.SetResult(child); host.Pump(); Check(host.IsSettled, "Cancelled late startup did not reap.");

        clock = new(); var input = new Io(true); var output = new Io(false); var channel = new BoundedStreamCompanionChannel(input, output, clock);
        channel.Read(new byte[20]); channel.TryWrite(Frame(CompanionOp.Stop));
        factory = new(); host = Host(factory, clock); host.SetEnabled(true); host.Begin(); child = new(factory.Ticket!.Session, channel); factory.Task.SetResult(child); host.Pump();
        host.Stop(); host.Pump(); child.HasExited = child.Settled = true; clock.Now = 750; host.Pump();
        Check(!host.IsSettled && !host.Begin() && child.Terminations == 0, "Dead process allowed overlap with pending I/O or was killed again.");
        output.WriteTask!.SetResult(); input.ReadTask!.SetResult(0); host.Pump(); Check(host.IsSettled && child.Disposals == 1, "I/O settlement did not release ownership.");
        factory.Task = Factory.Pending(); Check(host.Begin(), "Fresh explicit reconnect stayed blocked after settlement."); host.Stop();
        child = new(factory.Ticket!.Session, new Channel()) { Settled = true, HasExited = true }; factory.Task.SetResult(child); host.Pump();
    }
    private static void FailureAndWire() {
        foreach (var exited in new[] { false, true }) {
            var clock = new Clock(); var factory = new Factory(); var host = Host(factory, clock); host.SetEnabled(true); host.Begin();
            var channel = new Channel(); var child = new Child(factory.Ticket!.Session, channel); factory.Task.SetResult(child); host.Pump();
            if (exited) child.HasExited = child.Settled = true; else channel.Dispose(); host.Pump();
            Check(host.Failure == (exited ? CompanionHostFailure.Exited : CompanionHostFailure.ChannelClosed) && host.Channel == null && factory.Starts == 1, "Crash/channel failure automatically retried.");
            child.HasExited = child.Settled = true; host.Pump(); Check(host.IsSettled, "Crash/channel cleanup did not settle.");
        }
        {
            var clock = new Clock(); var factory = new Factory(); var host = Host(factory, clock); host.SetEnabled(true); host.Begin();
            var child = new Child(factory.Ticket!.Session, new Channel()) { Settled = true }; factory.Task.SetResult(child); host.Pump(); host.Stop(); host.Pump();
            Check(!host.IsSettled && child.Disposals == 0, "A live child was released on an incomplete settlement hint.");
            clock.Now = -1; host.Pump(); Check(host.Failure == CompanionHostFailure.Clock && child.Terminations == 1 && !host.Begin(), "Clock reversal left owned work reusable.");
            child.HasExited = true; host.Pump(); Check(host.IsSettled, "Clock-failed child could not finish cleanup.");
        }
        {
            var factory = new Factory() { Throw = true }; var host = new CompanionProcessHost(Profile(), factory, new Clock(), () => new Guid(1, 0, 0, new byte[8]));
            host.SetEnabled(true); host.Begin();
            try { host.Begin(); throw new Exception("Launch ticket reused."); } catch (InvalidOperationException) { assertions++; }
            Check(factory.Starts == 1, "Repeated ticket reached factory.");
        }
        foreach (var fault in new[] { 0, 1, 2 }) {
            var clock = new Clock(); var factory = new Factory(); var host = Host(factory, clock); host.SetEnabled(true); host.Begin();
            var child = new Child(factory.Ticket!.Session, new Channel()) { ThrowStop = fault == 0, ThrowTerminate = fault == 1, ThrowDispose = fault == 2 };
            factory.Task.SetResult(child); host.Pump(); host.Stop(); clock.Now = 750; host.Pump(); host.Pump();
            Check(child.Stops == 1 && child.Terminations <= 1 && !host.Begin(), "Exceptional cleanup repeated a request or reconnected.");
            child.ThrowStop = child.ThrowTerminate = false; child.Settled = child.HasExited = true; host.Pump(); host.Pump();
            if (fault == 2) Check(child.Disposals == 1 && !host.IsSettled && !host.Begin(), "Uncertain dispose was retried.");
            else Check(host.IsSettled, "Recovered terminal resources did not reap.");
        }
        foreach (var wrongVersion in new[] { false, true }) {
            var clock = new Clock(); var input = new Io(true); var output = new Io(false); var channel = new BoundedStreamCompanionChannel(input, output, clock);
            var factory = new Factory(); var host = Host(factory, clock); host.SetEnabled(true); host.Begin();
            var child = new Child(factory.Ticket!.Session, channel); factory.Task.SetResult(child); host.Pump();
            using var transport = new CompanionPresenceTransport(Profile(), channel, clock);
            PresenceTransportResult? result = null; transport.Publish(new("D", "S"), r => result = r); output.WriteTask!.SetResult();
            transport.RunCallbacks(); var payload = CompanionWire.Profile(Profile());
            if (!wrongVersion) payload[^1] = (byte)'3'; var ready = CompanionWire.Encode(CompanionOp.Ready, 1, payload); if (wrongVersion) ready[4] = 2;
            input.Deliver(ready); transport.RunCallbacks(); host.Pump();
            Check(result == PresenceTransportResult.Failed && child.Stops == 1 && host.Channel == null, "Wrong wire peer/version stayed attached to process host.");
            Check(!host.IsSettled && !host.Begin(), "Wrong-wire teardown overlapped pending output.");
            if (input.ReadTask is { Task.IsCompleted: false }) input.ReadTask.SetResult(0);
            output.WriteTask?.TrySetResult();
            child.HasExited = child.Settled = true; host.Pump(); Check(host.IsSettled, "Wrong-wire peer cleanup stayed held.");
        }
        var factoryOwner = new Factory(); var hostOwner = Host(factoryOwner, new()); var rejected = false;
        var thread = new Thread(() => { try { hostOwner.Begin(); } catch (InvalidOperationException) { rejected = true; } }); thread.Start(); thread.Join();
        Check(rejected && factoryOwner.Starts == 0, "Wrong thread started a process.");
    }
    internal static int Run() { assertions = 0; Channels(); Startup(); CancellationAndQuiescence(); FailureAndWire(); return assertions; }
}
