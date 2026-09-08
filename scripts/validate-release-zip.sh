#!/usr/bin/env bash

set -Eeuo pipefail

export LC_ALL=C
export TZ=UTC
umask 022

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly project_root="$(cd -- "${script_dir}/.." && pwd)"
readonly source_dir="${project_root}/plugin-dir"

usage() {
	cat <<'USAGE'
Usage: scripts/validate-release-zip.sh ZIP_PATH EXPECTED_VERSION

EXPECTED_VERSION must be the normalized production form X.Y.Z.
The archive is compared exactly with the canonical plugin-dir.
USAGE
}

fail() {
	printf 'Release ZIP validation failed: %s\n' "$*" >&2
	exit 1
}

if (( $# != 2 )); then
	usage >&2
	exit 2
fi

archive_path="$1"
expected_version="$2"
[[ "${expected_version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'expected version must be normalized X.Y.Z'

for command_name in git unzip python3 find cmp awk realpath mktemp; do
	command -v "${command_name}" >/dev/null 2>&1 || fail "required command not found: ${command_name}"
done

[[ -f "${archive_path}" && ! -L "${archive_path}" ]] || fail "ZIP is not a regular file: ${archive_path}"
archive_path="$(realpath -- "${archive_path}")"
[[ -d "${source_dir}" && ! -L "${source_dir}" ]] || fail 'canonical plugin-dir must be a real directory'

cd "${project_root}"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail 'project root is not a Git worktree'
if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
	expected_epoch="${SOURCE_DATE_EPOCH}"
else
	expected_epoch="$(git show -s --format=%ct HEAD)"
fi
[[ "${expected_epoch}" =~ ^[0-9]+$ ]] || fail 'SOURCE_DATE_EPOCH must be an integer Unix timestamp'
(( expected_epoch >= 315532800 && expected_epoch <= 4354819198 )) || fail 'SOURCE_DATE_EPOCH must fit the ZIP timestamp range 1980-2107'
expected_epoch="$(( expected_epoch - ( expected_epoch % 2 ) ))"

# Inspect central-directory metadata and exact names before extraction. Python's
# stdlib exposes raw entry boundaries, including names containing newlines that
# line-oriented zipinfo output cannot distinguish safely.
python3 - "${archive_path}" "${source_dir}" "${expected_epoch}" <<'PY'
import datetime
import os
import stat
import sys
import unicodedata
import zipfile

archive_path, source_dir, expected_epoch_raw = sys.argv[1:]
expected_datetime = datetime.datetime.fromtimestamp(
    int(expected_epoch_raw), datetime.timezone.utc
).timetuple()[:6]
root = "wp-site-options"
banned_components = {
    "vendor", "node_modules", "tests", "test", "docs", "doc", "coverage",
    "dist", "local-dev", "playwright-report", "test-results",
}
allowed_suffixes = {
    ".php", ".txt", ".css", ".js", ".json", ".xml", ".po", ".mo", ".pot",
    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".avif", ".ico",
    ".woff", ".woff2", ".ttf", ".eot",
}
allowed_extensionless = {"license", "copying", "notice"}
dev_names = {
    "composer.json", "composer.lock", "package.json", "package-lock.json",
    "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml", "compose.yml",
    "compose.yaml", "makefile", "readme.md",
}


def reject(message):
    raise SystemExit(f"Release ZIP validation failed: {message}")


def check_relative_path(relative, is_dir):
    if not relative:
        reject("empty path")
    if "\\" in relative:
        reject(f"backslash in path: {relative!r}")
    if ":" in relative:
        reject(f"colon in path: {relative!r}")
    if any(ord(char) < 32 or ord(char) == 127 for char in relative):
        reject(f"control character in path: {relative!r}")
    if relative != unicodedata.normalize("NFC", relative):
        reject(f"non-NFC path is not allowed: {relative!r}")

    components = relative.split("/")
    if any(not part or part in {".", ".."} for part in components):
        reject(f"unsafe path component: {relative!r}")
    lowered = [part.casefold() for part in components]
    if any(part.startswith(".") for part in components):
        reject(f"hidden path is not releasable: {relative!r}")
    if any(part in banned_components for part in lowered):
        reject(f"development directory is not releasable: {relative!r}")

    if is_dir:
        return

    basename = lowered[-1]
    if (
        basename in dev_names
        or basename.startswith(("phpunit", "phpcs", "dockerfile", "docker-compose"))
        or basename.endswith((".dist", ".example"))
    ):
        reject(f"development file is not releasable: {relative!r}")
    if (
        "secret" in basename
        or "credential" in basename
        or basename.startswith(("id_rsa", "id_dsa", "id_ecdsa", "id_ed25519"))
    ):
        reject(f"secret-like file name is not releasable: {relative!r}")
    suffix = os.path.splitext(basename)[1]
    if suffix not in allowed_suffixes and basename not in allowed_extensionless:
        reject(f"disallowed release file type: {relative!r}")


source_entries = [root + "/"]
source_sizes = {}


def walk_source(directory, prefix=""):
    try:
        entries = sorted(os.scandir(directory), key=lambda item: os.fsencode(item.name))
    except OSError as error:
        reject(f"cannot read canonical source: {error}")

    for entry in entries:
        relative = f"{prefix}/{entry.name}" if prefix else entry.name
        try:
            entry_stat = entry.stat(follow_symlinks=False)
        except OSError as error:
            reject(f"cannot stat canonical source {relative!r}: {error}")

        if stat.S_ISDIR(entry_stat.st_mode):
            check_relative_path(relative, True)
            source_entries.append(f"{root}/{relative}/")
            walk_source(entry.path, relative)
        elif stat.S_ISREG(entry_stat.st_mode):
            check_relative_path(relative, False)
            archive_name = f"{root}/{relative}"
            source_entries.append(archive_name)
            source_sizes[archive_name] = entry_stat.st_size
        else:
            reject(f"symlink or special canonical source entry: {relative!r}")


walk_source(source_dir)
source_entries.sort(key=lambda value: value.encode("utf-8"))
maximum_archive_size = sum(source_sizes.values()) + 1024 * 1024 + len(source_entries) * 1024
if os.path.getsize(archive_path) > maximum_archive_size:
    reject("archive is too large for the canonical source manifest")

try:
    archive = zipfile.ZipFile(archive_path, "r")
except (OSError, zipfile.BadZipFile) as error:
    reject(f"cannot open ZIP: {error}")

with archive:
    if archive.comment:
        reject("archive comment is not allowed")
    infos = archive.infolist()
    if not infos:
        reject("archive is empty")

    names = []
    casefolded_names = set()
    timestamps = set()
    for info in infos:
        name = getattr(info, "orig_filename", info.filename)
        if not isinstance(name, str):
            reject("non-text entry name")
        if name.startswith(("/", "\\")) or (len(name) > 1 and name[1] == ":"):
            reject(f"absolute entry path: {name!r}")
        if "\\" in name:
            reject(f"backslash in entry path: {name!r}")
        if ":" in name:
            reject(f"colon in entry path: {name!r}")
        if any(ord(char) < 32 or ord(char) == 127 for char in name):
            reject(f"control character in entry path: {name!r}")
        normalized_name = unicodedata.normalize("NFC", name)
        if name != normalized_name:
            reject(f"non-NFC entry path is not allowed: {name!r}")

        is_dir = name.endswith("/")
        path_without_slash = name[:-1] if is_dir else name
        components = path_without_slash.split("/")
        if not components or components[0] != root:
            reject(f"wrong archive root: {name!r}")
        if len(components) == 1 and name != root + "/":
            reject("root entry must be the directory wp-site-options/")
        relative = "/".join(components[1:])
        if relative:
            check_relative_path(relative, is_dir)

        folded = normalized_name.casefold()
        if folded in casefolded_names:
            reject(f"duplicate or case-colliding entry: {name!r}")
        casefolded_names.add(folded)

        if info.flag_bits & 0x1:
            reject(f"encrypted entry is not allowed: {name!r}")
        if info.extra:
            reject(f"extra ZIP metadata is not allowed: {name!r}")
        if info.comment:
            reject(f"entry comment is not allowed: {name!r}")
        if info.compress_type not in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}:
            reject(f"unsupported compression method: {name!r}")
        if info.create_system != 3:
            reject(f"entry lacks Unix mode metadata: {name!r}")

        unix_mode = (info.external_attr >> 16) & 0xFFFF
        expected_kind = stat.S_IFDIR if is_dir else stat.S_IFREG
        expected_permissions = 0o755 if is_dir else 0o644
        if stat.S_IFMT(unix_mode) != expected_kind:
            reject(f"symlink or special entry type: {name!r}")
        if stat.S_IMODE(unix_mode) != expected_permissions:
            reject(f"unsafe or non-normalized mode for {name!r}: {oct(stat.S_IMODE(unix_mode))}")
        if is_dir and (info.file_size != 0 or info.compress_size != 0 or info.CRC != 0):
            reject(f"directory entry must have zero size, compressed size, and CRC: {name!r}")
        if not is_dir and info.file_size != source_sizes.get(name):
            reject(f"file size differs from canonical source: {name!r}")
        if not is_dir and info.compress_size > info.file_size + 1024:
            reject(f"compressed entry is unexpectedly large: {name!r}")
        if info.date_time != expected_datetime:
            reject(
                f"timestamp for {name!r} is {info.date_time!r}, "
                f"expected UTC {expected_datetime!r}"
            )

        timestamps.add(info.date_time)
        names.append(name)

    if names.count(root + "/") != 1:
        reject("archive must contain exactly one wp-site-options/ root entry")
    if names != sorted(names, key=lambda value: value.encode("utf-8")):
        reject("central-directory entries are not sorted")
    if names != source_entries:
        missing = sorted(set(source_entries) - set(names))
        unexpected = sorted(set(names) - set(source_entries))
        reject(f"manifest differs from plugin-dir; missing={missing!r}, unexpected={unexpected!r}")
    if len(timestamps) != 1:
        reject("entry timestamps are not normalized")
PY

unzip -tqq "${archive_path}" >/dev/null || fail 'unzip integrity test failed'

work_dir="$(mktemp -d)"
cleanup() {
	rm -rf -- "${work_dir}"
}
trap cleanup EXIT

unzip -qq "${archive_path}" -d "${work_dir}"
extracted_root="${work_dir}/wp-site-options"
[[ -d "${extracted_root}" && ! -L "${extracted_root}" ]] || fail 'extracted root is missing or unsafe'

unsafe_entry="$(find "${extracted_root}" -mindepth 1 ! -type f ! -type d -print -quit)"
[[ -z "${unsafe_entry}" ]] || fail "extracted symlink or special entry: ${unsafe_entry}"

while IFS= read -r -d '' source_path; do
	relative_path="${source_path#${source_dir}/}"
	extracted_path="${extracted_root}/${relative_path}"
	if [[ -d "${source_path}" ]]; then
		[[ -d "${extracted_path}" && ! -L "${extracted_path}" ]] || fail "missing extracted directory: ${relative_path}"
	else
		[[ -f "${extracted_path}" && ! -L "${extracted_path}" ]] || fail "missing extracted file: ${relative_path}"
		cmp -s -- "${source_path}" "${extracted_path}" || fail "file bytes differ from plugin-dir: ${relative_path}"
	fi
done < <(find "${source_dir}" -mindepth 1 -print0)

header_version="$(sed -n 's/^[[:space:]]*Version:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' "${extracted_root}/wp-site-options.php" | tr -d '\r')"
[[ "${header_version}" == "${expected_version}" ]] || fail "plugin header Version ${header_version:-missing} does not equal ${expected_version}"

stable_tag="$(sed -n 's/^[[:space:]]*Stable tag:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' "${extracted_root}/readme.txt" | tr -d '\r')"
[[ "${stable_tag}" == "${expected_version}" ]] || fail "readme Stable tag ${stable_tag:-missing} does not equal ${expected_version}"

changelog_result="$(awk -v version_heading="= ${expected_version} =" '
	{
		sub(/\r$/, "")
		if ($0 == "== Changelog ==") {
			changelog_headings++
			in_changelog = 1
			next
		}
		if (in_changelog && $0 == version_heading) version_headings++
	}
	END { printf "%d:%d", changelog_headings + 0, version_headings + 0 }
' "${extracted_root}/readme.txt")"
[[ "${changelog_result}" == '1:1' ]] || fail "readme must contain one Changelog heading and exactly one '= ${expected_version} =' section beneath it"

printf 'Release ZIP is valid: %s (version %s)\n' "${archive_path}" "${expected_version}"
