# jailbreak-repo

静态越狱源（Cydia / Sileo / Zebra 通用），发布目标 GitHub Pages：
**https://unknown0actor.github.io/repo/**（仓库 `https://github.com/unknown0actor/repo.git`，Public，分支 `main` 根目录）。

项目根目录就是仓库根目录，所有路径都直接对应 Pages 上的 URL。

## 目录与文件

| 路径 | 说明 |
| --- | --- |
| `debs/*.deb` | 源里的包；内容原样，不要重新打包或改 control |
| `Packages` | 文本索引，control 字段原文 + `Filename` / `Size` / `SHA256` / `Depiction` |
| `Packages.gz` | 由 `Packages` 生成（gzip -9 -n） |
| `Release` | 源元信息 + `Packages`、`Packages.gz`、各 deb 的 MD5Sum/SHA256 与大小 |
| `index.html` | 落地页：包列表 + `sileo://source/https://unknown0actor.github.io/repo/` |
| `depictions/<Package>.html` | 每个包的简介页（标题/版本/作者/描述/截图占位） |
| `.nojekyll` | 让 GitHub Pages 原样发布，不跑 Jekyll |
| `build-repo.sh` | 一条命令全量重建上面除 `debs/` 之外的所有文件 |

`Packages.bz2` 只在设备有 `bzip2` 时才生成；本机没有 bzip2，脚本会跳过并删除陈旧文件（不留空占位）。

## 构建 / 重建

```sh
sh build-repo.sh        # 在项目根执行，可重复运行，幂等
```

脚本只用 `dpkg-deb`、`sha256sum`、`md5sum`、`gzip`、`sed`、`grep`、`tr`、`cut`、`wc`、`basename`、`mktemp`。
这台设备**没有 awk、bzip2、git、curl、python3**，脚本刻意不依赖它们。

新增包：把 `xxx.deb` 放进 `debs/` 后重跑脚本即可，`Packages`、`Release`、`depictions/`、`index.html` 一起更新。
源地址写在脚本头部 `REPO_URL`，换域名只改那里，然后重跑脚本。

两个坑（2026-10-24 实际踩过）：
- **必须在 `debs/` 目录里上传**。网页从仓库根目录上传的 deb 只是多了个文件：脚本扫的是 `debs/*.deb`，CI 只监听 `debs/**`，都不会被收录。补救办法是把根目录的 deb `mv` 进 `debs/`，重跑脚本后提交。
- **文件名用纯 ASCII**：`<Package>_<版本>_iphoneos-arm64e.deb`。中文文件名会进 `Packages` 的 `Filename` 和首页链接，客户端要 URL 编码，容易下载失败；改文件名不影响包标识（看 control 的 `Package`），不用重新打包。
  **空格尤其致命**：`Release` 的 MD5Sum/SHA256 行是「哈希 大小 路径」空格分隔，路径带空格整行错位 → 客户端 Hash Sum mismatch。脚本遇到含空格/非 ASCII 的文件名会打警告，但不会自动改名。
- **control 权限写成 0000 的 deb**：`dpkg-deb -f` 会 Permission denied（`dpkg-deb -I` 报 cannot open 'control'）。脚本的 `deb_control` 会退回自己解析 ar 成员，用 `tar xzOf`/`tar xJOf` 把 control 打到标准输出（不落盘，绕开权限位），这种包照样能收录（例：`com.25mao.leftpan_2.0-1`）。

批量改名的做法（`dpkg-deb` 读不出 control 的那个用 ar+tar 兜底，或手工按 control 内容命名）：

```sh
for f in debs/*.deb; do
	b="$(basename "$f")"
	pkg="$(dpkg-deb -f "$f" Package 2>/dev/null)"; ver="$(dpkg-deb -f "$f" Version 2>/dev/null)"
	arch="$(dpkg-deb -f "$f" Architecture 2>/dev/null)"
	[ -n "$pkg" ] && [ -n "$ver" ] || continue
	tgt="${pkg}_${ver}_${arch}.deb"; [ "$b" = "$tgt" ] && continue
	[ -e "debs/$tgt" ] || mv "$f" "debs/$tgt"
done
```

`NO_BZ2=1 sh build-repo.sh` 可强制不生成 `Packages.bz2`（本机没有 bzip2 时本来就是这行为；CI 里这样跑可与本机输出逐字节一致）。

## 零终端上传（GitHub Actions）

`.github/workflows/rebuild.yml` 会在 `debs/` 变更后于云端重建索引并自动提交回来：

1. GitHub App 或网页进入仓库 → `debs/` → Add file ▸ Upload files → 选 `.deb` → Commit changes；
2. 等约一分钟，Action 跑 `NO_BZ2=1 sh build-repo.sh` 并提交 `Packages`、`Packages.gz`、`Release`、`depictions/`、`index.html`；
3. 在 Actions 页面看绿灯即完成；`Packages`/`Release`/`index.html` 没有变化时工作流不会产生空提交。

前提：仓库 Settings ▸ Actions ▸ General 里允许 Actions（Allow all actions），且 Workflow permissions 为 Read and write。
2026-10-24 已在网页上核对并保存为 Read and write（保存成功提示：Default workflow permissions settings saved）。
若被组织策略禁止，退回本机流程：放 deb → `sh build-repo.sh` → 让 Apelin 提交推送。

设备相关的两个坑（已在脚本里处理）：dpkg 1.21 的 `dpkg-deb -f <deb> control` 只输出一个空行，要用
`dpkg-deb -f <deb>` 取整份 control 再去掉开头空行；脚本不用 awk。

## 检查过什么

- `sha256sum debs/<deb>` 与源文件 `/var/mobile/Documents/com.82flex.unseen_0.0.6_iphoneos-arm64e.deb` 一致（d4116702…1761），deb 未改动。
- 连续运行两次，`Packages`、`Packages.gz`、`Release`、`index.html`、`depictions/*.html` 哈希完全一致（幂等）。
- `gzip -t Packages.gz` 通过；`Release` 里的每个 MD5Sum/SHA256 与实际文件相符。
- 2026-10-24：提交 `376a67c` 推上 `origin/main` 后，Actions 的 `rebuild repo index` #1 与 `pages build and deployment` #4 均 completed successfully（索引未变，因此没有空提交）。
- 2026-10-24（19 个包）：`Packages` 每个条目的 `Size`/`SHA256` 与磁盘 deb 逐一比对一致，无重复 `Package`，`Release` 的 SHA256 区 21 行（`Packages`+`Packages.gz`+19 个 deb）；连续两次构建哈希一致；线上 `Packages`/`Packages.gz`/`Release`/每个 deb 与本地逐字节相同。

## 发布 / git

本设备**没有 git 可执行文件**，仓库历史只能由 Apelin 的 git 工具（`git_status` / `git_stage` / `git_commit` / `git_push` / `git_fetch`）操作：

- 凭据：github.com 的 HTTPS token 存在 Apelin keychain（Settings ▸ Git，账号 `unknown0actor`），是 classic PAT，勾选 `repo` + `workflow`，有效期到 2026-11-23。
  **推送 `.github/workflows/` 下的文件必须带 `workflow` 权限**，否则 GitHub 拒绝（refusing to allow a Personal Access Token to create or update workflow）。
  过期后按同样方式在网页新建 token，再用 `git_save_credential` 覆写，不要动 remote URL。
- 提交作者：`unknown0actor <unknown0actor@users.noreply.github.com>`。
- `git_clone` 对**空仓库**会失败（`the repository has no branch to check out`），所以首次推送前在项目根手工建了最小 `.git`
  （`HEAD` → `refs/heads/main`、`config` 里 `remote.origin.url` 与 `branch.main`、空的 `objects/`、`refs/`）；之后一切走上面的工具。
  远端已有分支时可以直接 `git_clone`，不要再手建 `.git`。
- 推送只到 `origin` 的 `main`，永不 force。`apelin-project.json` 是 Apelin 的工作区文件，不纳入仓库（保持未跟踪）。

GitHub Pages：Settings ▸ Pages ▸ Deploy from a branch ▸ `main` / root。

## 约束

- 不改 `debs/` 里已有 deb 的内容；换版本就加新文件或显式替换并说明。
- 不安装包、不 respring —— 这里产出的是要发布的仓库，不是本机要装的 tweak。
- `apelin-project.json` 是 Apelin 的工作区描述（external build），保持不动。
