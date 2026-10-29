using Civ13.ServerManagement;

namespace Civ13.Launcher.Management;

// This is a trusted I/O seam, not proof of ownership or a sandbox.
public interface IRegistrationFileSystem {
    DriveType DriveType { get; }
    FileAttributes Attributes(string path);
    Stream OpenRead(string path);
}

internal sealed class SystemRegistrationFileSystem : IRegistrationFileSystem {
    public DriveType DriveType => OperatingSystem.IsWindows() ? new DriveInfo("D").DriveType : DriveType.Unknown;
    public FileAttributes Attributes(string path) => File.GetAttributes(path);
    public Stream OpenRead(string path) => new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.SequentialScan);
}

// Unwired and deliberately conservative. These checks cannot prevent a concurrent
// path replacement between checks and open; do not treat this as a security sandbox.
public sealed class ReadOnlyRegistrationFileReader : IRegistrationFileReader {
    private readonly string root;
    private readonly IRegistrationFileSystem files;

    public ReadOnlyRegistrationFileReader(string canonicalRoot) : this(canonicalRoot, new SystemRegistrationFileSystem()) { }

    public ReadOnlyRegistrationFileReader(string canonicalRoot, IRegistrationFileSystem files) {
        RegistrationProvider.ValidatePath(canonicalRoot);
        root = canonicalRoot;
        this.files = files ?? throw new ArgumentNullException(nameof(files));
    }

    public RegistrationRead Read(string absolutePath, int maximumBytes) {
        try { RegistrationProvider.ValidatePath(absolutePath); }
        catch (ContractException) { return new(RegistrationReadKind.Invalid, null); }
        if (maximumBytes <= 0 || maximumBytes > ManifestJson.MaximumCatalogBytes ||
            !absolutePath.StartsWith(root + "\\", StringComparison.OrdinalIgnoreCase))
            return new(RegistrationReadKind.Invalid, null);

        bool reading = false;
        try {
            // A fixed local volume is required; unknown, network and removable
            // volumes are not silently admitted. This does not prove volume identity.
            if (files.DriveType != DriveType.Fixed) return new(RegistrationReadKind.Unavailable, null);
            var before = CheckComponents(absolutePath);
            if (before is null) return new(RegistrationReadKind.Invalid, null);
            using var stream = files.OpenRead(absolutePath);
            reading = true;
            var bytes = new byte[maximumBytes + 1];
            var count = 0;
            while (count < bytes.Length) {
                var n = stream.Read(bytes, count, bytes.Length - count);
                if (n == 0) break;
                count += n;
            }
            if (count > maximumBytes) return new(RegistrationReadKind.Invalid, null);
            var after = CheckComponents(absolutePath);
            if (after is null || !before.SequenceEqual(after) || files.DriveType != DriveType.Fixed)
                return new(RegistrationReadKind.Invalid, null);
            return new(RegistrationReadKind.Available, bytes[..count]);
        } catch (UnauthorizedAccessException) { return new(RegistrationReadKind.Denied, null); }
        catch (System.Security.SecurityException) { return new(RegistrationReadKind.Denied, null); }
        catch (FileNotFoundException) { return new(reading ? RegistrationReadKind.Unavailable : RegistrationReadKind.Missing, null); }
        catch (DirectoryNotFoundException) { return new(reading ? RegistrationReadKind.Unavailable : RegistrationReadKind.Missing, null); }
        catch (IOException) { return new(RegistrationReadKind.Unavailable, null); }
    }

    private FileAttributes[]? CheckComponents(string path) {
        var parts = path[3..].Split('\\');
        var current = "D:\\";
        var attributes = new FileAttributes[parts.Length + 1];
        for (int i = 0; i <= parts.Length; i++) {
            if (i > 0) current += (i == 1 ? "" : "\\") + parts[i - 1];
            var value = files.Attributes(current);
            if ((value & FileAttributes.ReparsePoint) != 0 ||
                ((value & FileAttributes.Directory) != 0) != (i < parts.Length)) return null;
            attributes[i] = value;
        }
        return attributes;
    }
}
