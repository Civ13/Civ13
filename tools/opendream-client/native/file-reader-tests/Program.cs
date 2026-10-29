using Civ13.Launcher.Management;
using Civ13.ServerManagement;

const string Root = @"D:\owned";
const string FilePath = @"D:\owned\registrations.json";
int assertions = 0;
void Assert(bool condition, string message) { assertions++; if (!condition) throw new Exception(message); }
void Is(RegistrationReadKind expected, RegistrationRead actual, string message) {
    Assert(actual.Kind == expected, message + ": " + actual.Kind);
    if (expected != RegistrationReadKind.Available) Assert(actual.Content is null, message + " leaked data");
}
var fs = new FakeFileSystem();
var reader = new ReadOnlyRegistrationFileReader(Root, fs);
var ok = reader.Read(FilePath, 4);
Is(RegistrationReadKind.Available, ok, "available");
Assert(ok.Content!.SequenceEqual(new byte[] { 1, 2, 3, 4 }), "exact bytes");
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, 3), "oversize");
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, 0), "invalid limit");
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, ManifestJson.MaximumCatalogBytes + 1), "maximum limit");
int count = fs.Calls;
Is(RegistrationReadKind.Invalid, reader.Read(@"D:\owned-other\registrations.json", 4), "sibling prefix");
Is(RegistrationReadKind.Invalid, reader.Read(@"D:\owned\..\escape.json", 4), "traversal");
Is(RegistrationReadKind.Invalid, reader.Read(Root, 4), "root itself");
Assert(fs.Calls == count, "invalid requests must not access filesystem");
Is(RegistrationReadKind.Available, reader.Read(@"d:\OWNED\registrations.json", 4), "case insensitive root");
fs.Drive = DriveType.Network;
Is(RegistrationReadKind.Unavailable, reader.Read(FilePath, 4), "network drive");
fs.Drive = DriveType.Fixed;
fs.Mode = "reparse";
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, 4), "reparse ancestor");
fs.Mode = "target-reparse";
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, 4), "reparse target");
fs.Mode = "changed";
Is(RegistrationReadKind.Invalid, reader.Read(FilePath, 4), "changed after read");
fs.Mode = "missing";
Is(RegistrationReadKind.Missing, reader.Read(FilePath, 4), "missing");
fs.Mode = "late-missing";
Is(RegistrationReadKind.Unavailable, reader.Read(FilePath, 4), "missing after open");
fs.Mode = "denied";
Is(RegistrationReadKind.Denied, reader.Read(FilePath, 4), "denied");
fs.Mode = "open-denied";
Is(RegistrationReadKind.Denied, reader.Read(FilePath, 4), "open denied");
fs.Mode = "open-missing";
Is(RegistrationReadKind.Missing, reader.Read(FilePath, 4), "missing at open");
fs.Mode = "io";
Is(RegistrationReadKind.Unavailable, reader.Read(FilePath, 4), "io error");
try { _ = new ReadOnlyRegistrationFileReader(@"C:\owned", fs); throw new Exception("invalid root admitted"); }
catch (ContractException) { assertions++; }
Console.WriteLine($"{assertions} file-reader assertions passed (fake filesystem only)");

sealed class FakeFileSystem : IRegistrationFileSystem {
    public DriveType Drive { get; set; } = DriveType.Fixed;
    private string mode = "ok";
    public string Mode { get => mode; set { mode = value; opened = false; } }
    public int Calls { get; private set; }
    private bool opened;
    public DriveType DriveType { get { Calls++; return Drive; } }
    public FileAttributes Attributes(string path) {
        Calls++;
        if (Mode == "missing" || (Mode == "late-missing" && opened)) throw new FileNotFoundException();
        if (Mode == "denied") throw new UnauthorizedAccessException();
        if (Mode == "io") throw new IOException();
        bool target = path.EndsWith("registrations.json", StringComparison.OrdinalIgnoreCase);
        if ((Mode == "reparse" && path.EndsWith("owned", StringComparison.OrdinalIgnoreCase)) || (Mode == "target-reparse" && target))
            return FileAttributes.ReparsePoint;
        var result = target ? FileAttributes.Normal : FileAttributes.Directory;
        if (Mode == "changed" && opened && target) result |= FileAttributes.Hidden;
        return result;
    }
    public Stream OpenRead(string path) {
        Calls++;
        if (Mode == "open-denied") throw new UnauthorizedAccessException();
        if (Mode == "open-missing") throw new FileNotFoundException();
        opened = true; return new MemoryStream(new byte[] { 1, 2, 3, 4 });
    }
}
