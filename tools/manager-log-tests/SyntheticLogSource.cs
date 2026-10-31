using System.Text;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

sealed class FakeSource : IRegisteredLogSource {
    public byte[] Bytes { get; set; } = [];
    public string Generation { get; set; } = "generation-a";
    public string? GenerationOnSecondCapture { get; set; }
    public long? LengthOnSecondCapture { get; set; }
    public int ChunkLimit { get; set; } = int.MaxValue;
    public int Opens { get; set; }
    public int Sessions { get; set; }
    public int Disposals { get; set; }
    public Exception? OpenError { get; set; }
    public Exception? ReadError { get; set; }
    public bool WrongStamp { get; set; }
    public bool BadRead { get; set; }
    public bool AllowAnyStream { get; set; }
    public Action? OnRead { get; set; }
    public void Set(string text) => Bytes = Encoding.UTF8.GetBytes(text);
    public IRegisteredLogSession Open(InstanceBinding binding, string streamId) {
        Opens++; if (OpenError is not null) throw OpenError;
        if (!AllowAnyStream && streamId != "world-log") throw new NotSupportedException();
        Sessions++;
        return new FakeSession(this, binding, streamId);
    }
    private sealed class FakeSession(FakeSource owner, InstanceBinding binding, string streamId) : IRegisteredLogSession {
        private int captures;
        public LogSourceStamp Capture() {
            captures++;
            return new(owner.WrongStamp ? binding with { HostId = "other" } : binding, streamId,
                captures > 1 && owner.GenerationOnSecondCapture is not null ? owner.GenerationOnSecondCapture : owner.Generation,
                captures > 1 && owner.LengthOnSecondCapture is not null ? owner.LengthOnSecondCapture.Value : owner.Bytes.Length);
        }
        public int Read(long offset, byte[] destination, int destinationOffset, int count) {
            owner.OnRead?.Invoke(); if (owner.ReadError is not null) throw owner.ReadError;
            if (owner.BadRead) return count + 1;
            var available = Math.Min(owner.ChunkLimit, Math.Min(count, owner.Bytes.Length - checked((int)offset)));
            Array.Copy(owner.Bytes, checked((int)offset), destination, destinationOffset, available); return available;
        }
        public void Dispose() => owner.Disposals++;
    }
}
