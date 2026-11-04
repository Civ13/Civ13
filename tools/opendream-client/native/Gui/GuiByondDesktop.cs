using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Same detection, validation and installer behavior as WindowsByondDesktop; only the two
// questions become dialogs. The installer still shows its own license and is never silent.
internal sealed class GuiByondDesktop(IWin32Window owner, WindowsByondDesktop inner, ByondRequirement requirement) : IByondDesktop {
    public IEnumerable<string> Candidates(string root, ByondRequirement required) => inner.Candidates(root, required);
    public bool Matches(string path, ByondRequirement required) => inner.Matches(path, required);
    public void ValidateInstaller(string installer, ByondRequirement required) => inner.ValidateInstaller(installer, required);
    public Task<int> Install(string installer, string destination) => inner.Install(installer, destination);

    public string? ChooseExisting() {
        var answer = MessageBox.Show(owner,
            $"The required BYOND {requirement.Version} was not found.\n\n" +
            "Yes: choose a folder where you already installed it.\n" +
            "No: download the official installer.\n" +
            "Cancel: stop BYOND setup for now.",
            "BYOND setup", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
        if (answer == DialogResult.Cancel) throw new IOException("BYOND setup cancelled. Existing installations are unchanged.");
        if (answer != DialogResult.Yes) return null;
        using var dialog = new FolderBrowserDialog {
            Description = $"Select your BYOND {requirement.Version} folder (or its bin folder)",
            UseDescriptionForTitle = true
        };
        return dialog.ShowDialog(owner) == DialogResult.OK ? dialog.SelectedPath : null;
    }

    public bool ConfirmInstall(ByondRequirement required) => MessageBox.Show(owner,
        $"Download and open the official BYOND {required.Version} installer?\n\n" +
        "Review its license and any Windows permission prompts. No silent install is used.",
        "BYOND setup", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2) == DialogResult.Yes;
}
