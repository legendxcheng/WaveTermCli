# PRD：Wave 外部 Workspace 切换与持续补丁构建

**版本**
- v1.0（草案）

**背景与痛点**
- 现有 Wave 支持多 workspace 与快捷键切换，但无法通过外部工具/脚本精准切换到指定 workspace。
- 外部模拟快捷键不稳定（焦点依赖、不可确定切换目标）。
- 期望保留 Wave 现有能力，最小改动增加“外部可控切换”。

---

## 一、目标与非目标

**目标**
1) 提供稳定的外部切换入口：按 workspace 名称精准切换。
2) 目标 workspace 不存在时自动创建并切换。
3) 确保单实例场景下可被外部脚本调用。
4) 允许长期维护：可以随时拉取 Wave 最新代码并自动叠加自己的 patch 进行构建。

**非目标**
- 不改动 Wave 核心终端管理逻辑。
- 不实现多实例/多进程的复杂管理。
- 不新增复杂权限系统或远程控制（仅本机 IPC）。

---

## 二、用户画像与使用场景

**目标用户**
- 重度终端用户，需要用脚本或外部工具快速切换到指定 workspace。

**关键场景**
1) AutoHotkey / PowerShell 调用 `wave.exe --switch-workspace "WorkA"` 即切换。
2) 切换时如果 Wave 未运行，自动启动并打开 WorkA。
3) 工作区名称唯一，切换不会落到错误 workspace。

---

## 三、功能需求（Functional Requirements）

### FR-1 外部切换入口（CLI）
- 新增命令行参数：
  `wave.exe --switch-workspace "<workspaceName>"`
- 若运行中实例存在：
  - 向实例发送切换命令并退出当前进程
- 若无运行实例：
  - 启动主实例并创建/打开指定 workspace

**验收**
- 任何本机外部脚本可执行上述命令完成切换。
- 若 workspace 不存在则自动创建并打开。

### FR-2 Workspace 名称规则
- Workspace 名称 **唯一**
- 名称匹配规则：
  - 默认：大小写不敏感（可在实现时确认）
- 不存在则创建，并记录名称

**验收**
- 在已存在 workspace 列表内，切换到唯一目标。
- 不存在时创建新 workspace，名称保持一致。

### FR-3 本地 IPC 通道
- 运行实例开启本机 IPC 通道（Windows 推荐 Named Pipe）
- IPC 接收 JSON 或简单文本命令：
  `{ "cmd": "switch", "name": "WorkA" }`
- 收到后触发 workspace 切换，并将窗口置前

**验收**
- IPC 可被 CLI 入口调用
- 命令被正确执行并且 UI 切换生效

### FR-4 窗口激活置前
- 切换完成后，确保窗口被置前
- 若系统限制前台激活，需有合理降级（比如闪烁任务栏）

**验收**
- 绝大多数情况下窗口被激活，用户能立即看到目标 workspace。

---

## 四、非功能需求（NFR）

1) **稳定性**：外部调用成功率 ≥ 99%（本机）
2) **性能**：切换响应 < 300ms（已运行实例）
3) **安全**：仅本机 IPC，不开放网络端口
4) **兼容性**：Windows 10/11

---

## 五、UX 交互

- CLI 无 UI 输出，静默执行
- 切换后 UI 聚焦并显示目标 workspace
- workspace 自动创建时可选 toast 提示（非必须）

---

## 六、数据与状态

- 复用 Wave 现有 workspace 存储
- 额外无需新增持久化结构
- 只新增运行态 IPC 监听

---

## 七、技术方案概要（高层）

1) **单实例逻辑**
   - 启动时判断是否已有实例
   - 若有：只负责转发命令并退出

2) **IPC**
   - Named Pipe: `\\.\pipe\wave-switch`
   - 简单请求/响应即可

3) **切换逻辑**
   - 通过现有 workspace 管理 API 切换
   - 若不存在则创建

4) **窗口置前**
   - Windows API 激活窗口（SetForegroundWindow / AttachThreadInput）

---

## 八、持续补丁构建方案（关键需求）

**目标**
- 可以随时 pull Wave 最新代码
- 自动应用自定义 patch
- 一键 build 生成自用版本

**推荐流程**
1) 保留 Wave 官方仓库为 `upstream`
2) 自己维护一个分支 `custom`
3) 通过 rebase 或 patch 叠加

**两种推荐方式**

**方式 A：Rebase 分支（最稳定）**
- `git fetch upstream`
- `git checkout custom`
- `git rebase upstream/main`
- 解决冲突后 `git push`
- 构建产物

**方式 B：Patch 文件（可脚本化）**
- 维护 patch 文件：`custom.patch`
- 每次更新：
  - `git fetch upstream`
  - `git reset --hard upstream/main`
  - `git apply custom.patch`
  - `build`

**验收**
- 任何时候 pull upstream 后可快速得到可构建版本
- 无需人工重复手工改代码

---

## 九、测试与验收

**功能验证**
- CLI 切换：
  - 存在 workspace → 切换成功
  - 不存在 → 自动创建并切换
- Wave 未运行 → 启动并打开 workspace
- 窗口置前

**回归测试**
- Wave 原有快捷键切换功能不受影响
- 多个 workspace 正常显示

---

## 十、风险与应对

- **风险**：Windows 前台激活受系统限制
  - **应对**：失败时闪烁任务栏或提示
- **风险**：Wave 内部 API 变动导致 patch 冲突
  - **应对**：补丁保持最小改动面 + 自动 rebase

---

## 十一、开放问题

1) Workspace 名称大小写是否敏感？
2) CLI 返回值与错误信息标准？
3) 目标 workspace 不存在时是否要自动创建并提示？
