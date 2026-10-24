# jailbreak-repo

静态越狱源（Cydia / Sileo / Zebra 通用），发布目标 GitHub Pages：
https://unknown.github.io/repo/ （仓库 `https://github.com/unknown/repo.git`，分支 `main`）。

项目根目录就是仓库根目录，所有路径都直接对应 Pages 上的 URL。

## 目录与文件

| 路径 | 说明 |
| --- | --- |
| `debs/*.deb` | 源里的包；内容原样，不要重新打包或改 control |
| `Packages` | 文本索引，control 字段原文 + `Filename` / `Size` / `SHA256` / `Depiction` |
| `Packages.gz` | 由 `Packages` 生成（gzip -9 -n） |
| `Release` | 源元信息 + `Packages`、`Packages.gz`、各 deb 的 MD5Sum/SHA256 与大小 |
| `index.html` | 落地页：包列表 + `sileo://source/https://unknown.github.io/repo/` |
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
源地址写在脚本头部（`REPO_URL` 等），换域名只改那里。

## 检查过什么

- `sha256sum debs/<deb>` 与源文件 `/var/mobile/Documents/com.82flex.unseen_0.0.6_iphoneos-arm64e.deb` 一致（d4116702…1761），deb 未改动。
- 连续运行两次，`Packages`、`Packages.gz`、`Release`、`index.html`、`depictions/*.html` 哈希完全一致（幂等）。
- `gzip -t Packages.gz` 通过；`Release` 里的每个 MD5Sum/SHA256 与实际文件相符。

## 发布

GitHub Pages 走 `main` 分支根目录（Settings ▸ Pages ▸ Deploy from a branch ▸ main / root）。

推送只能在 Apelin 里做，且本设备**没有 git 可执行文件**：`git init`、`git_commit`、`git_status` 都要求已有 `.git`，
`git_clone` 需要 github.com 的 HTTPS 凭据。先让用户在 Settings ▸ Git 里加 token
（或提供 token 后用 `git_save_credential` 存到 github.com），再 clone / 提交 / 推送。
不要伪造 token，也不要改远端地址。

## 约束

- 不改 `debs/` 里已有 deb 的内容；换版本就加新文件或显式替换并说明。
- 不安装包、不 respring —— 这里产出的是要发布的仓库，不是本机要装的 tweak。
- `apelin-project.json` 是 Apelin 的工作区描述（external build），保持不动。
