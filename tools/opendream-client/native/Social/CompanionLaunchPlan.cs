using System.Text;
namespace Civ13.Launcher.Social;

internal sealed record CompanionLaunchPlan(string CommandLine, string EnvironmentBlock) {
    internal static CompanionLaunchPlan Create(CompanionExecutable executable, CompanionLaunchTicket ticket, string windows, string temp) {
        ArgumentNullException.ThrowIfNull(executable); ArgumentNullException.ThrowIfNull(ticket);
        if (ticket.Session == Guid.Empty || ticket.WireVersion != 1 || ticket.Profile == null) throw new ArgumentException("Launch ticket.");
        if (string.IsNullOrWhiteSpace(windows) || string.IsNullOrWhiteSpace(temp) || windows.Contains('\0') || temp.Contains('\0')) throw new ArgumentException("Scoped environment.");
        var command = new StringBuilder('"' + executable.Path + "\" --social-peer-v1 ");
        command.Append(ticket.Profile.Target.Provider).Append(' ').Append(ticket.Profile.Target.Port.ToString(System.Globalization.CultureInfo.InvariantCulture)).Append(' ').Append(ticket.Profile.ApplicationId);
        // No parent environment inheritance, PATH, tokens, bot identity or SDK grants.
        var environment = "SystemRoot=" + windows + "\0TEMP=" + temp + "\0TMP=" + temp + "\0WINDIR=" + windows + "\0\0";
        return new(command.ToString(), environment);
    }
}
