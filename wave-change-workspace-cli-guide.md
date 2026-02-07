# Wave CLI 指令说明（自定义版本）

本指南说明我们修改后的 Wave 可执行文件支持的 CLI 指令，用于按名称切换/创建 workspace。

## 支持的命令

### 切换/创建 workspace

```
Wave.exe --switch-workspace=<workspaceName>
```

- 按 **workspace 名称** 精准切换（大小写不敏感）。
- 若目标 workspace 不存在，会自动创建并切换。
- 命令执行后会将窗口置前（尽量激活）。

## 示例

```
E:\MyWaveTerm\waveterm\make\win-unpacked\Wave.exe --switch-workspace=panda-oasis
```

## 说明

- **推荐使用等号形式**：`--switch-workspace=<name>`  
  由于 Electron/Chromium 自带参数较多，等号形式更稳定。
- 若参数错误或缺失，命令会以 **非 0 退出码** 结束。

## 命令行不退出的处理建议

由于 Wave 本身是 GUI 应用，直接在终端执行会占用当前命令行窗口。更优雅的做法是让它**后台启动/脱离当前终端**：

### PowerShell（推荐）
```
Start-Process "E:\MyWaveTerm\waveterm\make\win-unpacked\Wave.exe" `
  -ArgumentList "--switch-workspace=panda-oasis"
```

### cmd
```
start "" "E:\MyWaveTerm\waveterm\make\win-unpacked\Wave.exe" --switch-workspace=panda-oasis
```

这样命令会立即返回，不需要手动退出。 
