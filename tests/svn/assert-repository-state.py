#!/usr/bin/env python3
"""Assert exact SVN checkout trees, bytes, and property policy."""

import os
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET


def reject(message):
    raise SystemExit("SVN fixture assertion failed: " + message)


def inspect_tree(root):
    if not os.path.isdir(root) or os.path.islink(root):
        reject("tree root is missing or unsafe: " + root)
    result = {}
    for current, directories, files in os.walk(root, topdown=True, followlinks=False):
        directories[:] = sorted(
            (name for name in directories if name != ".svn"), key=os.fsencode
        )
        files.sort(key=os.fsencode)
        for name in directories + files:
            path = os.path.join(current, name)
            relative = os.path.relpath(path, root).replace(os.sep, "/")
            info = os.lstat(path)
            if stat.S_ISDIR(info.st_mode):
                result[relative] = ("directory", None)
            elif stat.S_ISREG(info.st_mode):
                with open(path, "rb") as source_file:
                    result[relative] = ("file", source_file.read())
            else:
                reject("special entry in exported state: " + relative)
    return result


def assert_tree(actual_root, expected_root, label):
    actual = inspect_tree(actual_root)
    expected = inspect_tree(expected_root)
    if actual != expected:
        missing = sorted(set(expected) - set(actual), key=os.fsencode)
        unexpected = sorted(set(actual) - set(expected), key=os.fsencode)
        differing = sorted(
            (path for path in set(actual) & set(expected) if actual[path] != expected[path]),
            key=os.fsencode,
        )
        reject(
            "%s differs; missing=%r, unexpected=%r, differing=%r"
            % (label, missing, unexpected, differing)
        )


def read_properties(tree_root):
    result = subprocess.run(
        ["svn", "proplist", "--xml", "--verbose", "-R", tree_root],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        reject("svn proplist failed for " + tree_root)

    tree_root = os.path.abspath(tree_root)
    properties = {}
    for target in ET.fromstring(result.stdout).findall("target"):
        raw_path = target.attrib.get("path", "")
        absolute = os.path.abspath(
            raw_path if os.path.isabs(raw_path) else os.path.join(os.getcwd(), raw_path)
        )
        try:
            common = os.path.commonpath((tree_root, absolute))
        except ValueError:
            reject("property target is outside asserted tree")
        if common != tree_root:
            reject("property target is outside asserted tree")
        relative = os.path.relpath(absolute, tree_root).replace(os.sep, "/")
        values = {}
        for prop in target.findall("property"):
            name = prop.attrib.get("name", "")
            if not name or name in values:
                reject("invalid or duplicate property at " + relative)
            values[name] = prop.text or ""
        if values:
            properties[relative] = values
    return properties


def expected_plugin_properties(plugin_root):
    expected = {}
    for current, _, files in os.walk(plugin_root):
        for name in files:
            if name.lower().endswith(".mo"):
                path = os.path.join(current, name)
                relative = os.path.relpath(path, plugin_root).replace(os.sep, "/")
                expected[relative] = {"svn:mime-type": "application/octet-stream"}
    return expected


def expected_asset_properties(asset_root):
    mime_types = {
        ".gif": "image/gif",
        ".jpeg": "image/jpeg",
        ".jpg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }
    expected = {}
    for entry in os.scandir(asset_root):
        extension = os.path.splitext(entry.name)[1].lower()
        if extension not in mime_types:
            reject("unsupported expected asset: " + entry.name)
        expected[entry.name] = {"svn:mime-type": mime_types[extension]}
    return expected


def assert_properties(actual, expected, label):
    if actual != expected:
        reject("%s properties differ; actual=%r expected=%r" % (label, actual, expected))


if __name__ == "__main__":
    if len(sys.argv) != 5:
        reject("usage: assert-repository-state.py WC CANDIDATE_ROOT ASSET_ROOT VERSION")

    working_copy = os.path.abspath(sys.argv[1])
    candidate_root = os.path.abspath(sys.argv[2])
    asset_root = os.path.abspath(sys.argv[3])
    version = sys.argv[4]

    root_entries = sorted(
        entry.name for entry in os.scandir(working_copy) if entry.name != ".svn"
    )
    if root_entries != ["assets", "tags", "trunk"]:
        reject("repository roots differ: %r" % root_entries)

    tag_entries = sorted(entry.name for entry in os.scandir(os.path.join(working_copy, "tags")))
    if tag_entries != [version]:
        reject("tag roots differ: %r" % tag_entries)

    trunk_root = os.path.join(working_copy, "trunk")
    tag_root = os.path.join(working_copy, "tags", version)
    svn_asset_root = os.path.join(working_copy, "assets")

    assert_tree(trunk_root, candidate_root, "trunk")
    assert_tree(tag_root, candidate_root, "tag")
    assert_tree(svn_asset_root, asset_root, "assets")

    plugin_properties = expected_plugin_properties(candidate_root)
    asset_properties = expected_asset_properties(asset_root)
    assert_properties(read_properties(trunk_root), plugin_properties, "trunk")
    assert_properties(read_properties(tag_root), plugin_properties, "tag")
    assert_properties(read_properties(svn_asset_root), asset_properties, "assets")

    status = subprocess.run(
        ["svn", "status", "--xml", "--no-ignore", working_copy],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if status.returncode != 0 or b"<entry" in status.stdout:
        reject("assertion checkout is not clean")

    print("SVN repository trees, bytes, and properties are exact.")
