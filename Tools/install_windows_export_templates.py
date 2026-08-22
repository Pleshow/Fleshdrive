"""Install only Godot's official Windows x86_64 templates via ZIP ranges."""

from __future__ import annotations

import argparse
import os
import struct
import urllib.request
import zlib
from pathlib import Path


ARCHIVE_URL = (
    "https://downloads.godotengine.org/"
    "?version=4.7.1&flavor=stable&slug=export_templates.tpz&platform=templates"
)
VERSION = "4.7.1.stable"
REQUIRED = {
    "version.txt",
    "windows_debug_x86_64.exe",
    "windows_release_x86_64.exe",
}


def request_range(url: str, start: int | None, end: int | None) -> tuple[bytes, str, int]:
    headers = {"User-Agent": "Godot/4.7.1 Fleshdrive release tooling"}
    if start is not None:
        headers["Range"] = f"bytes={start}-{'' if end is None else end}"
    elif end is not None:
        headers["Range"] = f"bytes=-{end}"
    response = urllib.request.urlopen(
        urllib.request.Request(url, headers=headers), timeout=90
    )
    data = response.read()
    total = int(response.headers.get("Content-Length", len(data)))
    content_range = response.headers.get("Content-Range", "")
    if "/" in content_range:
        total = int(content_range.rsplit("/", 1)[1])
    return data, response.url, total


def central_directory(url: str) -> tuple[bytes, str]:
    tail, resolved_url, _total = request_range(url, None, 65536)
    eocd_at = tail.rfind(b"PK\x05\x06")
    if eocd_at < 0:
        raise RuntimeError("ZIP end-of-central-directory record not found")
    eocd = struct.unpack_from("<4s4H2IH", tail, eocd_at)
    directory_size, directory_offset = eocd[5], eocd[6]
    data, _, _ = request_range(
        resolved_url, directory_offset, directory_offset + directory_size - 1
    )
    return data, resolved_url


def find_entries(directory: bytes) -> dict[str, tuple[int, int, int, int, int]]:
    found: dict[str, tuple[int, int, int, int, int]] = {}
    offset = 0
    while offset + 46 <= len(directory):
        header = struct.unpack_from("<4s6H3I5H2I", directory, offset)
        if header[0] != b"PK\x01\x02":
            raise RuntimeError(f"Invalid central-directory signature at {offset}")
        method, crc, compressed, uncompressed = header[4], header[7], header[8], header[9]
        name_len, extra_len, comment_len = header[10], header[11], header[12]
        local_offset = header[16]
        name_start = offset + 46
        archive_name = directory[name_start : name_start + name_len].decode("utf-8")
        basename = archive_name.replace("\\", "/").rsplit("/", 1)[-1]
        if basename in REQUIRED:
            found[basename] = (local_offset, method, crc, compressed, uncompressed)
        offset = name_start + name_len + extra_len + comment_len
    missing = REQUIRED.difference(found)
    if missing:
        raise RuntimeError(f"Required template entries missing: {sorted(missing)}")
    return found


def extract_entry(
    url: str, entry: tuple[int, int, int, int, int]
) -> bytes:
    local_offset, method, expected_crc, compressed_size, uncompressed_size = entry
    local_header, _, _ = request_range(url, local_offset, local_offset + 29)
    values = struct.unpack("<4s5H3I2H", local_header)
    if values[0] != b"PK\x03\x04":
        raise RuntimeError("Invalid ZIP local-file header")
    if values[2] & 0x1:
        raise RuntimeError("Encrypted template entry is not supported")
    data_offset = local_offset + 30 + values[9] + values[10]
    payload, _, _ = request_range(
        url, data_offset, data_offset + compressed_size - 1
    )
    if len(payload) != compressed_size:
        raise RuntimeError("Incomplete range download")
    if method == 0:
        result = payload
    elif method == 8:
        result = zlib.decompress(payload, -zlib.MAX_WBITS)
    else:
        raise RuntimeError(f"Unsupported ZIP compression method: {method}")
    if len(result) != uncompressed_size:
        raise RuntimeError("Uncompressed template size mismatch")
    if zlib.crc32(result) & 0xFFFFFFFF != expected_crc:
        raise RuntimeError("Template CRC32 mismatch")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    default_root = Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / VERSION
    parser.add_argument("--destination", type=Path, default=default_root)
    args = parser.parse_args()
    directory, resolved_url = central_directory(ARCHIVE_URL)
    entries = find_entries(directory)
    args.destination.mkdir(parents=True, exist_ok=True)
    for name in sorted(REQUIRED):
        output = args.destination / name
        data = extract_entry(resolved_url, entries[name])
        output.write_bytes(data)
        print(f"Installed {name}: {len(data)} bytes (CRC32 verified)")


if __name__ == "__main__":
    main()
