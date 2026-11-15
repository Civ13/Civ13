using System.Diagnostics;
using System.Security.Cryptography;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// Optional launcher voice chat (issue #5122 Phase 3, docs/launcher-voice-plan.md).
// Voice is on when the voice app is installed beside the launcher in
// voice\civ13-voice.exe (the Discord Social SDK runtime ships with it, never
// with the launcher). Each join gets a fresh random key: it goes to the game
// in the join link and to the voice app on stdin, and nowhere else. A voice
// app that is missing, blocked or failing never stops the game from joining.
public static class VoiceChat {
    public const string Folder = "voice";
    public const string Executable = "civ13-voice.exe";
    private static readonly Regex KeyShape = new("^[A-Za-z0-9_-]{32,64}$", RegexOptions.CultureInvariant);

    public static bool ValidKey(string? key) => key != null && KeyShape.IsMatch(key);

    // 32 random bytes, base64url without padding: 43 characters.
    public static string NewKey() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public static string? Installed(string? launcherDirectory = null) {
        var root = launcherDirectory ?? AppContext.BaseDirectory;
        var exe = Path.Combine(root, Folder, Executable);
        return File.Exists(exe) ? exe : null;
    }

    // Starts the voice app for a game that just started. Returns null, with a
    // note on output, when voice cannot start; the game keeps running.
    public static Process? Start(VerifiedGameServer verified, string exe, Process game, string key, TextWriter output) {
        try {
            var voice = Process.Start(ServerCatalog.VoiceStart(verified, exe, game.Id));
            if (voice == null) throw new IOException("Voice chat did not start.");
            voice.StandardInput.WriteLine(key);
            voice.StandardInput.Close();
            output.WriteLine("Voice chat on: hold F5 to talk to players in sight, F6 for team radio. Change them in OOC > Keybindings.");
            return voice;
        } catch (Exception e) when (e is IOException or System.ComponentModel.Win32Exception or InvalidOperationException) {
            output.WriteLine("Voice chat unavailable: " + e.Message + " The game is unaffected.");
            return null;
        }
    }
}
