using System.Text;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

var count = 0;
void Check(bool ok, string name) { count++; if (!ok) throw new Exception(name); }
void Reject(Action action, string name) { var ok = false; try { action(); } catch (ContractException) { ok = true; } Check(ok, name); }
var clock = new FakeClock();
var source = new FakeReader();
var provider = new RegistrationProvider(source, clock, 10);
const string path = @"D:\synthetic\catalog.json";
var json = "{\"schema\":\"civ13.catalog.v1\",\"instances\":[]}";
source.Result = new(RegistrationReadKind.Available, Encoding.UTF8.GetBytes(json));
var snapshot = provider.Read(path);
Check(snapshot.Status == RegistrationStatus.Available && snapshot.Catalog!.Instances.Count == 0, "valid empty declaration");
Check(snapshot.ClockScope == "fake-clock" && snapshot.SampleMilliseconds == 100 && snapshot.CompletedMilliseconds == 100, "original clock binding");
Check(snapshot.SourcePath == path, "snapshot retains exact requested source binding");
Check(source.Calls == 1 && source.Path == path && source.Limit == ManifestJson.MaximumCatalogBytes, "one bounded explicitly named read");
foreach (var bad in new[] { "", @"C:\data\catalog.json", @"D:catalog.json", @"\\server\share\catalog.json", @"D:\a\..\catalog.json", @"D:\a\con.txt", @"D:\a\file:stream", @"D:\a\bad.\catalog.json", @"D:\a\\catalog.json", "D:/data/catalog.json" })
    Reject(() => provider.Read(bad), "invalid path refused");
Check(source.Calls == 1, "invalid paths cause no read");
foreach (var prefix in new[] { "COM", "com", "LPT", "lpt" })
foreach (var digit in new[] { '\u00b9', '\u00b2', '\u00b3' })
foreach (var extension in new[] { "", ".json", ".tar.gz" }) {
    var name = $"{prefix}{digit}{extension}";
    foreach (var reserved in new[] { @"D:\a\" + name, @"D:\" + name + @"\catalog.json" }) {
        var before = source.Calls;
        Reject(() => provider.Read(reserved), "superscript device path rejected");
        Check(source.Calls == before, "superscript device path causes no read");
    }
}
foreach (var ordinary in new[] { "COM0", "COM10", "COM¹x", "LPT⁴", "COM²-dir", "LPT³-log.txt" }) {
    var before = source.Calls;
    Check(provider.Read(@"D:\a\" + ordinary).Status == RegistrationStatus.Available && source.Calls == before + 1,
        "non-reserved similar name reaches reader");
}
foreach (var kind in new[] { RegistrationReadKind.Missing, RegistrationReadKind.Denied, RegistrationReadKind.Unavailable, RegistrationReadKind.Invalid }) {
    source.Result = new(kind, null); var result = provider.Read(path);
    Check(result.Status.ToString() == kind.ToString() && result.Catalog is null && result.SourcePath == path, "distinct request-bound missing/denied/unavailable");
}
source.Error = new UnauthorizedAccessException("not for display");
Check(provider.Read(path).Status == RegistrationStatus.Denied, "access exception is sanitized");
source.Error = new IOException("not for display");
Check(provider.Read(path).Status == RegistrationStatus.Unavailable, "IO exception is sanitized");
source.Error = null;
foreach (var bad in new[] { new RegistrationRead(RegistrationReadKind.Available, null), new RegistrationRead(RegistrationReadKind.Missing, [1]),
    new RegistrationRead((RegistrationReadKind)99, null), new RegistrationRead(RegistrationReadKind.Available, [0xff]),
    new RegistrationRead(RegistrationReadKind.Available, new byte[ManifestJson.MaximumCatalogBytes + 1]),
    new RegistrationRead(RegistrationReadKind.Available, Encoding.UTF8.GetBytes("{\"schema\":\"unknown\",\"instances\":[]}")) }) {
    source.Result = bad; Check(provider.Read(path).Status == RegistrationStatus.Invalid, "invalid bytes/evidence fail closed");
}
source.Result = new(RegistrationReadKind.Available, Encoding.UTF8.GetBytes(json));
source.OnRead = () => clock.Now = 111;
Check(provider.Read(path).Status == RegistrationStatus.ReadTooSlow, "slow read not admitted");
clock.Now = 100; source.OnRead = () => clock.Scope = "other";
Check(provider.Read(path).Status == RegistrationStatus.ClockChanged, "clock scope change not admitted");
clock.Scope = "fake-clock"; clock.Now = 100; source.OnRead = () => clock.Now = 99;
Check(provider.Read(path).Status == RegistrationStatus.ClockChanged, "clock regression not admitted");
clock.Now = -1; source.OnRead = null; var calls = source.Calls;
Reject(() => provider.Read(path), "bad clock rejected"); Check(source.Calls == calls, "bad clock prevents read");
Console.WriteLine($"PASS {count} registration-provider assertions; injected reader/clock only, no real files or configuration.");

sealed class FakeClock : IProcessObservationClock { public string Scope { get; set; } = "fake-clock"; public long Now = 100; public long Milliseconds => Now; }
sealed class FakeReader : IRegistrationFileReader {
    public RegistrationRead Result = new(RegistrationReadKind.Unavailable, null); public int Calls, Limit; public string? Path; public Action? OnRead; public Exception? Error;
    public RegistrationRead Read(string absolutePath, int maximumBytes) { Calls++; Path = absolutePath; Limit = maximumBytes; OnRead?.Invoke(); if (Error is not null) throw Error; return Result; }
}
