using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

public sealed record RegisteredLogViewPage(bool RequiresReset, RegisteredLogResult? Observation, LogView? View);

// Unwired, one-page-at-a-time presentation. Injected sources must independently
// establish their own authorization and containment. Default access is disabled.
public sealed class RegisteredLogViewSession {
    public const int MaximumCursorKeys = 128;
    private sealed class DisabledSource : IRegisteredLogSource {
        public IRegisteredLogSession Open(InstanceBinding binding, string streamId) => throw new NotSupportedException("log-source-disabled");
    }
    private readonly object gate = new();
    private readonly RegisteredLogReader reader;
    private readonly IProcessObservationClock clock;
    private readonly Dictionary<(InstanceBinding Binding, string Stream), LogCursor> issued = [];
    public RegisteredLogViewSession(IProcessObservationClock clock) : this(new DisabledSource(), clock) { }
    public RegisteredLogViewSession(IRegisteredLogSource source, IProcessObservationClock clock) {
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock));
        reader = new RegisteredLogReader(source ?? throw new ArgumentNullException(nameof(source)), clock);
    }
    public RegisteredLogViewPage Read(RegistrationSnapshot registration, string registrationPath, string localHost,
        LogRequest request, long maximumRegistrationAge, long maximumViewAge) {
        ArgumentNullException.ThrowIfNull(request); request.Validate();
        if (maximumRegistrationAge <= 0 || maximumViewAge <= 0) throw new ContractException("invalid-log-view-age");
        var key = (request.Binding, request.StreamId);
        lock (gate) {
            // Retain at most one cursor per key and a bounded number of keys.
            // Do not silently evict a different selection or open a source.
            if (!issued.ContainsKey(key) && issued.Count >= MaximumCursorKeys)
                throw new ContractException("log-session-capacity");
            if (request.Cursor is not null && (!issued.TryGetValue(key, out var accepted) || accepted != request.Cursor))
                return new(true, null, null);
            try {
                if (request.Cursor is null) issued.Remove(key);
                var observation = reader.Read(registration, registrationPath, localHost, request, maximumRegistrationAge);
                if (observation.Observation is null) { issued.Remove(key); return new(false, observation, null); }
                var view = LogProjection.Project(request, observation.Observation, clock.Scope, clock.Milliseconds, maximumViewAge);
                Remember(key, view);
                return new(view.Status == LogViewStatus.ResetRequired, observation, view);
            } catch {
                issued.Remove(key); throw;
            }
        }
    }

    // Rechecks registration and projection at display time. Only projected
    // lines are written; a failed write invalidates the issued cursor.
    public RegisteredLogViewPage ReadAndWrite(TextWriter output, RegistrationSnapshot registration, string registrationPath,
        string localHost, LogRequest request, long maximumRegistrationAge, long maximumViewAge) {
        ArgumentNullException.ThrowIfNull(output);
        lock (gate) {
            var page = Read(registration, registrationPath, localHost, request, maximumRegistrationAge, maximumViewAge);
            var key = (request.Binding, request.StreamId);
            try {
                if (page.View is not null && page.Observation?.Observation is not null) {
                    var scope = clock.Scope; var now = clock.Milliseconds;
                    if (clock.Scope != scope) {
                        issued.Remove(key);
                        page = new(false, new(RegistrationViewStatus.ClockChanged, RegisteredLogSelection.RegistrationUnknown, null), null);
                    } else {
                        var batch = LocalManagementComposition.Compose(registration, [], registrationPath, localHost, scope, now, maximumRegistrationAge);
                        if (batch.Status != RegistrationViewStatus.Available) {
                            issued.Remove(key);
                            page = new(false, new(batch.Status, RegisteredLogSelection.RegistrationUnknown, null), null);
                        } else if (request.Binding.HostId != localHost || !batch.Entries.Any(entry => entry.Manifest.Binding == request.Binding)) {
                            issued.Remove(key);
                            var selection = request.Binding.HostId != localHost ? RegisteredLogSelection.NotLocal : RegisteredLogSelection.NotRegistered;
                            page = new(false, new(batch.Status, selection, null), null);
                        } else {
                            var view = LogProjection.Project(request, page.Observation.Observation, scope, now, maximumViewAge);
                            Remember(key, view); page = new(view.Status == LogViewStatus.ResetRequired, page.Observation, view);
                        }
                    }
                }
                if (page.RequiresReset) output.WriteLine("Log status: ResetRequired. Request a fresh page.");
                else if (page.View is null) {
                    var observation = page.Observation;
                    output.WriteLine(observation is null ? "Log status: Unavailable." :
                        "Registration status: " + observation.Registration + "; selection: " + observation.Selection + ".");
                } else {
                    output.WriteLine("Log status: " + page.View.Status + ".");
                    foreach (var line in page.View.Lines) output.WriteLine(line);
                    if (page.View.Truncated || page.View.InputTruncated) output.WriteLine("Log output truncated.");
                }
                return page;
            } catch {
                issued.Remove(key); throw;
            }
        }
    }
    private void Remember((InstanceBinding Binding, string Stream) key, LogView view) {
        if (view.Status == LogViewStatus.Available && view.NextCursor is not null) issued[key] = view.NextCursor;
        else issued.Remove(key);
    }
}
