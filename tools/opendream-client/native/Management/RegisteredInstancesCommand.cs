using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// An explicit, one-shot operator view. No process targets, discovery or controls are inferred.
public static class RegisteredInstancesCommand {
    public const string Option = "--registered-instances";
    public const string Usage = "Usage: --registered-instances <trusted-D-root> <registration-file> <local-host-id>";

    public static int Run(IReadOnlyList<string> args, TextWriter output,
        Func<string, IRegistrationFileReader> readerFactory, IProcessObservationClock clock) {
        ArgumentNullException.ThrowIfNull(args);
        ArgumentNullException.ThrowIfNull(output);
        ArgumentNullException.ThrowIfNull(readerFactory);
        ArgumentNullException.ThrowIfNull(clock);
        if (args.Count != 4 || args[0] != Option) {
            output.WriteLine(Usage);
            return 1;
        }
        try {
            RegistrationProvider.ValidatePath(args[1]);
            RegistrationProvider.ValidatePath(args[2]);
            if (!args[2].StartsWith(args[1] + "\\", StringComparison.OrdinalIgnoreCase) ||
                args[3] is not { Length: > 0 and <= 64 } ||
                !args[3].All(c => c is >= 'a' and <= 'z' or >= 'A' and <= 'Z' or >= '0' and <= '9' or '_' or '-'))
                throw new ContractException("invalid-operator-selection");
            var snapshot = new RegistrationProvider(readerFactory(args[1]), clock).Read(args[2]);
            // Registrations alone cannot generate a process target or establish provenance.
            LocalManagementPresentation.WriteRegisteredInstances(output, snapshot, [], args[2], args[3], clock, 5000, 5000);
            return snapshot.Status == RegistrationStatus.Available ? 0 : 1;
        } catch (Exception e) when (e is ContractException or IOException or UnauthorizedAccessException or System.Security.SecurityException) {
            // Do not disclose the operator's registration paths or raw exception text.
            output.WriteLine("Registration status: Invalid or unavailable. Registered instances remain unknown.");
            return 1;
        }
    }
}
