#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export TZ=UTC
umask 077

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly asset_source="${project_root}/.wordpress-org"

usage() {
	cat <<'USAGE'
Usage: scripts/deploy-wordpress-svn.sh --zip PATH --version X.Y.Z [OPTIONS]

Required:
  --zip PATH          Strictly validated release candidate ZIP.
  --version X.Y.Z     Normalized plugin version.

Options:
  --slug SLUG         WordPress.org slug (default: wp-site-options).
  --svn-url URL       Exact official plugin URL or a local file:/// URL.
  --dry-run           Prepare and verify a fresh working copy without commit.
  -h, --help          Show this help.

Official commits require WPORG_USERNAME and WPORG_PASSWORD. The password is
read by svn from standard input and is never passed in argv or cached.
USAGE
}

fail() {
	printf 'WordPress.org SVN deploy failed: %s\n' "$*" >&2
	exit 1
}

zip_path=''
version=''
slug='wp-site-options'
svn_url=''
dry_run=false
seen_zip=false
seen_version=false
seen_slug=false
seen_svn_url=false

while (( $# > 0 )); do
	case "$1" in
		--zip)
			[[ "${seen_zip}" == false ]] || fail '--zip may be specified only once'
			(( $# >= 2 )) || fail '--zip requires a path'
			zip_path="$2"
			seen_zip=true
			shift 2
			;;
		--version)
			[[ "${seen_version}" == false ]] || fail '--version may be specified only once'
			(( $# >= 2 )) || fail '--version requires X.Y.Z'
			version="$2"
			seen_version=true
			shift 2
			;;
		--slug)
			[[ "${seen_slug}" == false ]] || fail '--slug may be specified only once'
			(( $# >= 2 )) || fail '--slug requires a value'
			slug="$2"
			seen_slug=true
			shift 2
			;;
		--svn-url)
			[[ "${seen_svn_url}" == false ]] || fail '--svn-url may be specified only once'
			(( $# >= 2 )) || fail '--svn-url requires a URL'
			svn_url="$2"
			seen_svn_url=true
			shift 2
			;;
		--dry-run)
			[[ "${dry_run}" == false ]] || fail '--dry-run may be specified only once'
			dry_run=true
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			fail 'unknown argument'
			;;
	esac
done

[[ "${seen_zip}" == true ]] || fail '--zip is required'
[[ "${seen_version}" == true ]] || fail '--version is required'
[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail '--version must be normalized X.Y.Z'
[[ "${slug}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail '--slug must contain lowercase ASCII letters, digits, and single hyphens'

for command_name in git svn unzip python3 realpath mktemp; do
	command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

[[ "${zip_path}" != *'\'* && ! "${zip_path}" =~ [[:cntrl:]] ]] || fail 'ZIP path contains unsafe characters'
[[ -f "${zip_path}" && ! -L "${zip_path}" ]] || fail 'ZIP is not a regular file'
zip_path="$(realpath -- "${zip_path}")"
[[ -d "${asset_source}" && ! -L "${asset_source}" ]] || fail '.wordpress-org must be a real directory'

readonly official_url="https://plugins.svn.wordpress.org/${slug}"
if [[ -z "${svn_url}" ]]; then
	svn_url="${official_url}"
fi

official_mode=false
if [[ "${svn_url}" == "${official_url}" ]]; then
	official_mode=true
elif [[ "${svn_url}" =~ ^file:///[^%?#[:space:]\\]+$ ]]; then
	local_svn_path="${svn_url#file://}"
	[[ "${local_svn_path}" =~ ^/[A-Za-z0-9._/-]+$ ]] || fail 'local file:/// URL path must use safe ASCII characters'
	[[ "${local_svn_path}" == /* && "${local_svn_path}" != *'//'* ]] || fail 'local file:/// URL must contain one normalized absolute path'
	IFS='/' read -r -a local_svn_components <<< "${local_svn_path#/}"
	for local_svn_component in "${local_svn_components[@]}"; do
		[[ -n "${local_svn_component}" && "${local_svn_component}" != '.' && "${local_svn_component}" != '..' ]] || fail 'local file:/// URL must not contain empty or dot path segments'
	done
else
	fail "--svn-url must be exactly ${official_url} or a local file:/// URL without escapes, query, or fragment"
fi
if [[ "${official_mode}" == true && "${slug}" != 'wp-site-options' ]]; then
	fail 'official deployment is restricted to the wp-site-options slug'
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/wpso-svn-deploy.XXXXXX")"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

validate_tree_assets() {
	python3 - "${asset_source}" <<'PY'
import os
import re
import stat
import sys
import unicodedata

root = sys.argv[1]
allowed = {
    ".gif": ("image/gif", (b"GIF87a", b"GIF89a")),
    ".jpeg": ("image/jpeg", (b"\xff\xd8\xff",)),
    ".jpg": ("image/jpeg", (b"\xff\xd8\xff",)),
    ".png": ("image/png", (b"\x89PNG\r\n\x1a\n",)),
    ".webp": ("image/webp", (b"RIFF",)),
}


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: unsafe .wordpress-org assets: {message}")


names = set()
file_count = 0
for entry in os.scandir(root):
    name = entry.name
    if name != unicodedata.normalize("NFC", name):
        reject(f"non-NFC name {name!r}")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", name):
        reject(f"unsafe name {name!r}")
    folded = name.casefold()
    if folded in names:
        reject(f"case-colliding name {name!r}")
    names.add(folded)

    info = entry.stat(follow_symlinks=False)
    if not stat.S_ISREG(info.st_mode):
        reject(f"non-regular or nested entry {name!r}")
    if info.st_size <= 0 or info.st_size > 10 * 1024 * 1024:
        reject(f"invalid size for {name!r}")

    extension = os.path.splitext(name)[1].lower()
    if extension not in allowed:
        reject(f"unsupported image extension for {name!r}")
    with open(entry.path, "rb") as image:
        header = image.read(12)
    signatures = allowed[extension][1]
    if not any(header.startswith(signature) for signature in signatures):
        reject(f"signature does not match extension for {name!r}")
    if extension == ".webp" and header[8:12] != b"WEBP":
        reject(f"invalid WebP signature for {name!r}")
    file_count += 1

if file_count == 0:
    reject("asset directory is empty")
PY
}

compare_or_sync_tree() {
	local operation="$1"
	local source_root="$2"
	local target_root="$3"
	local label="$4"

	python3 - "${operation}" "${source_root}" "${target_root}" "${label}" <<'PY'
import filecmp
import os
import shutil
import stat
import sys
import unicodedata

operation, source_root, target_root, label = sys.argv[1:]


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: {label}: {message}")


def inspect(root):
    if not os.path.isdir(root) or os.path.islink(root):
        reject("tree root is missing, not a directory, or a symlink")
    result = {}
    folded = set()
    for current, directories, files in os.walk(root, topdown=True, followlinks=False):
        directories.sort(key=os.fsencode)
        files.sort(key=os.fsencode)
        for name in directories + files:
            path = os.path.join(current, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            if relative != unicodedata.normalize("NFC", relative):
                reject(f"non-NFC path {relative!r}")
            if (
                "\\" in relative
                or ":" in relative
                or any(ord(character) < 32 or ord(character) == 127 for character in relative)
                or any(component in {"", ".", "..", ".svn"} for component in relative.split("/"))
            ):
                reject(f"unsafe path {relative!r}")
            normalized = unicodedata.normalize("NFC", relative).casefold()
            if normalized in folded:
                reject(f"case-colliding path {relative!r}")
            folded.add(normalized)

            info = os.lstat(path)
            if stat.S_ISDIR(info.st_mode):
                result[relative] = "directory"
            elif stat.S_ISREG(info.st_mode):
                result[relative] = "file"
            else:
                reject(f"symlink or special entry {relative!r}")
    return result


source = inspect(source_root)
target = inspect(target_root)

if operation == "compare":
    if source != target:
        missing = sorted(set(source) - set(target), key=os.fsencode)
        unexpected = sorted(set(target) - set(source), key=os.fsencode)
        changed_kind = sorted(
            (path for path in set(source) & set(target) if source[path] != target[path]),
            key=os.fsencode,
        )
        reject(
            f"manifest differs; missing={missing!r}, unexpected={unexpected!r}, "
            f"changed_kind={changed_kind!r}"
        )
    for relative, kind in source.items():
        if kind == "file" and not filecmp.cmp(
            os.path.join(source_root, relative),
            os.path.join(target_root, relative),
            shallow=False,
        ):
            reject(f"file bytes differ: {relative!r}")
    raise SystemExit(0)

if operation != "sync":
    reject(f"unknown tree operation {operation!r}")

remove = [
    relative
    for relative, kind in target.items()
    if relative not in source or source.get(relative) != kind
]
for relative in sorted(remove, key=lambda path: (path.count("/"), os.fsencode(path)), reverse=True):
    path = os.path.join(target_root, relative)
    if os.path.isdir(path) and not os.path.islink(path):
        os.rmdir(path)
    else:
        os.unlink(path)

for relative, kind in sorted(source.items(), key=lambda item: (item[0].count("/"), os.fsencode(item[0]))):
    source_path = os.path.join(source_root, relative)
    target_path = os.path.join(target_root, relative)
    if kind == "directory":
        os.makedirs(target_path, mode=0o755, exist_ok=True)
        os.chmod(target_path, 0o755)
        continue
    os.makedirs(os.path.dirname(target_path), mode=0o755, exist_ok=True)
    if not os.path.isfile(target_path) or not filecmp.cmp(source_path, target_path, shallow=False):
        shutil.copyfile(source_path, target_path)
    os.chmod(target_path, 0o644)
PY
}

schedule_svn_changes() {
	local working_copy="$1"
	local status_xml="${work_dir}/schedule-status.xml"

	svn status --xml --no-ignore "${working_copy}" > "${status_xml}"
	python3 - "${working_copy}" "${version}" "${status_xml}" <<'PY'
import os
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET

working_copy, version, xml_path = sys.argv[1:]
working_copy = os.path.abspath(working_copy)


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: cannot schedule SVN changes: {message}")


def relative_path(raw):
    absolute = os.path.abspath(raw if os.path.isabs(raw) else os.path.join(os.getcwd(), raw))
    try:
        common = os.path.commonpath((working_copy, absolute))
    except ValueError:
        reject("status path is outside the working copy")
    if common != working_copy:
        reject("status path is outside the working copy")
    relative = os.path.relpath(absolute, working_copy).replace(os.sep, "/")
    if relative in {"", "."}:
        reject("working-copy root must not change")
    if (
        relative != unicodedata.normalize("NFC", relative)
        or "\\" in relative
        or ":" in relative
        or any(ord(character) < 32 or ord(character) == 127 for character in relative)
        or any(component in {"", ".", ".."} for component in relative.split("/"))
    ):
        reject("unsafe status path")
    allowed = (
        relative in {"trunk", "assets", "tags"}
        or relative.startswith("trunk/")
        or relative.startswith("assets/")
        or relative == f"tags/{version}"
        or relative.startswith(f"tags/{version}/")
    )
    if not allowed:
        reject(f"change outside managed paths: {relative}")
    return relative, absolute


tree = ET.parse(xml_path)
unversioned = []
missing = []
for entry in tree.findall(".//entry"):
    relative, absolute = relative_path(entry.attrib.get("path", ""))
    status = entry.find("wc-status")
    if status is None:
        reject(f"missing wc-status for {relative}")
    item = status.attrib.get("item", "")
    props = status.attrib.get("props", "none")
    if status.attrib.get("tree-conflicted") == "true" or item in {
        "conflicted", "obstructed", "external", "incomplete", "ignored",
    } or props == "conflicted":
        reject(f"unsafe status {item}/{props} for {relative}")
    if item == "unversioned":
        unversioned.append((relative, absolute))
    elif item == "missing":
        missing.append((relative, absolute))


def topmost(entries):
    selected = []
    for relative, absolute in sorted(entries, key=lambda item: (item[0].count("/"), os.fsencode(item[0]))):
        if any(relative == parent or relative.startswith(parent + "/") for parent, _ in selected):
            continue
        selected.append((relative, absolute))
    return selected


for _, absolute in topmost(missing):
    subprocess.run(
        ["svn", "delete", "--force", "--", absolute],
        check=True,
        stdout=subprocess.DEVNULL,
    )
for _, absolute in topmost(unversioned):
    subprocess.run(
        [
            "svn", "add", "--force", "--parents", "--no-auto-props",
            "--no-ignore", "--", absolute,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )
PY
}

normalize_svn_properties() {
	local working_copy="$1"
	local trunk_path="$2"
	local assets_path="$3"

	python3 - "${working_copy}" "${trunk_path}" "${assets_path}" <<'PY'
import os
import subprocess
import sys

working_copy, trunk_path, assets_path = sys.argv[1:]
mime_types = {
    ".gif": "image/gif",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


def svn(*arguments, capture=False):
    return subprocess.run(
        ["svn", *arguments],
        check=False,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def remove_property(name, path):
    result = svn("propget", "--strict", name, path, capture=True)
    if result.returncode == 0:
        deleted = svn("propdel", name, path)
        if deleted.returncode != 0:
            raise SystemExit(f"WordPress.org SVN deploy failed: could not remove {name}")
    elif result.returncode != 1:
        raise SystemExit(f"WordPress.org SVN deploy failed: could not inspect {name}")


for root in (trunk_path, assets_path):
    for current, directories, files in os.walk(root):
        paths = [current]
        paths.extend(os.path.join(current, name) for name in directories)
        paths.extend(os.path.join(current, name) for name in files)
        for path in paths:
            remove_property("svn:externals", path)
        for path in (os.path.join(current, name) for name in files):
            remove_property("svn:eol-style", path)
            remove_property("svn:keywords", path)
            remove_property("svn:executable", path)

for current, _, files in os.walk(trunk_path):
    for name in files:
        if name.lower().endswith(".mo"):
            path = os.path.join(current, name)
            result = svn("propset", "svn:mime-type", "application/octet-stream", path)
            if result.returncode != 0:
                raise SystemExit("WordPress.org SVN deploy failed: could not set .mo MIME type")

for entry in os.scandir(assets_path):
    extension = os.path.splitext(entry.name)[1].lower()
    mime_type = mime_types[extension]
    result = svn("propset", "svn:mime-type", mime_type, entry.path)
    if result.returncode != 0:
        raise SystemExit("WordPress.org SVN deploy failed: could not set asset MIME type")
PY
}

validate_exact_properties() {
	local tree_path="$1"
	local tree_kind="$2"
	local tree_label="$3"

	python3 - "${tree_path}" "${tree_kind}" "${tree_label}" <<'PY'
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

tree_path, tree_kind, tree_label = sys.argv[1:]
tree_path = os.path.abspath(tree_path)
mime_types = {
    ".gif": "image/gif",
    ".jpeg": "image/jpeg",
    ".jpg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: {tree_label} property policy: {message}")


if tree_kind not in {"plugin", "assets"}:
    reject("unknown tree kind")

expected = {}
for current, _, files in os.walk(tree_path):
    for name in files:
        path = os.path.join(current, name)
        relative = os.path.relpath(path, tree_path).replace(os.sep, "/")
        if tree_kind == "plugin" and name.lower().endswith(".mo"):
            expected[relative] = {"svn:mime-type": "application/octet-stream"}
        elif tree_kind == "assets":
            extension = os.path.splitext(name)[1].lower()
            if extension not in mime_types:
                reject(f"unsupported asset extension at {relative}")
            expected[relative] = {"svn:mime-type": mime_types[extension]}

result = subprocess.run(
    ["svn", "proplist", "--xml", "--verbose", "-R", tree_path],
    check=False,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if result.returncode != 0:
    reject("could not read recursive properties")

actual = {}
for target in ET.fromstring(result.stdout).findall("target"):
    raw_path = target.attrib.get("path", "")
    absolute = os.path.abspath(raw_path if os.path.isabs(raw_path) else os.path.join(os.getcwd(), raw_path))
    try:
        common = os.path.commonpath((tree_path, absolute))
    except ValueError:
        reject("property target is outside the managed tree")
    if common != tree_path:
        reject("property target is outside the managed tree")
    relative = os.path.relpath(absolute, tree_path).replace(os.sep, "/")
    properties = {}
    for prop in target.findall("property"):
        name = prop.attrib.get("name", "")
        if not name or name in properties:
            reject(f"invalid or duplicate property at {relative}")
        properties[name] = prop.text or ""
    if properties:
        actual[relative] = properties

if actual != expected:
    missing = sorted(set(expected) - set(actual), key=os.fsencode)
    unexpected = sorted(set(actual) - set(expected), key=os.fsencode)
    changed = sorted(
        (path for path in set(actual) & set(expected) if actual[path] != expected[path]),
        key=os.fsencode,
    )
    reject(
        f"properties differ; missing={missing!r}, unexpected={unexpected!r}, "
        f"changed={changed!r}"
    )
PY
}

validate_and_report_status() {
	local working_copy="$1"
	local existing_tag="$2"
	local label="$3"
	local status_xml="${work_dir}/final-status.xml"
	local count_file="${work_dir}/delta-count"

	svn status --xml --no-ignore "${working_copy}" > "${status_xml}"
	python3 - "${working_copy}" "${version}" "${existing_tag}" "${label}" "${status_xml}" "${count_file}" <<'PY'
import os
import sys
import unicodedata
import xml.etree.ElementTree as ET

working_copy, version, existing_tag, label, xml_path, count_path = sys.argv[1:]
working_copy = os.path.abspath(working_copy)
allowed_items = {"added": "A", "deleted": "D", "modified": "M", "replaced": "R"}
counts = {name: 0 for name in allowed_items}
property_count = 0
changes = []


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: unsafe final SVN status: {message}")


for entry in ET.parse(xml_path).findall(".//entry"):
    raw = entry.attrib.get("path", "")
    absolute = os.path.abspath(raw if os.path.isabs(raw) else os.path.join(os.getcwd(), raw))
    try:
        common = os.path.commonpath((working_copy, absolute))
    except ValueError:
        reject("path outside working copy")
    if common != working_copy:
        reject("path outside working copy")
    relative = os.path.relpath(absolute, working_copy).replace(os.sep, "/")
    if relative in {"", "."}:
        reject("working-copy root changed")
    if (
        relative != unicodedata.normalize("NFC", relative)
        or "\\" in relative
        or ":" in relative
        or any(ord(character) < 32 or ord(character) == 127 for character in relative)
        or any(component in {"", ".", ".."} for component in relative.split("/"))
    ):
        reject("unsafe relative path")
    allowed = (
        relative in {"trunk", "assets", "tags"}
        or relative.startswith("trunk/")
        or relative.startswith("assets/")
        or relative == f"tags/{version}"
        or relative.startswith(f"tags/{version}/")
    )
    if not allowed:
        reject(f"change outside managed paths: {relative}")

    status = entry.find("wc-status")
    if status is None:
        reject(f"missing wc-status for {relative}")
    item = status.attrib.get("item", "")
    props = status.attrib.get("props", "none")
    if status.attrib.get("tree-conflicted") == "true" or status.attrib.get("switched") == "true":
        reject(f"tree conflict or switch at {relative}")
    if props not in {"none", "modified"}:
        reject(f"property status {props!r} at {relative}")
    if item == "normal":
        if props != "modified":
            reject(f"unchanged status entry at {relative}")
        marker = "-P"
    elif item in allowed_items:
        counts[item] += 1
        marker = allowed_items[item] + ("P" if props == "modified" else "-")
    else:
        reject(f"item status {item!r} at {relative}")
    if existing_tag == "true" and (relative == f"tags/{version}" or relative.startswith(f"tags/{version}/")):
        reject("existing release tag would be modified")

    if props == "modified":
        property_count += 1
    changes.append((relative.encode("utf-8"), marker, relative))

with open(count_path, "w", encoding="ascii") as count_file:
    count_file.write(str(len(changes)))

print(f"{label} SVN status (sanitized relative paths):")
if not changes:
    print("  clean")
for _, marker, relative in sorted(changes):
    print(f"  {marker} {relative}")
print(
    "SVN delta counts: "
    + " ".join(f"{name}={counts[name]}" for name in ("added", "modified", "deleted", "replaced"))
    + f" property_modified={property_count} total={len(changes)}"
)
PY

	SVN_DELTA_COUNT="$(<"${count_file}")"
	[[ "${SVN_DELTA_COUNT}" =~ ^[0-9]+$ ]] || fail 'invalid internal SVN delta count'
}

validate_remote_freshness() {
	local working_copy="$1"
	local managed_xml="${work_dir}/fresh-managed.xml"
	local tags_xml="${work_dir}/fresh-tags.xml"

	svn status --show-updates --verbose --xml --no-ignore --non-interactive --no-auth-cache \
		"${working_copy}/trunk" "${working_copy}/assets" "${working_copy}/tags/${version}" > "${managed_xml}" || fail 'could not check managed paths against repository HEAD'
	svn status --show-updates --verbose --xml --no-ignore --depth empty --non-interactive --no-auth-cache \
		"${working_copy}/tags" > "${tags_xml}" || fail 'could not check tags ancestor against repository HEAD'

	python3 - "${working_copy}" "${version}" "${managed_xml}" "${tags_xml}" <<'PY'
import os
import sys
import unicodedata
import xml.etree.ElementTree as ET

working_copy, version, managed_xml, tags_xml = sys.argv[1:]
working_copy = os.path.abspath(working_copy)


def reject(message):
    raise SystemExit(f"WordPress.org SVN deploy failed: stale SVN working copy: {message}")


def checked_relative(raw):
    absolute = os.path.abspath(raw if os.path.isabs(raw) else os.path.join(os.getcwd(), raw))
    try:
        common = os.path.commonpath((working_copy, absolute))
    except ValueError:
        reject("status path is outside the working copy")
    if common != working_copy:
        reject("status path is outside the working copy")
    relative = os.path.relpath(absolute, working_copy).replace(os.sep, "/")
    if (
        relative in {"", "."}
        or relative != unicodedata.normalize("NFC", relative)
        or "\\" in relative
        or ":" in relative
        or any(ord(character) < 32 or ord(character) == 127 for character in relative)
        or any(component in {"", ".", ".."} for component in relative.split("/"))
    ):
        reject("unsafe status path")
    return relative


seen_roots = set()
for xml_path, tags_ancestor_only in ((managed_xml, False), (tags_xml, True)):
    for entry in ET.parse(xml_path).findall(".//entry"):
        relative = checked_relative(entry.attrib.get("path", ""))
        if tags_ancestor_only:
            if relative != "tags":
                reject(f"unexpected tags-ancestor status path: {relative}")
            seen_roots.add("tags")
        else:
            allowed = (
                relative in {"trunk", "assets"}
                or relative.startswith("trunk/")
                or relative.startswith("assets/")
                or relative == f"tags/{version}"
                or relative.startswith(f"tags/{version}/")
            )
            if not allowed:
                reject(f"path outside expected managed roots: {relative}")
            if relative == "trunk" or relative.startswith("trunk/"):
                seen_roots.add("trunk")
            elif relative == "assets" or relative.startswith("assets/"):
                seen_roots.add("assets")
            else:
                seen_roots.add("target-tag")

        repository_status = entry.find("repos-status")
        if repository_status is None:
            continue
        repository_item = repository_status.attrib.get("item", "none")
        repository_props = repository_status.attrib.get("props", "none")
        if repository_item != "none" or repository_props != "none":
            reject(
                f"remote delta {repository_item}/{repository_props} at {relative}"
            )

required_roots = {"trunk", "assets", "target-tag", "tags"}
if seen_roots != required_roots:
    reject(f"freshness response omitted managed roots: {sorted(required_roots - seen_roots)!r}")
PY
}

validate_tree_assets

cd "${project_root}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 'project root is not a Git worktree'
if [[ "${official_mode}" == true ]]; then
	asset_status="$(git status --porcelain=v1 --untracked-files=all -- .wordpress-org)"
	[[ -z "${asset_status}" ]] || fail '.wordpress-org must be clean for an official deployment'
	git ls-files -z -- .wordpress-org > "${work_dir}/tracked-assets"
	python3 - "${asset_source}" "${work_dir}/tracked-assets" <<'PY'
import os
import sys

asset_root, tracked_path = sys.argv[1:]
with open(tracked_path, "rb") as tracked_file:
    tracked = set()
    prefix = ".wordpress-org/"
    for value in tracked_file.read().split(b"\0"):
        if not value:
            continue
        path = value.decode("utf-8")
        if not path.startswith(prefix):
            raise SystemExit("WordPress.org SVN deploy failed: invalid tracked asset path")
        tracked.add(path[len(prefix):])
actual = {entry.name for entry in os.scandir(asset_root)}
if tracked != actual:
    raise SystemExit("WordPress.org SVN deploy failed: .wordpress-org must contain only tracked files")
PY
fi

"${script_dir}/validate-release-zip.sh" "${zip_path}" "${version}"
unzip -q "${zip_path}" -d "${work_dir}/candidate"
candidate_root="${work_dir}/candidate/wp-site-options"
[[ -d "${candidate_root}" && ! -L "${candidate_root}" ]] || fail 'validated candidate root is unavailable after extraction'

working_copy="${work_dir}/svn"
svn checkout --quiet --ignore-externals --non-interactive --no-auth-cache "${svn_url}" "${working_copy}" || fail 'fresh SVN checkout failed'
initial_revision="$(svn info --show-item revision "${working_copy}")"
[[ "${initial_revision}" =~ ^[0-9]+$ ]] || fail 'could not determine initial SVN revision'
repository_uuid="$(svn info --show-item repos-uuid "${working_copy}")"
[[ -n "${repository_uuid}" && ! "${repository_uuid}" =~ [[:cntrl:]] ]] || fail 'could not determine a safe SVN repository UUID'
if [[ "${official_mode}" == true && "${repository_uuid}" != 'b8457f37-d9ea-0310-8a92-e5e31aec5664' ]]; then
	fail 'official WordPress.org SVN repository UUID mismatch'
fi

for managed_name in trunk assets tags; do
	managed_path="${working_copy}/${managed_name}"
	if [[ -e "${managed_path}" || -L "${managed_path}" ]]; then
		[[ -d "${managed_path}" && ! -L "${managed_path}" ]] || fail "managed SVN path is obstructed: ${managed_name}"
		svn info "${managed_path}" >/dev/null 2>&1 || fail "managed SVN path is not versioned: ${managed_name}"
	else
		mkdir -- "${managed_path}"
	fi
done

tag_path="${working_copy}/tags/${version}"
tag_exists=false
if [[ -e "${tag_path}" || -L "${tag_path}" ]]; then
	[[ -d "${tag_path}" && ! -L "${tag_path}" ]] || fail "existing tags/${version} is obstructed"
	svn info "${tag_path}" >/dev/null 2>&1 || fail "existing tags/${version} is not versioned"
	compare_or_sync_tree compare "${candidate_root}" "${tag_path}" "existing tags/${version} differs from candidate"
	validate_exact_properties "${tag_path}" plugin "existing tags/${version}"
	tag_exists=true
fi

compare_or_sync_tree sync "${candidate_root}" "${working_copy}/trunk" 'cannot sync candidate to trunk'
compare_or_sync_tree sync "${asset_source}" "${working_copy}/assets" 'cannot sync canonical assets'
schedule_svn_changes "${working_copy}"
normalize_svn_properties "${working_copy}" "${working_copy}/trunk" "${working_copy}/assets"
validate_exact_properties "${working_copy}/trunk" plugin 'synced trunk'
validate_exact_properties "${working_copy}/assets" assets 'synced assets'

compare_or_sync_tree compare "${candidate_root}" "${working_copy}/trunk" 'synced trunk differs from candidate'
compare_or_sync_tree compare "${asset_source}" "${working_copy}/assets" 'synced assets differ from canonical assets'

if [[ "${tag_exists}" == false ]]; then
	svn copy --quiet "${working_copy}/trunk" "${tag_path}" || fail "could not create local tags/${version} copy"
fi

compare_or_sync_tree compare "${candidate_root}" "${tag_path}" "tags/${version} differs from candidate"
validate_exact_properties "${tag_path}" plugin "tags/${version}"

status_label='Candidate'
if [[ "${dry_run}" == true ]]; then
	status_label='Dry-run'
fi
SVN_DELTA_COUNT=0
validate_and_report_status "${working_copy}" "${tag_exists}" "${status_label}"
validate_remote_freshness "${working_copy}"

if [[ "${dry_run}" == true ]]; then
	final_revision="$(svn info --show-item revision "${working_copy}")"
	[[ "${final_revision}" == "${initial_revision}" ]] || fail 'dry-run changed the working-copy revision'
	printf 'Dry-run complete: repository revision remained %s; no commit attempted.\n' "${initial_revision}"
	exit 0
fi

if (( SVN_DELTA_COUNT == 0 )); then
	printf 'No-op: candidate, assets, and tags/%s already match at revision %s; no credentials or commit needed.\n' "${version}" "${initial_revision}"
	exit 0
fi

commit_message="Release ${slug} ${version}"
commit_output="${work_dir}/commit-output.txt"
if [[ "${official_mode}" == true ]]; then
	wporg_username="${WPORG_USERNAME:-}"
	wporg_password="${WPORG_PASSWORD:-}"
	[[ -n "${wporg_username}" ]] || fail 'WPORG_USERNAME is required for an official commit'
	[[ -n "${wporg_password}" ]] || fail 'WPORG_PASSWORD is required for an official commit'
	[[ "${wporg_username}" =~ ^[A-Za-z0-9_.@+-]+$ ]] || fail 'WPORG_USERNAME contains unsupported characters'
	[[ "${wporg_password}" != *$'\n'* && "${wporg_password}" != *$'\r'* ]] || fail 'WPORG_PASSWORD must not contain a newline'
	unset WPORG_USERNAME WPORG_PASSWORD
	printf '%s\n' "${wporg_password}" | svn commit --non-interactive --no-auth-cache \
		--username "${wporg_username}" --password-from-stdin --message "${commit_message}" "${working_copy}" > "${commit_output}" || fail 'official SVN commit failed'
	wporg_password=''
else
	svn commit --non-interactive --no-auth-cache --message "${commit_message}" "${working_copy}" > "${commit_output}" || fail 'local fixture SVN commit failed'
fi

committed_revision="$(sed -n 's/^Committed revision \([0-9][0-9]*\)\.$/\1/p' "${commit_output}")"
[[ "${committed_revision}" =~ ^[0-9]+$ ]] || fail 'could not parse committed SVN revision'
post_commit_status="$(svn status --xml --no-ignore "${working_copy}")"
if [[ "${post_commit_status}" == *'<entry'* ]]; then
	fail 'working copy is not clean after commit'
fi
compare_or_sync_tree compare "${candidate_root}" "${working_copy}/trunk" 'committed trunk differs from candidate'
compare_or_sync_tree compare "${asset_source}" "${working_copy}/assets" 'committed assets differ from canonical assets'
compare_or_sync_tree compare "${candidate_root}" "${tag_path}" "committed tag differs from candidate"
printf 'SVN deployment committed safely: version %s at revision %s.\n' "${version}" "${committed_revision}"
