using Civ13.Launcher;
using System.Buffers.Binary;
using System.Text;
using System.Text.Json;

// Discord's local RPC pipe is replaced by an in-memory stream. Nothing here opens a pipe.
static class DiscordPresenceTests {
    const string Id = "123456789012345678";

    // Reads come from scripted Discord replies; writes are recorded.
    sealed class FakePipe(params string[] replies) : Stream {
        readonly MemoryStream incoming = new(Frames(replies));
        public readonly MemoryStream Written = new();
        public bool Disposed { get; private set; }
        static byte[] Frames(string[] replies) {
            var output = new MemoryStream();
            foreach (var reply in replies) output.Write(Frame(1, reply));
            return output.ToArray();
        }
        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override int Read(byte[] buffer, int offset, int count) {
            var read = incoming.Read(buffer, offset, count);
            if (read == 0 && count > 0) throw new IOException("Pipe closed.");
            return read;
        }
        public override void Write(byte[] buffer, int offset, int count) => Written.Write(buffer, offset, count);
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        protected override void Dispose(bool disposing) { Disposed = true; base.Dispose(disposing); }
    }

    static byte[] Frame(int op, string json) {
        var body = Encoding.UTF8.GetBytes(json);
        var frame = new byte[8 + body.Length];
        BinaryPrimitives.WriteInt32LittleEndian(frame, op);
        BinaryPrimitives.WriteInt32LittleEndian(frame.AsSpan(4), body.Length);
        body.CopyTo(frame, 8);
        return frame;
    }

    static List<(int Op, JsonElement Body)> Parse(byte[] bytes) {
        var frames = new List<(int, JsonElement)>();
        for (var at = 0; at < bytes.Length;) {
            var op = BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(at));
            var length = BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(at + 4));
            frames.Add((op, JsonDocument.Parse(bytes.AsMemory(at + 8, length)).RootElement.Clone()));
            at += 8 + length;
        }
        return frames;
    }

    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Discord presence contract: " + message);
        }
        const string ready = "{\"cmd\":\"DISPATCH\",\"evt\":\"READY\"}";
        const string ok = "{\"cmd\":\"SET_ACTIVITY\",\"evt\":null}";

        // Handshake, browsing, playing and clear, then a close frame on shutdown.
        var pipe = new FakePipe(ready, ok, ok, ok);
        var presence = new DiscordPresence(Id, () => pipe, 4242);
        presence.Browsing();
        var started = DateTimeOffset.FromUnixTimeSeconds(1_800_000_000);
        presence.Playing(DiscordPresence.ServerLine("NOMADS_GAIA", "civ13.com"), started);
        presence.Clear();
        presence.Dispose();
        var frames = Parse(pipe.Written.ToArray());
        Require(frames.Select(f => f.Op).SequenceEqual(new[] { 0, 1, 1, 1, 2 }), "frame order was " + string.Join(",", frames.Select(f => f.Op)));
        Require(frames[0].Body.GetProperty("v").GetInt32() == 1 && frames[0].Body.GetProperty("client_id").GetString() == Id, "handshake lacked version or application ID");
        var browsing = frames[1].Body;
        Require(browsing.GetProperty("cmd").GetString() == "SET_ACTIVITY" && browsing.GetProperty("args").GetProperty("pid").GetInt32() == 4242, "activity lacked command or process ID");
        Require(browsing.GetProperty("args").GetProperty("activity").GetProperty("details").GetString() == "In the launcher", "browsing activity text changed");
        var playing = frames[2].Body.GetProperty("args").GetProperty("activity");
        Require(playing.GetProperty("details").GetString() == "Playing Civ13", "playing activity text changed");
        Require(playing.GetProperty("state").GetString() == "NOMADS_GAIA on civ13.com", "server line was " + playing.GetProperty("state").GetString());
        Require(playing.GetProperty("timestamps").GetProperty("start").GetInt64() == 1_800_000_000, "elapsed time did not start at join");
        Require(frames[3].Body.GetProperty("args").GetProperty("activity").ValueKind == JsonValueKind.Null, "clear did not send a null activity");
        Require(frames.All(f => !f.Body.GetRawText().Contains("ckey", StringComparison.OrdinalIgnoreCase)), "presence carried a BYOND key");
        Require(frames[1].Body.GetProperty("nonce").GetString() != frames[2].Body.GetProperty("nonce").GetString(), "nonces repeated");
        Require(pipe.Disposed && !presence.Connected, "pipe stayed open after dispose");
        Require(presence.LastResult == "Cleared.", "last result was " + presence.LastResult);
        Require(DiscordPresence.ServerLine("", "civ13.com") == "civ13.com", "empty map left a dangling 'on'");

        // Discord not running: nothing is written and the launcher keeps going.
        var attempts = 0;
        var absent = new DiscordPresence(Id, () => { attempts++; return null; });
        absent.Browsing();
        absent.Dispose();
        Require(attempts == 1 && absent.LastResult == "Discord is not running.", "missing Discord was not reported");

        // A refused handshake drops the pipe; an error reply is reported, not thrown.
        var refused = new FakePipe("{\"evt\":\"ERROR\",\"data\":{\"code\":4000}}");
        var rejecting = new DiscordPresence(Id, () => refused);
        rejecting.Browsing();
        rejecting.Dispose();
        Require(refused.Disposed && rejecting.LastResult == "Discord connection lost.", "refused handshake kept the pipe");
        var errorPipe = new FakePipe(ready, "{\"cmd\":\"SET_ACTIVITY\",\"evt\":\"ERROR\"}");
        var erroring = new DiscordPresence(Id, () => errorPipe);
        erroring.Browsing();
        erroring.Dispose();
        Require(erroring.LastResult == "Discord refused the activity.", "error reply was " + erroring.LastResult);

        // Long server text is bounded to Discord's 128 characters.
        var longPipe = new FakePipe(ready, ok);
        var bounded = new DiscordPresence(Id, () => longPipe);
        bounded.Playing(new string('x', 300), started);
        bounded.Dispose();
        Require(Parse(longPipe.Written.ToArray())[1].Body.GetProperty("args").GetProperty("activity").GetProperty("state").GetString()!.Length == 128, "state was not bounded");

        // Settings: off without an ID, opt-out saved, override kept, bad IDs ignored.
        var dir = Path.Combine(root, "discord-presence");
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, PresenceSettings.FileName);
        var none = PresenceSettings.Load(dir);
        Require(none.ShowActivity && none.ApplicationId == PresenceSettings.ValidId(PresenceSettings.BuiltInApplicationId), "defaults changed");
        File.WriteAllText(file, JsonSerializer.Serialize(new { application_id = Id }));
        Require(PresenceSettings.Load(dir).ApplicationId == Id, "application_id override ignored");
        PresenceSettings.SaveShowActivity(dir, false);
        var saved = PresenceSettings.Load(dir);
        Require(!saved.ShowActivity && saved.ApplicationId == Id, "opt-out lost the override");
        File.WriteAllText(file, "{\"application_id\":\"not-a-number\",\"show_activity\":\"yes\"}");
        var bad = PresenceSettings.Load(dir);
        Require(bad.ShowActivity && bad.ApplicationId == PresenceSettings.ValidId(PresenceSettings.BuiltInApplicationId), "invalid settings were accepted");
        File.WriteAllText(file, "{broken");
        Require(PresenceSettings.Load(dir).ShowActivity, "broken settings file stopped the launcher");
        try { _ = new DiscordPresence("12"); Require(false, "short ID accepted"); } catch (ArgumentException) { assertions++; }
        return assertions;
    }
}
