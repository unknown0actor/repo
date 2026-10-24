#!/bin/sh
# 从 debs/ 全量重建静态越狱源索引：
#   Packages / Packages.gz / Packages.bz2 / Release / depictions/*.html / index.html
# 幂等：输出只取决于 debs/ 的内容；同一输入重复运行字节一致。
set -eu

cd "$(dirname "$0")"

REPO_URL="https://unknown.github.io/repo"
ORIGIN="unknown"
LABEL="unknown"
SUITE="stable"
RELEASE_VERSION="1.0"
CODENAME="ios"
ARCHS="iphoneos-arm64 iphoneos-arm64e"
COMPONENTS="main"
RELEASE_DESC="Static jailbreak deb repository, compatible with Cydia, Sileo and Zebra"

need() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "build-repo: 缺少命令 $1" >&2
		exit 1
	}
}
need dpkg-deb
need sha256sum
need md5sum
need gzip
need sed
need grep
need tr
need cut
need wc

mkdir -p debs depictions
touch .nojekyll

tmp="$(mktemp -d "${TMPDIR:-/tmp}/build-repo.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT INT TERM

esc() {
	sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

file_size() {
	wc -c < "$1" | tr -d ' '
}

: > Packages
: > "$tmp/index.cards"

count=0
for deb in debs/*.deb; do
	[ -e "$deb" ] || continue
	file="$(basename "$deb")"

	# control 字段原文：dpkg 1.21 的 `-f <deb>` 打印整个 control，
	# `-f <deb> control` 只输出一个空行，所以先取整份再去掉开头空行。
	dpkg-deb -f "$deb" > "$tmp/control"
	sed -e '/./,$!d' "$tmp/control" > "$tmp/control.clean"
	mv "$tmp/control.clean" "$tmp/control"
	if ! grep -q '^Package:' "$tmp/control"; then
		echo "build-repo: 无法读取 $deb 的 control，跳过" >&2
		continue
	fi

	pkg="$(dpkg-deb -f "$deb" Package || true)"
	[ -n "$pkg" ] || { echo "build-repo: $deb 缺少 Package 字段，跳过" >&2; continue; }
	ver="$(dpkg-deb -f "$deb" Version || true)"
	title="$(dpkg-deb -f "$deb" Name || true)"
	[ -n "$title" ] || title="$pkg"
	author="$(dpkg-deb -f "$deb" Author || true)"
	[ -n "$author" ] || author="$(dpkg-deb -f "$deb" Maintainer || true)"
	section="$(dpkg-deb -f "$deb" Section || true)"
	arch="$(dpkg-deb -f "$deb" Architecture || true)"
	short="$(dpkg-deb -f "$deb" Description 2>/dev/null | head -n 1 || true)"
	slug="$(printf '%s' "$pkg" | tr -c 'A-Za-z0-9._-' '_')"

	size="$(file_size "$deb")"
	sum="$(sha256sum "$deb" | cut -d' ' -f1)"

	# 1) Packages 条目：control 字段原样保留，后接索引字段
	{
		cat "$tmp/control"
		printf 'Filename: %s\n' "$deb"
		printf 'Size: %s\n' "$size"
		printf 'SHA256: %s\n' "$sum"
		printf 'Depiction: %s/depictions/%s.html\n' "$REPO_URL" "$slug"
		printf '\n'
	} >> Packages

	# 2) depictions/<package>.html
	title_html="$(printf '%s' "$title" | esc)"
	short_html="$(printf '%s' "$short" | esc)"
	author_html="$(printf '%s' "$author" | esc)"
	section_html="$(printf '%s' "$section" | esc)"
	desc_html="$(dpkg-deb -f "$deb" Description \
		| sed -e 's/^ \.$//' -e 's/^ //' \
		| esc \
		| while IFS= read -r line; do
			if [ -n "$line" ]; then printf '%s<br>\n' "$line"; fi
		done)"

	cat > "depictions/$slug.html" <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title_html} ${ver}</title>
<style>
body{margin:0;background:#f2f2f7;color:#1c1c1e;font:16px/1.5 -apple-system,system-ui,"PingFang SC",sans-serif}
main{max-width:640px;margin:0 auto;padding:24px 20px 48px}
h1{font-size:28px;margin:0 0 4px}
h2{font-size:18px;margin:28px 0 8px}
.sub{color:#6e6e73;margin:0 0 20px}
dl{display:grid;grid-template-columns:auto 1fr;gap:6px 16px;margin:0}
dt{color:#6e6e73}
dd{margin:0;word-break:break-all}
a{color:#0a84ff;text-decoration:none}
.desc{background:#fff;border-radius:12px;padding:14px 16px}
.shots{background:#fff;border-radius:12px;padding:14px 16px;color:#8e8e93}
.ph{display:block;text-align:center;padding:24px 0;border:1px dashed #c7c7cc;border-radius:8px}
.back{margin-top:32px;font-size:14px}
</style>
</head>
<body>
<main>
<h1>${title_html}</h1>
<p class="sub">${ver} · ${section_html} · ${arch}</p>
<dl>
<dt>标识</dt><dd>${pkg}</dd>
<dt>版本</dt><dd>${ver}</dd>
<dt>作者</dt><dd>${author_html}</dd>
<dt>架构</dt><dd>${arch}</dd>
<dt>下载</dt><dd><a href="../debs/${file}">${file}</a></dd>
</dl>
<h2>描述</h2>
<div class="desc">${desc_html}</div>
<h2>截图</h2>
<div class="shots">
<!-- 截图位置留空：把图片放进 depictions/ 后取消下面注释并改名
<img src="${slug}-1.png" alt="screenshot">
-->
<span class="ph">暂无截图</span>
</div>
<p class="back"><a href="../">← 返回源首页</a></p>
</main>
</body>
</html>
EOF

	# 3) index.html 的一张卡片
	cat >> "$tmp/index.cards" <<EOF
<section class="card">
<h2><a href="depictions/${slug}.html">${title_html}</a></h2>
<p class="meta">${ver} · ${section_html} · ${arch}</p>
<p class="desc">${short_html}</p>
<p class="dl"><a href="debs/${file}">下载 ${file}</a> · <a href="depictions/${slug}.html">详情</a></p>
</section>
EOF

	count=$((count + 1))
done

# 4) 首页
cat > index.html <<EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${LABEL} 源</title>
<style>
body{margin:0;background:#f2f2f7;color:#1c1c1e;font:16px/1.5 -apple-system,system-ui,"PingFang SC",sans-serif}
main{max-width:680px;margin:0 auto;padding:28px 20px 48px}
h1{font-size:30px;margin:0 0 6px}
.lead{color:#6e6e73;margin:0 0 20px}
.cta{display:inline-block;background:#0a84ff;color:#fff;border-radius:10px;padding:11px 18px;font-weight:600;text-decoration:none}
.url{color:#6e6e73;font-size:13px;word-break:break-all;margin:10px 0 24px}
.card{background:#fff;border-radius:14px;padding:16px 18px;margin:0 0 14px}
.card h2{font-size:20px;margin:0 0 4px}
.card h2 a{color:#1c1c1e;text-decoration:none}
.meta{color:#6e6e73;font-size:13px;margin:0 0 8px}
.desc{margin:0 0 8px}
.dl{margin:0;font-size:14px}
a{color:#0a84ff;text-decoration:none}
.empty{color:#8e8e93}
footer{color:#8e8e93;font-size:12px;margin-top:28px}
</style>
</head>
<body>
<main>
<h1>${LABEL} 源</h1>
<p class="lead">Cydia / Sileo / Zebra 通用静态源，共 ${count} 个包。</p>
<p><a class="cta" href="sileo://source/${REPO_URL}/">添加到 Sileo</a></p>
<p class="url">${REPO_URL}/</p>
EOF

if [ -s "$tmp/index.cards" ]; then
	cat "$tmp/index.cards" >> index.html
else
	printf '<p class="empty">debs/ 里还没有包。</p>\n' >> index.html
fi

cat >> index.html <<EOF
<footer>${RELEASE_DESC}</footer>
</main>
</body>
</html>
EOF

# 5) 压缩索引
gzip -9 -n -c Packages > Packages.gz
if command -v bzip2 >/dev/null 2>&1; then
	bzip2 -9 -c Packages > Packages.bz2
else
	rm -f Packages.bz2
	echo "build-repo: 设备上没有 bzip2，跳过 Packages.bz2" >&2
fi

# 6) Release
{
	printf 'Origin: %s\n' "$ORIGIN"
	printf 'Label: %s\n' "$LABEL"
	printf 'Suite: %s\n' "$SUITE"
	printf 'Version: %s\n' "$RELEASE_VERSION"
	printf 'Codename: %s\n' "$CODENAME"
	printf 'Architectures: %s\n' "$ARCHS"
	printf 'Components: %s\n' "$COMPONENTS"
	printf 'Description: %s\n' "$RELEASE_DESC"
} > Release

: > "$tmp/files"
printf 'Packages\n' >> "$tmp/files"
if [ -f Packages.gz ]; then printf 'Packages.gz\n' >> "$tmp/files"; fi
if [ -f Packages.bz2 ]; then printf 'Packages.bz2\n' >> "$tmp/files"; fi
for deb in debs/*.deb; do
	[ -e "$deb" ] || continue
	printf '%s\n' "$deb" >> "$tmp/files"
done

printf 'MD5Sum:\n' >> Release
while IFS= read -r f; do
	printf ' %s %s %s\n' "$(md5sum "$f" | cut -d' ' -f1)" "$(file_size "$f")" "$f"
done < "$tmp/files" >> Release

printf 'SHA256:\n' >> Release
while IFS= read -r f; do
	printf ' %s %s %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$(file_size "$f")" "$f"
done < "$tmp/files" >> Release

echo "build-repo: $count 个包，已重建 Packages、Packages.gz、Release、depictions/、index.html"
