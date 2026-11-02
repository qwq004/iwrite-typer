# IWrite 快速写入工具 —— 把文本以"键盘输入"方式灌入任意输入框（不依赖剪贴板）
# 适用：iwrite 等禁用粘贴的网页编辑器。整段文本分批 SendInput，速度接近瞬间。
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class Typer {
  [StructLayout(LayoutKind.Explicit, Size = 40)]
  public struct INPUT {
    [FieldOffset(0)]  public uint   type;
    [FieldOffset(8)]  public ushort wVk;
    [FieldOffset(10)] public ushort wScan;
    [FieldOffset(12)] public uint   dwFlags;
    [FieldOffset(16)] public uint   time;
    [FieldOffset(24)] public IntPtr dwExtraInfo;
  }

  [DllImport("user32.dll", SetLastError = true)]
  public static extern uint SendInput(uint n, INPUT[] p, int cb);
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);

  const uint UNICODE = 0x0004, KEYUP = 0x0002;

  public static uint SendChars(string s) {
    int n = s.Length;
    if (n == 0) return 0;
    INPUT[] a = new INPUT[2 * n];
    for (int k = 0; k < n; k++) {
      char c = s[k];
      a[2 * k].type = 1;     a[2 * k].wScan = c;     a[2 * k].dwFlags = UNICODE;
      a[2 * k + 1].type = 1; a[2 * k + 1].wScan = c; a[2 * k + 1].dwFlags = UNICODE | KEYUP;
    }
    return SendInput((uint)(2 * n), a, Marshal.SizeOf(typeof(INPUT)));
  }

  public static uint SendKey(ushort vk) {
    INPUT[] a = new INPUT[2];
    a[0].type = 1; a[0].wVk = vk;
    a[1].type = 1; a[1].wVk = vk; a[1].dwFlags = KEYUP;
    return SendInput(2, a, Marshal.SizeOf(typeof(INPUT)));
  }

  public static uint Chord(ushort mod, ushort vk) {
    INPUT[] a = new INPUT[4];
    a[0].type = 1; a[0].wVk = mod;
    a[1].type = 1; a[1].wVk = vk;
    a[2].type = 1; a[2].wVk = vk;  a[2].dwFlags = KEYUP;
    a[3].type = 1; a[3].wVk = mod; a[3].dwFlags = KEYUP;
    return SendInput(4, a, Marshal.SizeOf(typeof(INPUT)));
  }

  public static long Fore() { return GetForegroundWindow().ToInt64(); }

  public static string Title(long h) {
    var sb = new System.Text.StringBuilder(400);
    GetWindowText(new IntPtr(h), sb, 400);
    return sb.ToString();
  }
}
'@

# ---------------- 界面 ----------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "IWrite 快速写入工具"
$form.Size = New-Object System.Drawing.Size(780, 712)
$form.StartPosition = "CenterScreen"
$form.TopMost = $false
$form.MinimizeBox = $true
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = "① 把正文放进下面（可带换行，换行=分段）"
$lbl.Location = New-Object System.Drawing.Point(12, 10)
$lbl.AutoSize = $true
$form.Controls.Add($lbl)

$tb = New-Object System.Windows.Forms.TextBox
$tb.Multiline = $true
$tb.ScrollBars = "Vertical"
$tb.AcceptsReturn = $true
$tb.Location = New-Object System.Drawing.Point(12, 32)
$tb.Size = New-Object System.Drawing.Size(740, 400)
$tb.Font = New-Object System.Drawing.Font("Consolas", 10)
$form.Controls.Add($tb)

$btnPaste = New-Object System.Windows.Forms.Button
$btnPaste.Text = "从剪贴板读取"
$btnPaste.Location = New-Object System.Drawing.Point(12, 440)
$btnPaste.Size = New-Object System.Drawing.Size(120, 30)
$form.Controls.Add($btnPaste)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "清空文本"
$btnClear.Location = New-Object System.Drawing.Point(140, 440)
$btnClear.Size = New-Object System.Drawing.Size(90, 30)
$form.Controls.Add($btnClear)

$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = "② 倒数秒数"
$lbl2.Location = New-Object System.Drawing.Point(250, 447)
$lbl2.AutoSize = $true
$form.Controls.Add($lbl2)

$numCount = New-Object System.Windows.Forms.NumericUpDown
$numCount.Minimum = 1; $numCount.Maximum = 10; $numCount.Value = 3
$numCount.Location = New-Object System.Drawing.Point(338, 444)
$numCount.Size = New-Object System.Drawing.Size(50, 26)
$form.Controls.Add($numCount)

$lbl3 = New-Object System.Windows.Forms.Label
$lbl3.Text = "每批字符"
$lbl3.Location = New-Object System.Drawing.Point(404, 447)
$lbl3.AutoSize = $true
$form.Controls.Add($lbl3)

$numBatch = New-Object System.Windows.Forms.NumericUpDown
$numBatch.Minimum = 1; $numBatch.Maximum = 60; $numBatch.Value = 14
$numBatch.Location = New-Object System.Drawing.Point(470, 444)
$numBatch.Size = New-Object System.Drawing.Size(50, 26)
$form.Controls.Add($numBatch)

$lbl4 = New-Object System.Windows.Forms.Label
$lbl4.Text = "批间隔(ms)"
$lbl4.Location = New-Object System.Drawing.Point(536, 447)
$lbl4.AutoSize = $true
$form.Controls.Add($lbl4)

$numGap = New-Object System.Windows.Forms.NumericUpDown
$numGap.Minimum = 0; $numGap.Maximum = 2000; $numGap.Value = 35
$numGap.Increment = 5
$numGap.Location = New-Object System.Drawing.Point(612, 444)
$numGap.Size = New-Object System.Drawing.Size(60, 26)
$form.Controls.Add($numGap)

$chkClear = New-Object System.Windows.Forms.CheckBox
$chkClear.Text = "写入前先 Ctrl+A/Delete 清空目标框（默认不勾）"
$chkClear.Location = New-Object System.Drawing.Point(12, 478)
$chkClear.AutoSize = $true
$form.Controls.Add($chkClear)

$btnGo = New-Object System.Windows.Forms.Button
$btnGo.Text = "③ 开始写入"
$btnGo.Location = New-Object System.Drawing.Point(12, 506)
$btnGo.Size = New-Object System.Drawing.Size(150, 42)
$btnGo.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 90)
$btnGo.ForeColor = [System.Drawing.Color]::White
$btnGo.FlatStyle = "Flat"
$btnGo.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnGo)

$btnHi = New-Object System.Windows.Forms.Button
$btnHi.Text = "窗口置顶：关"
$btnHi.Location = New-Object System.Drawing.Point(174, 506)
$btnHi.Size = New-Object System.Drawing.Size(110, 30)
$form.Controls.Add($btnHi)

$status = New-Object System.Windows.Forms.Label
$status.Text = "就绪"
$status.Location = New-Object System.Drawing.Point(12, 556)
$status.AutoSize = $true
$status.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($status)

$bar = New-Object System.Windows.Forms.ProgressBar
$bar.Location = New-Object System.Drawing.Point(12, 578)
$bar.Size = New-Object System.Drawing.Size(740, 16)
$form.Controls.Add($bar)

$tip = New-Object System.Windows.Forms.Label
$tip.Text = "用法：填正文 → 点开始 → 立刻点进 iwrite 写作框（把光标放进去）→ 倒数结束时开始灌入。中途鼠标点到别处会自动停。"
$tip.Location = New-Object System.Drawing.Point(12, 598)
$tip.AutoSize = $true
$tip.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($tip)

$btnPaste.Add_Click({ if ([System.Windows.Forms.Clipboard]::ContainsText()) { $tb.Text = [System.Windows.Forms.Clipboard]::GetText() } })
$btnClear.Add_Click({ $tb.Text = "" })
$btnHi.Add_Click({ $form.TopMost = -not $form.TopMost; $btnHi.Text = "窗口置顶：" + $(if ($form.TopMost) { "开" } else { "关" }) })

$btnGo.Add_Click({
  $text = $tb.Text -replace "`r`n", "`n" -replace "`r", "`n"
  $text = $text.TrimEnd()
  if ($text.Length -eq 0) { [System.Windows.Forms.MessageBox]::Show("文本是空的。", "提示"); return }

  $btnGo.Enabled = $false; $btnPaste.Enabled = $false; $btnClear.Enabled = $false
  $batch = [int]$numBatch.Value
  $gap = [int]$numGap.Value

  for ($c = [int]$numCount.Value; $c -gt 0; $c--) {
    $status.Text = "请立刻点进写作框… " + $c
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 1000
  }

  $target = [Typer]::Fore()
  $status.Text = "目标窗口：" + [Typer]::Title($target)
  [System.Windows.Forms.Application]::DoEvents()
  if ($target -eq [int64]$form.Handle) {
    $status.Text = "没检测到写作框（你还没点进去），已取消"
    $btnGo.Enabled = $true; $btnPaste.Enabled = $true; $btnClear.Enabled = $true
    return
  }

  if ($chkClear.Checked) {
    [void][Typer]::Chord(0x11, 0x41); Start-Sleep -Milliseconds 120
    [void][Typer]::SendKey(0x2E);     Start-Sleep -Milliseconds 150
  }

  $paras = $text -split "`n"
  $total = $text.Length
  $done = 0
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $abort = $false
  $bar.Maximum = $total
  $bar.Value = 0

  for ($p = 0; $p -lt $paras.Length -and -not $abort; $p++) {
    if ($p -gt 0) { [void][Typer]::SendKey(0x0D); Start-Sleep -Milliseconds $gap; $done++ }
    $line = $paras[$p]
    for ($i = 0; $i -lt $line.Length; $i += $batch) {
      if ([Typer]::Fore() -ne $target) { $abort = $true; break }
      $len = [Math]::Min($batch, $line.Length - $i)
      if ($i + $len -lt $line.Length -and [char]::IsHighSurrogate($line[$i + $len - 1])) { $len-- }
      [void][Typer]::SendChars($line.Substring($i, $len))
      $done += $len
      $bar.Value = [Math]::Min($done, $total)
      $status.Text = "写入中… " + $done + " / " + $total
      [System.Windows.Forms.Application]::DoEvents()
      if ($gap -gt 0) { Start-Sleep -Milliseconds $gap }
    }
  }
  $sw.Stop()

  if ($abort) {
    $status.Text = "已中止：焦点被切换到别的窗口（已写入 " + $done + " / " + $total + "）"
  } else {
    $status.Text = "完成：写入 " + $done + " 字符，用时 " + [math]::Round($sw.Elapsed.TotalSeconds, 2) + " 秒"
  }
  $btnGo.Enabled = $true; $btnPaste.Enabled = $true; $btnClear.Enabled = $true
})

[void]$form.ShowDialog()
