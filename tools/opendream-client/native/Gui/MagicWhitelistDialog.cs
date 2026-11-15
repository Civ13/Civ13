using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "Magic whitelist…": the players who may follow a god and learn magic on persistent
// worlds (Civ13 code/modules/divine/magic_whitelist.dm, MagicWhitelist.cs). One list for the whole group;
// running worlds pick up a change within 30 seconds. Staff can do the same in game (Admin > Magic Whitelist).
internal sealed class MagicWhitelistDialog : Form {
    private readonly HostControl control;
    private readonly Action<string> log;
    private readonly ListBox keys = new() { Width = 420, Height = 200, SelectionMode = SelectionMode.MultiExtended };
    private readonly TextBox entry = new() { Width = 300, PlaceholderText = "Player keys, comma separated" };
    private readonly TextBox result = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 420, Height = 70 };
    private readonly Button add = new() { Text = "Add", AutoSize = true };
    private readonly Button remove = new() { Text = "Remove selected", AutoSize = true };
    private readonly Button refresh = new() { Text = "Refresh", AutoSize = true };

    public MagicWhitelistDialog(HostControl control, Action<string> log) {
        this.control = control;
        this.log = log;
        Text = "Magic whitelist";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(420, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "Only these players can follow a god, pray for favours, read sealed notes or learn magic on persistent worlds. " +
                "One list for every region; running worlds pick up a change within 30 seconds. Removing someone suspends what " +
                "their characters learned without deleting it." });
        layout.Controls.Add(keys);
        var adding = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        adding.Controls.Add(entry);
        adding.Controls.Add(add);
        layout.Controls.Add(adding);
        var buttons = new FlowLayoutPanel { AutoSize = true };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(remove);
        buttons.Controls.Add(refresh);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        layout.Controls.Add(result);
        Controls.Add(layout);
        CancelButton = close;
        AcceptButton = add;

        add.Click += async (_, _) => {
            var typed = MagicWhitelist.SplitKeys(entry.Text);
            if (typed.Count == 0) { result.Text = "Type at least one player key."; return; }
            if (await Change(typed, null)) entry.Clear();
        };
        remove.Click += async (_, _) => {
            var picked = keys.SelectedItems.Cast<string>().ToList();
            if (picked.Count == 0) { result.Text = "Select the players to remove."; return; }
            if (MessageBox.Show(this, "Remove " + string.Join(", ", picked) + " from the magic whitelist? Their characters keep what they learned, " +
                    "but cannot use it until added again.", "Magic whitelist", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            await Change(null, picked);
        };
        refresh.Click += async (_, _) => await Change(null, null);
        Shown += async (_, _) => await Change(null, null);
    }

    private async Task<bool> Change(IReadOnlyList<string>? adding, IReadOnlyList<string>? removing) {
        add.Enabled = remove.Enabled = refresh.Enabled = false;
        try {
            var answer = await Task.Run(() => MagicWhitelist.Run(control, adding, removing));
            if (!answer.Ok) { result.Text = answer.Error ?? "No answer."; return false; }
            keys.Items.Clear();
            foreach (var key in answer.Keys) keys.Items.Add(key);
            var lines = new List<string> { answer.Keys.Count == 0 ? "Nobody is on the list." : answer.Keys.Count + " on the list." };
            if (answer.Added.Count > 0) lines.Add("Added: " + string.Join(", ", answer.Added));
            if (answer.Removed.Count > 0) lines.Add("Removed: " + string.Join(", ", answer.Removed));
            if ((adding != null || removing != null) && answer.Added.Count + answer.Removed.Count == 0) lines.Add("Nothing changed.");
            if (answer.File != null) lines.Add(answer.File);
            result.Text = string.Join(Environment.NewLine, lines);
            if (answer.Added.Count + answer.Removed.Count > 0)
                log("Magic whitelist: " + string.Join("; ", lines.Take(lines.Count - (answer.File != null ? 1 : 0)).Skip(1)));
            return true;
        } catch (ArgumentException e) {
            result.Text = e.Message;
            return false;
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "The request failed: " + e.Message;
            return false;
        } finally {
            add.Enabled = remove.Enabled = refresh.Enabled = true;
        }
    }
}
