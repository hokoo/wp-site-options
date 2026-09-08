#!/usr/bin/env python3
"""Generate deterministic, inert ZIP fixtures for release-validator tests.

The fixtures are never extracted by this helper. Each one is derived from a
known-good release archive and changes only the metadata or payload needed for
its named negative case.
"""

from __future__ import annotations

import pathlib
import stat
import sys
import warnings
import zipfile
from dataclasses import dataclass


@dataclass
class Entry:
    info: zipfile.ZipInfo
    data: bytes


def clone_info(source: zipfile.ZipInfo, filename: str | None = None) -> zipfile.ZipInfo:
    target = zipfile.ZipInfo(filename or source.filename, source.date_time)
    target.compress_type = source.compress_type
    target.comment = source.comment
    target.extra = source.extra
    target.create_system = source.create_system
    target.create_version = source.create_version
    target.extract_version = source.extract_version
    target.reserved = source.reserved
    target.flag_bits = source.flag_bits
    target.volume = source.volume
    target.internal_attr = source.internal_attr
    target.external_attr = source.external_attr
    return target


def clone_entries(entries: list[Entry]) -> list[Entry]:
    return [Entry(clone_info(entry.info), entry.data) for entry in entries]


def find_entry(entries: list[Entry], filename: str) -> Entry:
    return next(entry for entry in entries if entry.info.filename == filename)


def rename_entry(entries: list[Entry], source: str, target: str) -> None:
    entry = find_entry(entries, source)
    entry.info = clone_info(entry.info, target)


def make_file(template: Entry, filename: str, data: bytes = b"<?php\n") -> Entry:
    info = clone_info(template.info, filename)
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    info.extra = b""
    info.comment = b""
    return Entry(info, data)


def write_archive(
    output_path: pathlib.Path,
    entries: list[Entry],
    *,
    archive_comment: bytes = b"",
) -> None:
    with warnings.catch_warnings():
        warnings.filterwarnings("ignore", message="Duplicate name:.*")
        with zipfile.ZipFile(output_path, "w") as archive:
            archive.comment = archive_comment
            for entry in entries:
                archive.writestr(entry.info, entry.data)


def sorted_entries(entries: list[Entry]) -> list[Entry]:
    return sorted(entries, key=lambda entry: entry.info.filename.encode("utf-8"))


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: generate-malicious-zips.py GOOD_ZIP OUTPUT_DIRECTORY", file=sys.stderr)
        return 2

    good_zip = pathlib.Path(sys.argv[1])
    output_dir = pathlib.Path(sys.argv[2])
    if not good_zip.is_file():
        print(f"Good ZIP not found: {good_zip}", file=sys.stderr)
        return 2
    output_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(good_zip, "r") as archive:
        base = [Entry(clone_info(info), archive.read(info)) for info in archive.infolist()]

    regular_name = "wp-site-options/inc/index.php"
    alternate_name = "wp-site-options/index.php"
    regular_template = find_entry(base, regular_name)

    fixtures: dict[str, tuple[list[Entry], bytes]] = {}

    entries = clone_entries(base)
    for entry in entries:
        entry.info = clone_info(entry.info, entry.info.filename.replace("wp-site-options", "other-plugin", 1))
    fixtures["wrong-root.zip"] = (sorted_entries(entries), b"")

    for fixture_name, invalid_name in {
        "traversal.zip": "wp-site-options/../outside.php",
        "absolute-path.zip": "/wp-site-options/outside.php",
        "backslash.zip": "wp-site-options\\outside.php",
        "control-newline.zip": "wp-site-options/new\nline.php",
        "colon-ads.zip": "wp-site-options/index.php:payload.php",
    }.items():
        entries = clone_entries(base)
        rename_entry(entries, regular_name, invalid_name)
        fixtures[fixture_name] = (sorted_entries(entries), b"")

    entries = clone_entries(base)
    duplicate = find_entry(entries, regular_name)
    entries.append(Entry(clone_info(duplicate.info), duplicate.data))
    fixtures["duplicate.zip"] = (entries, b"")

    entries = clone_entries(base)
    collision = find_entry(entries, regular_name)
    entries.append(Entry(clone_info(collision.info, "wp-site-options/inc/INDEX.php"), collision.data))
    # Keep the colliding variant after the canonical name so collision checking
    # runs before the final-order assertion or canonical size lookup.
    fixtures["case-collision.zip"] = (entries, b"")

    entries = clone_entries(base)
    symlink = find_entry(entries, regular_name)
    symlink.info.external_attr = (stat.S_IFLNK | 0o777) << 16
    fixtures["symlink.zip"] = (entries, b"")

    entries = clone_entries(base)
    executable = find_entry(entries, regular_name)
    executable.info.external_attr = (stat.S_IFREG | 0o755) << 16
    fixtures["unsafe-mode.zip"] = (entries, b"")

    entries = clone_entries(base)
    root_directory = find_entry(entries, "wp-site-options/")
    root_directory.data = b"directory payload"
    fixtures["directory-payload.zip"] = (entries, b"")

    for fixture_name, invalid_name in {
        "hidden-env.zip": "wp-site-options/.env",
        "svn-metadata.zip": "wp-site-options/.svn/entries",
        "development-test.zip": "wp-site-options/tests/release-test.php",
    }.items():
        entries = clone_entries(base)
        entries.append(make_file(regular_template, invalid_name))
        fixtures[fixture_name] = (sorted_entries(entries), b"")

    entries = [entry for entry in clone_entries(base) if entry.info.filename != regular_name]
    fixtures["missing-entry.zip"] = (entries, b"")

    entries = clone_entries(base)
    entries.append(make_file(regular_template, "wp-site-options/unexpected.php"))
    fixtures["unexpected-allowlisted-entry.zip"] = (sorted_entries(entries), b"")

    entries = clone_entries(base)
    mutated = find_entry(entries, alternate_name)
    if not mutated.data:
        raise RuntimeError(f"Cannot byte-mutate empty canonical file: {alternate_name}")
    mutated.data = bytes([mutated.data[0] ^ 0x01]) + mutated.data[1:]
    fixtures["same-size-byte-mutation.zip"] = (entries, b"")

    entries = clone_entries(base)
    entries[1], entries[2] = entries[2], entries[1]
    fixtures["unsorted-entries.zip"] = (entries, b"")

    entries = clone_entries(base)
    for entry in entries:
        timestamp = list(entry.info.date_time)
        timestamp[5] += 2
        entry.info.date_time = tuple(timestamp)
    fixtures["wrong-common-timestamp.zip"] = (entries, b"")

    fixtures["archive-comment.zip"] = (clone_entries(base), b"release comment")

    entries = clone_entries(base)
    find_entry(entries, regular_name).info.extra = b"\xca\xfe\x00\x00"
    fixtures["entry-extra.zip"] = (entries, b"")

    entries = clone_entries(base)
    find_entry(entries, regular_name).info.comment = b"entry comment"
    fixtures["entry-comment.zip"] = (entries, b"")

    for fixture_name, (entries, archive_comment) in fixtures.items():
        write_archive(output_dir / fixture_name, entries, archive_comment=archive_comment)

    print(f"Generated {len(fixtures)} malicious fixtures in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
