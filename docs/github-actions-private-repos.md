# SeiunEngine 构建流：私有仓库 + GitHub Actions + Git 全攻略

> 适用对象：想把本地改完的 SeiunEngine 推到 GitHub 私有仓库，用 GitHub Actions 自动出
> Windows / Linux / macOS 构建包，并且以后可能让构建流去拉取**另一个私有仓库**（例如
> 你自己的 hxvlc fork）。本文按“原理 → 实操 → 命令速查 → 常见坑”的顺序讲。

---

## 0. 这个仓库的构建流现在长什么样

先说结论，本仓库现在的 CI 依赖链是：

1. `hmm.json` 声明所有 haxelib 依赖（哪些来自 haxelib.org、哪些来自 git）。
2. `setup/Main.hx` 读 `hmm.json`，逐个执行 `haxelib install` / `haxelib git`。
3. `Project.xml` 里 `<classpath name="source" />` 让引擎源码排在最前面——
   所以 `source/flixel/`、`source/lime/`、`source/openfl/`、`source/hxvlc/` 里
   的同名文件会**覆盖** haxelib 里的同名类（类路径遮蔽，classpath shadowing）。
4. `lime build <平台>` 出产物，`actions/upload-artifact` 把 `export/release/<平台>/bin`
   上传为构建产物。

针对你本地的情况，neko 对仓库做了这几处修改（都还没提交，等你来 commit）：

| 文件 | 改了什么 | 为什么 |
|---|---|---|
| `hmm.json` | `hxvlc` 从 `git ./hxvlc-local` 改为 `haxelib 2.2.5` | `./hxvlc-local` 不在仓库里（你把它移出去了），CI 全新环境里根本 clone 不到，必然失败；haxelib 官方 2.2.5 自带 VLC 二进制 |
| `source/hxvlc/`（新增） | 拷入 fork 的三个补丁文件：`openfl/Video.hx`、`util/Handle.hx`、`flixel/FlxInternalVideo.hx` | 你的 fork 修了 Haxe 4.2.5 兼容问题 + 视频泄漏防护，这些改动必须跟仓库一起走；放 `source/` 遮蔽即可，不需要把整个库塞进引擎 |
| `.github/workflows/main.yml` | 重写 | 见下文“CI 里做了什么” |
| `.gitignore` | 追加 `**/.gradle/`、`.DS_Store` | `templates/` 里的 Gradle 缓存是垃圾，不该提交 |
| `docs/github-actions-private-repos.md` | 本文 | 教学 |

> ⚠️ `setup/` 和 `hmm.json` 目前都**没有被 git 跟踪**（`git ls-files` 里没有它们），
> 而 workflow 的装依赖步骤依赖 `setup/Main.hx`。**必须把它们 commit 进去**，否则 CI
> 一定在“Install haxelib dependencies”这步挂掉。

### CI 里做了什么（读一遍 workflow 就能懂）

每个平台的 job 都是同一个套路：

```text
checkout 仓库
  → 装 Haxe 4.2.5（krdlab/setup-haxe，按 hmm.json 哈希缓存 haxelib）
  → （可选）用 GH_PAT 给 git 配私有仓库鉴权
  → haxelib setup + 跑 setup/Main.hx 装依赖 + haxelib fixrepo
  → 手动拉 discord_rpc 的子模块（haxelib git 不会自动拉，实测确认）
  → 从 Project.xml 读版本号
  → lime build <平台> --app-version="版本-运行号"
  → 上传 export/release/<平台>/bin
```

几个特意做的决定：

- **macOS 只在手动触发时构建**。macOS runner 按 **10 倍**额度计费，Free 套餐私有仓库每月
  只有 2000 分钟，一次三平台全构建可能烧掉一两百分钟。想恢复“每次 push 都构建 mac”，
  删掉 `buildMac` job 上那行 `if:` 即可。
- **构建版本号自动从 Project.xml 读**，不再手写死 `0.2.1`，以后改版本不会忘同步 CI。
- **haxelib 有缓存**（`cache-dependency-path: hmm.json`），hxvlc 2.2.5 本体 600MB 左右，
  不缓存的话每个 job 每次都要重新下载。
- **产物保留 14 天**，避免把仓库的 Actions 存储占满。

---

## 1. 私有仓库能用 GitHub Actions 吗？

**能用，而且这是 GitHub 官方支持的主流程。** 很多人误以为只有公开仓库才能跑 Actions。

关键事实（按 GitHub 现行政策）：

| 项 | 公开仓库 | 私有仓库（Free 套餐） |
|---|---|---|
| Actions 额度 | 无限分钟 | 每月 **2000 分钟**（超出后按量付费或等重置） |
| 计费倍率 | 标准 runner 1× | 同上 |
| macOS runner | 10× | 10× |
| 产物/日志 | 公开可见 | 只有仓库有权限的人可见 |

怎么看自己还剩多少分钟：GitHub 网页 → 仓库 `Settings` → `Billing and plans`（或者组织级
同样的入口）。

想省额度的小技巧：

- PR 阶段只跑最快、最能说明问题的平台（比如只跑 Linux）；
- mac 这种 10 倍计费的留到手动触发；
- 依赖装好后靠缓存，别让每次 push 都重新下载 600MB；
- 频繁的小 push 会叠加消耗，可以把不重要的改动攒一攒再推。

---

## 2. GITHUB_TOKEN：Actions 默认的“临时钥匙”

每次 workflow 运行时，GitHub 会自动生成一个**只属于本次运行**的令牌 `GITHUB_TOKEN`：

- 权限范围：默认只能读写**当前仓库**（`contents: read` 之类，可在 workflow 顶部用
  `permissions:` 声明）；
- 生命周期：本次运行结束就作废；
- 用途：`actions/checkout@v4` 默认就用它 clone 当前仓库，所以你**不需要**给 checkout
  配任何账号密码，私有仓库也一样；
- 引用方式：`${{ github.token }}`。

由此推出一个结论：**“仓库本身是私有的”完全不影响 checkout**；需要额外配置的是下面这种
情况——构建流要去 clone **另一个**私有仓库。

---

## 3. 构建流里使用“另一个私有仓库”的三种姿势

场景：你把 `hxvlc-local` 推到 GitHub 的一个私有仓库（比如 `mohong2/hxvlc-local`），
`hmm.json` 里的 `url` 指向它。CI 全新环境里 `haxelib git` 本质就是 `git clone`，
没有凭证会 403。

### 姿势 A：Personal Access Token（PAT）+ git header（推荐入门）

1. 生成 PAT：
   - **Fine-grained PAT（推荐）**：GitHub 网页 → 右上角头像 → `Settings` →
     `Developer settings` → `Fine-grained tokens` → `Generate new token`。
     选 `Only select repositories` → 勾上 `hxvlc-local` → `Repository permissions` →
     `Contents` 给 `Read-only` → 生成后**只显示一次，立刻复制**。
   - 老式 Classic PAT：`Settings` → `Developer settings` → `Personal access tokens` →
     `Tokens (classic)` → 勾 `repo` 范围。权限大，能少用就少用。
2. 把令牌存进仓库 secret：`Settings` → `Secrets and variables` → `Actions` →
   `New repository secret`，名字叫 `GH_PAT`，值粘贴令牌。
3. workflow 里已经写好了鉴权步骤：检测到 `GH_PAT` 就执行

   ```bash
   git config --global http.https://github.com/.extraheader "AUTHORIZATION: basic <base64(x-access-token:PAT)>"
   ```

   这条配置让之后所有 `git clone https://github.com/...` 都带上 PAT。`haxelib git`
   克隆私有依赖时就能通过鉴权。没配 secret 时这步是空操作，不干扰公开依赖。

原理：GitHub 支持 `https://x-access-token:<令牌>@github.com/...` 这种登录方式，
把 `x-access-token:令牌` 做 base64 塞进 `Authorization` 头是 actions/checkout
同款做法。

### 姿势 B：actions/checkout 直接拉另一个私有仓库

如果某个私有仓库不是走 haxelib，而是想作为工作目录里的文件用，可以直接用 checkout
把它拉下来（`token` 指向有权限的 PAT）：

```yaml
- name: Checkout private library
  uses: actions/checkout@v4
  with:
    repository: mohong2/hxvlc-local   # 另一个私有仓库
    token: ${{ secrets.GH_PAT }}      # 这个令牌要有那个仓库的读权限
    path: deps/hxvlc-local            # 放到工作目录的哪个子目录
    ref: master
```

### 姿势 C：SSH deploy key

1. 本机生成密钥对：`ssh-keygen -t ed25519 -C "ci-hxvlc" -f ci_hxvlc`；
2. 把**公钥**（`ci_hxvlc.pub`）贴到目标私有仓库的 `Settings` → `Deploy keys` →
   `Add deploy key`（勾 `Allow write access` 与否取决于是否需要写）；
3. 把**私钥**存成 secret（名字如 `HXVLC_SSH_KEY`）；
4. workflow 里用 `webfactory/ssh-agent@v0.9.0` 载入，然后把依赖 URL 写成
   `git@github.com:mohong2/hxvlc-local.git`：

   ```yaml
   - uses: webfactory/ssh-agent@v0.9.0
     with:
       ssh-private-key: ${{ secrets.HXVLC_SSH_KEY }}
   ```

优点：只对单一仓库授权，没法读你其它仓库；缺点：要管密钥、换机器要重配。

### 姿势 D：GitHub App（进阶，暂不展开）

用 GitHub App 的 installation token，权限按 App 安装范围精确控制、令牌短期自动轮换，
适合团队/组织级流水线。个人项目用 PAT 或 deploy key 足够。

---

## 4. 实操全流程：从“本地改完”到“CI 出产物”

下面所有命令在仓库根目录的 **PowerShell** 里执行。

### 4.1 提交前：看清楚要提交什么

```powershell
git status                     # 改动清单：modified / deleted / untracked
git diff --stat                # 每个文件改了多少行（统计）
git diff .github/workflows/main.yml   # 只看某个文件的具体差异
```

对照检查单：

- ✅ 必须提交：`setup/`（整个目录）、`hmm.json`、`.github/workflows/main.yml`、
  `source/hxvlc/`、`.gitignore`、`templates/`（Android 扩展用，但里面
  `**/.gradle/` 已被忽略）、以及你所有的引擎源码/资源改动。
- ✅ 会被忽略、不会提交：`.haxelib/`（本地库，含你的 hxvlc 修改）、`export/`（构建产物）、
  `.venv/`、`.vscode/`。这是设计好的——**本地库改动靠 `source/` 里的补丁跟随仓库走**。
- ⚠️ 已删除的两个 zip（`SeiunEngine-7.2019148构建源代码.zip` 等）会在 `git add -A` 时
  记录为删除，确认你不再需要它们（它们不在 git 历史里的话就找不回来了）。
- ⚠️ `key.keystore` 和 `Project.xml` 里硬编码的证书密码 `mohong` 会被一起提交。
  仓库是私有的风险可控，但**任何**拿到仓库访问权的人都能看到密码并用它签名。
  以后做正式版发布建议把密码挪到 Actions secret（见第 6 节安全清单）。

### 4.2 提交

```powershell
git add -A                                  # 把“所有改动”放入暂存区（staging）
git status                                  # 再看一眼暂存区，确认没有奇怪的文件
git commit -m "feat: 重写构建流并提交全部 SeiunEngine 改动"
```

想分门别类提交（更干净的历史）：

```powershell
git add .github/workflows/main.yml hmm.json setup .gitignore
git commit -m "ci: 重构 GitHub Actions 构建流"

git add source/hxvlc docs/github-actions-private-repos.md
git commit -m "fix: 将 hxvlc 补丁移入 source 并补充私有仓库文档"

git add -A                                   # 剩下的所有改动
git commit -m "feat: SeiunEngine 引擎改动"
```

常用提交信息动词：`feat:` 新功能、`fix:` 修 bug、`ci:` 构建/CI、`docs:` 文档、
`refactor:` 重构。个人项目不强求，但养成习惯以后翻历史会很爽。

### 4.3 建一个私有仓库

你现在有两个选择：

**方案 1（简单）：把现有的 `mohong2/MohongEngine` 仓库改成私有**。网页进仓库 →
`Settings` → `General` → 最下面 `Danger Zone` → `Change repository visibility` →
`Private`。远端不用动，直接跳到 4.5 推送。

**方案 2（推荐给“新引擎”身份）：新建一个私有仓库**，比如 `SeiunEngine`。

网页操作：`github.com` → 右上角 `+` → `New repository` → 填名字 → 选 **Private** →
**不要**勾 `Add a README`（避免和本地冲突）→ `Create repository`。

或者装 GitHub CLI 后用命令（你机器上目前没有 `gh`）：

```powershell
winget install GitHub.cli
gh auth login                          # 浏览器授权一次
gh repo create SeiunEngine --private --source=. --remote=origin --push
```

注意 `--push` 会立刻把当前分支推上去；想先建空仓库再手动推，就把 `--push` 去掉。

### 4.4 关联远端

新建仓库后，GitHub 页面会给你一个地址。把本地的 `origin` 指过去：

```powershell
# 换成你仓库的实际地址（HTTPS 或 SSH 都行）
git remote set-url origin https://github.com/mohong2/SeiunEngine.git
git remote -v                          # 确认 origin 已经指向新地址
```

（如果不小心把远端删了，重新加：`git remote add origin <地址>`。）

### 4.5 推送

```powershell
git push -u origin main
```

`-u`（`--set-upstream`）把本地 `main` 和远端 `main` 绑定，以后直接 `git push` 就行。
第一次推送会因为你的提交量很大而需要一点时间。

如果报 `! [rejected] ... non-fast-forward`，说明远端和本地历史分叉了。**不要**
`git push --force`。先看远端是不是空仓库/别人推过东西：

```powershell
git fetch origin
git pull --rebase origin main    # 把远端提交垫到本地提交下面，再推
git push -u origin main
```

> 你自己全新创建的私有仓库一般不会遇到这个，除非 4.3 里勾了 `Add a README` 又直接
> `git push`——那种情况上面的 `pull --rebase` 就能解决。

### 4.6 看 Actions 跑、手动触发

推送成功后：

1. 仓库页点 `Actions` 标签，能看到 `Build` 工作流在跑；
2. 点进去看每个 job（Linux / Windows / macOS）的实时日志，红叉是失败，点日志定位哪一步；
3. 以后想随时手动跑：`Actions` → `Build` → 右侧 `Run workflow` → 选分支 → `Run`。

第一次跑推荐先只关注 Linux 和 Windows；mac 默认只在手动触发时跑。

### 4.7 下载构建产物

私有仓库的产物**只有有仓库访问权的人**能下载：

- 网页：`Actions` → 选中某次运行 → 底部 `Artifacts` → 点名字下载 zip；
- 命令行：

  ```powershell
  gh run download --repo mohong2/SeiunEngine    # 下载最新一次运行的所有产物
  gh run download 1234567890                     # 下载指定 run ID 的产物
  ```

### 4.8 配 secret（重要一步）

网页：`Settings` → `Secrets and variables` → `Actions` → `New repository secret`。

命令行：

```powershell
gh secret set GH_PAT
# 会提示输入值（粘贴时不会回显）
```

配好 `GH_PAT` 后，私有依赖的鉴权步骤才会真正生效。

### 4.9（可选）把 hxvlc-local 变成私有依赖

如果你更想让构建流使用**你的 hxvlc fork**（而不是官方 2.2.5 + 仓库内补丁）：

1. 把 `hxvlc-local` 推成一个私有仓库（注意它现在是干净的，但
   `FlxInternalVideo.hx` 的泄漏防护补丁目前只存在于 `.haxelib/hxvlc/git` 的工作区，
   推之前先把那个文件 commit 进去）：

   ```powershell
   cd O:\FNF-PsychEngine-0.6.3\FNF-PsychEngine-0.6.3\hxvlc-local
   git add source/hxvlc/flixel/FlxInternalVideo.hx   # 从 .haxelib/hxvlc/git 拷贝过来的那份
   git commit -m "fix: FlxInternalVideo 视频实例泄漏防护"
   # 建私有仓库并推送（网页或 gh repo create --private）
   git remote add origin https://github.com/mohong2/hxvlc-local.git
   git push -u origin master
   ```

2. 改引擎的 `hmm.json`，把 hxvlc 一项改回 git 类型：

   ```json
   {
     "name": "hxvlc",
     "type": "git",
     "url": "https://github.com/mohong2/hxvlc-local.git",
     "ref": "master"
   }
   ```

3. 在引擎仓库配好 `GH_PAT`（只读 `hxvlc-local` 的 fine-grained token）。
   本地装依赖时你机器上的 git 凭据会负责鉴权；CI 里 workflow 的鉴权步骤负责。

4. `source/hxvlc/` 里的三个补丁可以留着（内容一致，遮蔽无害），也可以删掉。

---

## 5. Git 常用命令手册（PowerShell）

### 看状态 / 看差异

```powershell
git status                # 工作区 + 暂存区状态（最常用）
git status -sb            # 精简版，附带分支跟踪信息
git diff                  # 未暂存的改动
git diff --staged         # 已暂存（准备提交）的改动
git diff --stat           # 只显示统计
git log --oneline -10     # 最近 10 条提交（一行一条）
git log --oneline --graph # 带分支图
```

### 暂存 / 提交

```powershell
git add <文件或目录>       # 把改动放进暂存区；目录会递归加入
git add -A                # 全部（含删除、新增）
git add -p                # 交互式挑片段（高级，适合把一次改动拆成多个提交）
git commit -m "消息"       # 提交暂存区内容
git commit -am "消息"      # 跳过 git add，直接提交“已跟踪文件”的改动（新文件不生效）
```

### 推送 / 拉取

```powershell
git push                  # 推当前分支到已绑定的远端
git push -u origin main   # 首次推送并绑定
git pull                  # 拉取并合并远端（= fetch + merge）
git pull --rebase         # 拉取并把本地提交“垫”到远端之后（历史更干净）
git fetch                 # 只更新远端快照，不合并（先看看再说）
git fetch --prune         # 顺手清掉远端已删除的分支引用
```

### 分支

```powershell
git branch                # 列出本地分支
git branch <名字>          # 新建分支
git switch <名字>          # 切换分支（git checkout <名字> 也行）
git switch -c <名字>       # 新建并切换
git merge <分支>           # 把分支合并进当前分支
git branch -d <分支>       # 删除已合并的分支（-D 强制删，慎用）
```

### 撤销 / 回滚（按危险程度从低到高）

```powershell
git restore <文件>         # 丢弃工作区里某个文件的改动（未提交的改动会丢，谨慎）
git restore --staged <文件> # 把文件从暂存区撤回（内容不动）
git commit --amend -m "新消息" # 改写上一次提交的消息（已推送的提交别 amend）
git reset --soft HEAD~1    # 撤销上一次提交，改动保留在暂存区
git reset --hard HEAD~1    # 撤销提交并丢弃改动（危险！不可恢复）
git tag v0.2.1             # 打标签
git tag -d v0.2.1          # 删标签
git push origin v0.2.1     # 推送标签
```

> 黄金法则：**已经推送到远端的提交，不要 reset/amend/force-push**。个人私有仓库你
> 说了算，但一旦多人协作，重写历史会让大家都很痛苦。

### 仓库信息 / 清理

```powershell
git remote -v              # 看远端地址
git config user.name       # 看提交者名字
git config user.email      # 看提交者邮箱
git clean -nd              # 预览会被删除的未跟踪文件（-n 是试运行！）
git clean -fd              # 真的删除未跟踪文件（危险，先跑上面那条）
```

---

## 6. 安全清单

- **secret 只进 Actions secret，永远不写进代码/文档/commit**。日志里如果出现令牌，
  立刻去 GitHub 把它 revoke 并重新生成。
- **PAT 权限最小化**：fine-grained token 只勾目标仓库的 `Contents: Read-only`；
  classic token 的 `repo` 权限是“全家桶”，尽量别用。
- **`key.keystore` 与硬编码密码**：现在是 `mohong` 明文躺在 `Project.xml` 里。
  私有仓库里还能忍，但建议：把密码移到 secret，`Project.xml` 用占位符，CI 里用
  `-Dcertificate-password=...` 或环境变量注入。至少要知道“仓库里的密码不是秘密”。
- **私有 ≠ 保险**：私有仓库的协作者、被 fork 的私有副本（如果允许 fork）、以及
  泄漏的 PAT 都能看到代码。机密（音乐包未发布素材、密钥）别指望靠“私有”二字兜底。
- **大文件**：GitHub 单文件超 50MB 会警告、超 100MB 直接拒绝。neko 查过，这个仓库
  当前没有超 50MB 的文件。以后往 `assets/` 塞视频/音频时注意，超了要用
  Git LFS 或放到发布包（Release）里。
- **fork PR 拿不到 secret**：被 fork 的私有仓库里，外部 fork 的 PR 不会拿到任何
  secret。个人项目影响不大，知道有这个限制就行。

---

## 7. 常见问题 FAQ

**Q：Actions 页面是空的，workflow 不跑。**
A：先确认文件在 `.github/workflows/` 目录且已提交；再看有没有语法错误（YAML 缩进、
`on` 写成 `one` 之类）。推送后 5 秒内 Actions 页应该出现新 run。

**Q：报错 `Could not resolve dependency: hxvlc` 或 clone 失败。**
A：确认 `setup/` 和 `hmm.json` 已提交；如果依赖是私有仓库，确认 `GH_PAT` secret 已配
且 PAT 对目标仓库有读权限（403 基本就是权限问题）。

**Q：报错找不到 `rapidjson` / discord_rpc 编译失败。**
A：确认“Init discord_rpc submodules”步骤执行成功（它拉 `rapidjson` 和
`discord-rpc` 两个子模块，`haxelib git` 不自动拉）。

**Q：artifact 下载 404 或看不到。**
A：私有仓库产物只有有权限的人能下。确认登录的是仓库 owner/协作者；过期产物
（默认 90 天，本 workflow 设了 14 天）也会消失。

**Q：私有依赖 clone 403。**
A：`GH_PAT` 没配 / PAT 过期 / PAT 没勾目标仓库。去
`Developer settings` → `Fine-grained tokens` 检查有效期与权限。

**Q：本月 Actions 分钟用完了。**
A：`Settings` → `Billing and plans` 看明细；临时方案是把 mac job 关掉、减少 push
频率；长期方案是升级套餐或把构建改成本地/自托管 runner（自托管不扣额度，但要自己维护机器）。

**Q：`git push` 报 `non-fast-forward`。**
A：见 4.5，先 `git pull --rebase origin main` 再推，别 force。

**Q：commit 后想改提交信息。**
A：还没推：`git commit --amend -m "新消息"`。已推送：别 amend，直接再提交一次即可。

**Q：改了 `.gitignore` 但文件还在 git status 里。**
A：`.gitignore` 只管**未跟踪**文件；已被跟踪的文件要
`git rm --cached <文件>`（保留磁盘文件，只解除跟踪）才会被忽略。

---

## 8. 下一步建议

1. 按第 4 节走一遍：审阅 → 提交 → 建私有仓库 → 推送 → 看 Actions 绿。
2. 第一次构建成功后，把产物下载下来和本地 `export/release/windows/bin` 对比验证行为一致。
3. 想真正用私有 hxvlc fork 再按 4.9 操作；不折腾也完全没问题（补丁已在仓库里）。
4. 有需要再给 CI 加 Android job（需要 Java 11 + Android SDK + 签名 secret），
   neko 可以下次帮你整。
