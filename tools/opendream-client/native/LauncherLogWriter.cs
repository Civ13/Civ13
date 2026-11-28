using System.Globalization;
using System.Text;

namespace Civ13.Launcher;

// Timestamp completed lines before handing them to a potentially asynchronous UI sink.
// Files displayed by the launcher are read as-is: their original event times are not inferred.
internal sealed class LauncherLogWriter(Action<string> sink, TimeProvider? clock = null) : TextWriter {
    private readonly StringBuilder line = new();
    private readonly TimeProvider time = clock ?? TimeProvider.System;
    public override Encoding Encoding => Encoding.UTF8;

    public override void Write(char value) {
        if (value == '\n') {
            var text = line.ToString();
            line.Clear();
            sink(string.IsNullOrWhiteSpace(text)
                ? text
                : $"[{time.GetLocalNow().ToString("yyyy-MM-dd HH:mm:ss zzz", CultureInfo.InvariantCulture)}] {text}");
        } else if (value != '\r') line.Append(value);
    }

    public override void Write(string? value) {
        if (value == null) return;
        foreach (var character in value) Write(character);
    }

    public override void WriteLine(string? value) {
        Write(value);
        Write('\n');
    }
}
