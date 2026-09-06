#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_linemap.py - generate the crash-time address->file:line table for the
SeiunEngine native crash handler (Android and other POSIX targets).

Reads the DWARF line table from an UNSTRIPPED .so and writes a compact sorted
binary map that native_crash.inc binary-searches at crash time, so an on-device
native crash report can print the exact "[source/File.cpp:123]" for each frame
- no root, no tombstones, no host tools needed after the fact.

Usage:
    python gen_linemap.py <libApplicationMain-64.so> <out.bin>

Requires:  pip install pyelftools

Binary format (little endian):
    magic 'SELM' | u32 version=1 | u32 entry_count | u32 str_table_offset
    entries[entry_count]: { u32 rel_addr, u32 line, u32 str_off }  sorted by rel_addr
    string table (NUL-terminated file paths), located at str_table_offset

rel_addr is relative to the module load base (dladdr dli_fbase), i.e. the
link-time virtual address - matching (fault_pc - dli_fbase) at runtime.
Rows with line==0 are "no source info" terminators so a lookup never bleeds
into the next sequence. Only the FIRST row of every constant file:line run is
kept (the runtime lookup returns the last row <= pc, which is then exact).
"""

import struct
import sys
import os

try:
    from elftools.elf.elffile import ELFFile
except ImportError:
    sys.exit("pyelftools is required:  pip install pyelftools")

MAGIC = b"SELM"
VERSION = 1


def _as_text(value):
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return str(value)


def _dir_list(lineprog):
    """Directory table as a list of text paths (index 0 == compilation dir placeholder)."""
    header = lineprog.header
    dirs = []
    entries = None
    try:
        entries = header["directory_entry"]  # DWARF 5
    except (KeyError, TypeError):
        pass
    if entries:
        for d in entries:
            dirs.append(_as_text(d.get("DW_LNCT_path")))
        return dirs
    try:
        entries = header["include_directory"]  # DWARF 2-4
    except (KeyError, TypeError):
        pass
    if entries:
        return [_as_text(d) for d in entries]
    return []


def _file_table(lineprog, dirs, comp_dir):
    """File table as a list of resolved absolute-ish paths (index 0 reserved)."""
    header = lineprog.header
    files = [comp_dir]  # DWARF file index 0 means "compilation dir" (v5); index is 1-based otherwise
    entries = None
    try:
        entries = header["file_entry"]  # both DWARF <5 and 5
    except (KeyError, TypeError):
        pass
    if not entries:
        return files

    v5 = False
    if entries and isinstance(entries[0], dict):
        v5 = True

    for f in entries:
        if v5:
            name = _as_text(f.get("DW_LNCT_path"))
            dir_index = f.get("DW_LNCT_directory_index", 0)
        else:
            name = _as_text(f.name)
            dir_index = f.dir_index
        if dir_index and 0 <= dir_index < len(dirs):
            d = dirs[dir_index]
            if d:
                # join without worrying about separators: DWARF paths use '/' on
                # all hosts, Windows toolchains emit forward slashes too
                name = d.rstrip("/") + "/" + name
            elif comp_dir:
                name = comp_dir.rstrip("/") + "/" + name
        files.append(name)
    return files


def collect_rows(lib_path):
    rows = {}  # addr -> (file_str_index, line); file_str_index resolved later
    files_index = {}
    file_strings = []

    def intern(path):
        path = path.replace("\\", "/")
        idx = files_index.get(path)
        if idx is None:
            idx = len(file_strings)
            files_index[path] = idx
            file_strings.append(path)
        return idx

    with open(lib_path, "rb") as f:
        elf = ELFFile(f)
        if not elf.has_dwarf_info():
            sys.exit("ERROR: %s has no DWARF info (stripped build?). Use the unstripped .so from export/<target>/android/obj/" % lib_path)
        dwarf = elf.get_dwarf_info()

        cu_count = 0
        for cu in dwarf.iter_CUs():
            lineprog = dwarf.line_program_for_CU(cu)
            if lineprog is None:
                continue
            cu_count += 1

            comp_dir = ""
            try:
                comp_dir = _as_text(cu.get_top_DIE().attributes["DW_AT_comp_dir"].value)
            except (KeyError, TypeError, AttributeError):
                pass

            dirs = _dir_list(lineprog)
            file_table = _file_table(lineprog, dirs, comp_dir)

            for entry in lineprog.get_entries():
                state = entry.state
                if state is None:
                    continue
                if state.end_sequence:
                    rows[state.address] = (intern(""), 0)  # terminator
                    continue
                line = state.line or 0
                file_idx = state.file or 0
                path = file_table[file_idx] if 0 <= file_idx < len(file_table) else ""
                if not path:
                    rows[state.address] = (intern(""), 0)
                else:
                    rows[state.address] = (intern(path), line)

        if not rows:
            sys.exit("ERROR: no line-table rows found in %s" % lib_path)
        print("CUs parsed: %d, raw rows: %d, unique addresses: %d" % (cu_count, len(rows), len(rows)))

    return rows, file_strings


def build_map(rows, file_strings):
    # sort + collapse constant runs
    addrs = sorted(rows.keys())
    entries = []
    prev = None
    for addr in addrs:
        row = rows[addr]
        if prev is not None and row == prev:
            continue
        entries.append((addr, row))
        prev = row

    str_blob = bytearray()
    str_index = {}
    for path in file_strings:
        str_index[path] = len(str_blob)
        str_blob.extend(path.encode("utf-8", "replace"))
        str_blob.extend(b"\x00")

    str_off = 16 + 12 * len(entries)
    out = bytearray()
    out.extend(MAGIC)
    out.extend(struct.pack("<III", VERSION, len(entries), str_off))
    for addr, (fidx, line) in entries:
        out.extend(struct.pack("<III", addr, line, str_index[file_strings[fidx]]))
    out.extend(str_blob)
    return out, entries


def selftest(out_bytes, entries, lib_path):
    """Round-trip a few entries through the same lookup the C++ handler does."""
    import random
    if not entries:
        return
    random.seed(1234)
    base = 16
    ok = 0
    for _ in range(min(5, len(entries))):
        i = random.randrange(len(entries))
        addr, (fidx, line) = entries[i]
        # find last entry with rel_addr <= addr
        lo, hi = 0, len(entries)
        while lo + 1 < hi:
            mid = lo + (hi - lo) // 2
            a = struct.unpack_from("<I", out_bytes, base + mid * 12)[0]
            if a <= addr:
                lo = mid
            else:
                hi = mid
        found_line = struct.unpack_from("<I", out_bytes, base + lo * 12 + 4)[0]
        str_off = struct.unpack_from("<I", out_bytes, base + lo * 12 + 8)[0]
        str_table = struct.unpack_from("<I", out_bytes, 12)[0]
        end = out_bytes.index(b"\x00", str_table + str_off)
        path = out_bytes[str_table + str_off:end].decode("utf-8", "replace")
        if found_line == line:
            ok += 1
            print("  lookup 0x%08x -> %s:%d" % (addr, path, found_line))
    print("selftest: %d/5 lookups exact" % ok)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    lib_path, out_path = sys.argv[1], sys.argv[2]
    if not os.path.exists(lib_path):
        sys.exit("ERROR: input not found: %s" % lib_path)

    rows, file_strings = collect_rows(lib_path)
    out_bytes, entries = build_map(rows, file_strings)

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(out_bytes)

    print("entries kept (after run-collapse): %d" % len(entries))
    print("output: %s (%.1f MB)" % (out_path, len(out_bytes) / 1048576.0))
    selftest(out_bytes, entries, lib_path)


if __name__ == "__main__":
    main()
