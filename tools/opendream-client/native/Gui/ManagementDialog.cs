using System.Drawing;
using System.Windows.Forms;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

namespace Civ13.Launcher.Gui;

// Window form of the read-only "M: Server management" menu. Same inputs and the same command.
internal sealed class ManagementDialog : Form {
    private readonly TextBox rootBox = new() { Dock = DockStyle.Fill };
    private readonly TextBox catalogBox = new() { Dock = DockStyle.Fill };
    private readonly TextBox hostBox = new() { Dock = DockStyle.Fill, MaxLength = 64 };
    private readonly TextBox output = new() {
        Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
        Font = new Font(FontFamily.GenericMonospace, 9f)
    };
    private readonly Button view = new() { Text = "View instances", AutoSize = true };

    public ManagementDialog() {
        Text = "Server management (read-only)";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        MinimumSize = new Size(640, 460);
        Size = new Size(760, 540);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, Padding = new Padding(12) };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        var notice = new Label {
            AutoSize = true, MaximumSize = new Size(700, 0), Margin = new Padding(0, 0, 0, 8),
            Text = string.Join(Environment.NewLine, RegisteredInstancesMenu.Notice) + Environment.NewLine +
                "Use only an operator-controlled trusted D: directory."
        };
        layout.Controls.Add(notice, 0, 0);
        layout.SetColumnSpan(notice, 3);

        var browseRoot = new Button { Text = "Browse...", AutoSize = true };
        browseRoot.Click += (_, _) => {
            using var dialog = new FolderBrowserDialog { Description = "Trusted D: root", UseDescriptionForTitle = true };
            if (dialog.ShowDialog(this) == DialogResult.OK) rootBox.Text = dialog.SelectedPath;
        };
        var browseCatalog = new Button { Text = "Browse...", AutoSize = true };
        browseCatalog.Click += (_, _) => {
            using var dialog = new OpenFileDialog { Title = "Registration catalog file", CheckFileExists = true };
            if (rootBox.Text.Length > 0 && Directory.Exists(rootBox.Text)) dialog.InitialDirectory = rootBox.Text;
            if (dialog.ShowDialog(this) == DialogResult.OK) catalogBox.Text = dialog.FileName;
        };
        AddRow(layout, 1, "Trusted D: root", rootBox, browseRoot);
        AddRow(layout, 2, "Registration catalog file", catalogBox, browseCatalog);
        AddRow(layout, 3, "Local host ID", hostBox, view);
        layout.Controls.Add(output, 0, 4);
        layout.SetColumnSpan(output, 3);
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        for (var row = 1; row <= 3; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel, Anchor = AnchorStyles.Right, Margin = new Padding(0, 8, 0, 0) };
        layout.Controls.Add(close, 2, 5);
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        Controls.Add(layout);
        AcceptButton = view;
        CancelButton = close;

        view.Click += async (_, _) => {
            string root = rootBox.Text.Trim(), catalog = catalogBox.Text.Trim(), host = hostBox.Text.Trim();
            if (root.Length == 0 || catalog.Length == 0 || host.Length == 0) {
                output.Text = "Enter the trusted D: root, the registration catalog file and the local host ID.";
                return;
            }
            view.Enabled = false;
            try {
                var text = await Task.Run(() => {
                    using var writer = new StringWriter();
                    _ = RegisteredInstancesCommand.Run([RegisteredInstancesCommand.Option, root, catalog, host], writer,
                        path => new ReadOnlyRegistrationFileReader(path), new MonotonicProcessObservationClock());
                    return writer.ToString();
                });
                output.Text = text.ReplaceLineEndings(Environment.NewLine);
            } finally { view.Enabled = true; }
        };
    }

    private static void AddRow(TableLayoutPanel layout, int row, string label, Control field, Control action) {
        layout.Controls.Add(new Label { Text = label, AutoSize = true, Anchor = AnchorStyles.Left, Margin = new Padding(0, 6, 8, 6) }, 0, row);
        layout.Controls.Add(field, 1, row);
        layout.Controls.Add(action, 2, row);
    }
}
