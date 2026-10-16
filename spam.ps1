# Interactive spam macro. Run with:  spam
# Settings are saved to config.json next to this script.

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class Spam {
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public MI u; }
    [StructLayout(LayoutKind.Explicit)]
    struct MI {
        [FieldOffset(0)] public MOUSEINPUT m;
        [FieldOffset(0)] public KEYBDINPUT k;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx, dy; public uint data, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern uint MapVirtualKey(uint code, uint type);
    [DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint ms);
    [DllImport("winmm.dll")] static extern uint timeEndPeriod(uint ms);

    static INPUT Mouse(uint flags) {
        var i = new INPUT { type = 0 }; i.u.m.flags = flags; return i;
    }
    static INPUT Key(ushort scan, bool up) {
        var i = new INPUT { type = 1 };
        i.u.k.scan = scan;
        i.u.k.flags = 0x8 | (up ? 0x2u : 0u); // SCANCODE | KEYUP
        return i;
    }
    static bool Down(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    // mouseBtn: 0 none, 1 left, 2 right. Returns when quitVk is pressed.
    public static void Run(int toggleVk, int quitVk, double cps, int mouseBtn, int[] keyVks, bool hold) {
        timeBeginPeriod(1);
        var prio = Thread.CurrentThread.Priority;
        Thread.CurrentThread.Priority = ThreadPriority.AboveNormal;

        var list = new System.Collections.Generic.List<INPUT>();
        if (mouseBtn == 1) { list.Add(Mouse(0x2)); list.Add(Mouse(0x4)); }
        if (mouseBtn == 2) { list.Add(Mouse(0x8)); list.Add(Mouse(0x10)); }
        foreach (int vk in keyVks) {
            ushort scan = (ushort)MapVirtualKey((uint)vk, 0);
            list.Add(Key(scan, false)); list.Add(Key(scan, true));
        }
        INPUT[] cycle = list.ToArray(); // sent as ONE SendInput call per cycle
        int size = Marshal.SizeOf(typeof(INPUT));
        long period = cps > 0 ? (long)(Stopwatch.Frequency / cps) : 0;
        bool on = false, wasDown = false, wasQuit = Down(quitVk);
        long next = 0;

        try {
            while (true) {
                bool quit = Down(quitVk);
                if (quit && !wasQuit) break;
                wasQuit = quit;

                bool down = Down(toggleVk);
                if (hold) {
                    if (down != on) { on = down; next = Stopwatch.GetTimestamp(); Status(on); }
                } else if (down && !wasDown) {
                    on = !on; next = Stopwatch.GetTimestamp(); Status(on);
                }
                wasDown = down;

                if (!on) { Thread.Sleep(1); continue; }

                if (period > 0) {
                    long wait = next - Stopwatch.GetTimestamp();
                    if (wait > 0) {
                        if (wait > Stopwatch.Frequency / 500) Thread.Sleep(1); // >2ms left: yield
                        continue; // otherwise spin
                    }
                    next += period;
                    if (next < Stopwatch.GetTimestamp() - period) next = Stopwatch.GetTimestamp();
                }
                SendInput((uint)cycle.Length, cycle, size);
            }
        } finally {
            Thread.CurrentThread.Priority = prio;
            timeEndPeriod(1);
        }
    }
    static void Status(bool on) { Console.WriteLine(on ? "  ON" : "  OFF"); }
}
"@

$ConfigPath = Join-Path $PSScriptRoot "config.json"
$Default = [ordered]@{
    ToggleKey = "F6"; QuitKey = "End"; Speed = 0
    Mouse = "Left"          # None | Left | Right
    Keys = @("G", "F")
    Mode = "Toggle"         # Toggle | Hold
}

function Load-Config {
    $c = [ordered]@{} + $Default
    if (Test-Path $ConfigPath) {
        try {
            $j = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            foreach ($k in @($c.Keys)) { if ($null -ne $j.$k) { $c[$k] = $j.$k } }
            $c.Keys = @($c.Keys)
        } catch { }
    }
    $c
}
function Save-Config($c) { $c | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8 }

function Get-Vk([string]$name) {
    $n = $name.Trim()
    switch -Regex ($n.ToLower()) {
        '^(mouse3|middle)$' { return 0x04 }
        '^mouse4$' { return 0x05 }
        '^mouse5$' { return 0x06 }
        '^\d$' { $n = "D$n" }
    }
    try { return [int][System.Enum]::Parse([System.Windows.Forms.Keys], $n, $true) } catch { return $null }
}

function Ask-Key([string]$prompt, [string]$current) {
    $v = Read-Host "$prompt [$current]"
    if ($v -eq "") { return $current }
    if ($null -eq (Get-Vk $v)) { Write-Host "  Unknown key '$v'" -ForegroundColor Red; Start-Sleep 1; return $current }
    $v
}

$cfg = Load-Config
while ($true) {
    Clear-Host
    $speedText = if ($cfg.Speed -gt 0) { "$($cfg.Speed) cycles/sec" } else { "max" }
    $keysText  = if (@($cfg.Keys).Count) { (@($cfg.Keys) -join ", ") } else { "(none)" }
    Write-Host "=== Spam Macro ===" -ForegroundColor Cyan
    Write-Host " 1) Toggle key : $($cfg.ToggleKey)"
    Write-Host " 2) Mode       : $($cfg.Mode)   (Toggle = press on/off, Hold = active while held)"
    Write-Host " 3) Speed      : $speedText"
    Write-Host " 4) Mouse      : $($cfg.Mouse)"
    Write-Host " 5) Keys       : $keysText"
    Write-Host " 6) Quit key   : $($cfg.QuitKey)   (stops the macro, back to this menu)"
    Write-Host " S) START      R) Reset defaults      X) Exit"
    $ch = (Read-Host "Choose").Trim().ToLower()

    switch ($ch) {
        '1' { $cfg.ToggleKey = Ask-Key "Toggle key (F6, X, mouse4...)" $cfg.ToggleKey; Save-Config $cfg }
        '2' { $cfg.Mode = if ($cfg.Mode -eq "Toggle") { "Hold" } else { "Toggle" }; Save-Config $cfg }
        '3' {
            $v = Read-Host "Cycles per second (0 = max) [$($cfg.Speed)]"
            $d = 0.0
            if ($v -ne "" -and [double]::TryParse($v, [ref]$d) -and $d -ge 0) { $cfg.Speed = $d; Save-Config $cfg }
        }
        '4' {
            $cfg.Mouse = switch ($cfg.Mouse) { "Left" { "Right" } "Right" { "None" } default { "Left" } }
            Save-Config $cfg
        }
        '5' {
            $v = Read-Host "Keys to spam, comma separated, blank = none (e.g. G,F,E) [$keysText]"
            $list = @($v -split '[,\s]+' | Where-Object { $_ })
            $bad = @($list | Where-Object { $null -eq (Get-Vk $_) })
            if ($bad.Count) { Write-Host "  Unknown: $($bad -join ', ')" -ForegroundColor Red; Start-Sleep 1 }
            elseif ($v -ne "" -or $keysText -ne "(none)") { $cfg.Keys = $list; Save-Config $cfg }
        }
        '6' { $cfg.QuitKey = Ask-Key "Quit key" $cfg.QuitKey; Save-Config $cfg }
        'r' { $cfg = [ordered]@{} + $Default; Save-Config $cfg }
        'x' { return }
        's' {
            $keyVks = [int[]]@(@($cfg.Keys) | ForEach-Object { Get-Vk $_ })
            $mouse = switch ($cfg.Mouse) { "Left" { 1 } "Right" { 2 } default { 0 } }
            if ($mouse -eq 0 -and $keyVks.Count -eq 0) {
                Write-Host "Nothing to spam - enable the mouse or add keys." -ForegroundColor Red; Start-Sleep 2; continue
            }
            $verb = if ($cfg.Mode -eq "Hold") { "Hold" } else { "Press" }
            Write-Host "`n$verb $($cfg.ToggleKey) to activate. Press $($cfg.QuitKey) to stop." -ForegroundColor Green
            [Spam]::Run((Get-Vk $cfg.ToggleKey), (Get-Vk $cfg.QuitKey), [double]$cfg.Speed, $mouse, $keyVks, ($cfg.Mode -eq "Hold"))
        }
    }
}
