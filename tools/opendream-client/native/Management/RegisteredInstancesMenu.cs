using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// Interactive adapter for the existing explicit, declaration-only command.
public static class RegisteredInstancesMenu {
    public const string Option = "--manage-servers";
    public const string Key = "M";
    public const string Menu = "M: Server management (read-only)";
    public static readonly IReadOnlyList<string> Notice = [
        "Registered server instances - read-only, one-time view.",
        "Process state, ownership and readiness are not established by registration.",
        "Start / stop / save / update / restart: unavailable in this view; lifecycle authority is not established."
    ];

    public static bool TryHandle(string? choice, TextReader input, TextWriter output,
        Func<string, IRegistrationFileReader> readerFactory, Func<IProcessObservationClock> clockFactory) {
        if (!string.Equals(choice, Key, StringComparison.OrdinalIgnoreCase)) return false;
        ArgumentNullException.ThrowIfNull(input);
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(readerFactory);
        ArgumentNullException.ThrowIfNull(clockFactory);

        foreach (var line in Notice) output.WriteLine(line);
        output.WriteLine("Use only an operator-controlled trusted D: directory. Press Enter to cancel.");
        string? Ask(string prompt) {
            output.Write(prompt);
            var value = input.ReadLine();
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }

        var root = Ask("Trusted D: root: ");
        if (root is null) { output.WriteLine("Server management cancelled."); return true; }
        var catalog = Ask("Registration catalog file: ");
        if (catalog is null) { output.WriteLine("Server management cancelled."); return true; }
        var host = Ask("Local host ID: ");
        if (host is null) { output.WriteLine("Server management cancelled."); return true; }

        _ = RegisteredInstancesCommand.Run(
            [RegisteredInstancesCommand.Option, root, catalog, host], output, readerFactory, clockFactory());
        return true;
    }
}