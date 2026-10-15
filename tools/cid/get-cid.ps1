param([Parameter(Mandatory)][string]$ByondBin)
$ErrorActionPreference = 'Stop'
if ([IntPtr]::Size -ne 4) { throw 'Run with 32-bit Windows PowerShell.' }
$dll = Join-Path $ByondBin 'byondcore.dll'
if ((Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash -ne '55CF268A4F054F02D556D2ED3C26AB01B7B0318BB3C5419E85F88E4E3B9E5898') {
    throw 'Unsupported library: offsets are specific to the reviewed Windows BYOND 516.1681 binary.'
}
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class NativeCid {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr LoadLibraryW(string path);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool SetDllDirectoryW(string path);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    public delegate void Fingerprint([Out] byte[] buffer, int length);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate uint Crc(uint initial, [In] byte[] bytes, int length);
    public static uint Read(string dll) {
        if(!SetDllDirectoryW(System.IO.Path.GetDirectoryName(dll))) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        IntPtr module=LoadLibraryW(dll);
        if(module==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        var fingerprint=(Fingerprint)Marshal.GetDelegateForFunctionPointer(IntPtr.Add(module,0x29ab20),typeof(Fingerprint));
        var crc=(Crc)Marshal.GetDelegateForFunctionPointer(IntPtr.Add(module,0x244cc0),typeof(Crc));
        byte[] buffer=new byte[100];
        fingerprint(buffer,buffer.Length);
        int end=Array.IndexOf(buffer,(byte)0);
        if(end!=32) throw new Exception("Unexpected fingerprint format.");
        string hex=Encoding.ASCII.GetString(buffer,0,end).ToLowerInvariant();
        // Cid::GetString emits lowercase hex, omitting trailing zero bytes.
        while(hex.Length>0 && hex.EndsWith("00",StringComparison.Ordinal)) hex=hex.Substring(0,hex.Length-2);
        byte[] text=Encoding.ASCII.GetBytes(hex);
        return crc(uint.MaxValue,text,text.Length);
    }
}
'@
[NativeCid]::Read($dll).ToString([Globalization.CultureInfo]::InvariantCulture)
