from __future__ import annotations

import hashlib
from pathlib import Path


def git_blob_sha(text: str) -> str:
    payload = text.encode('utf-8')
    header = f'blob {len(payload)}\0'.encode('utf-8')
    return hashlib.sha1(header + payload).hexdigest()


path = Path('server/cameras.lua')
source = path.read_text(encoding='utf-8')
expected_blob = '7b8539fad7948ef7536509c5fa9da8a2310d752b'
actual_blob = git_blob_sha(source)
if actual_blob != expected_blob:
    raise RuntimeError(
        f'server/cameras.lua changed before patching: expected {expected_blob}, found {actual_blob}'
    )

before = """    local pilotSource = tonumber(feed.pilotSource)
    if config.requirePilotOnDuty ~= false
        and pilotSource and pilotSource > 0
        and pilotSource ~= operatorSource
        and not officerIsOnDuty(pilotSource) then
        return false
    end
"""
after = """    local pilotSource = tonumber(feed.pilotSource)
    if config.requirePilotOnDuty ~= false then
        if not pilotSource or pilotSource <= 0 then
            return false
        end

        if not officerIsOnDuty(pilotSource) then
            return false
        end
    end
"""

count = source.count(before)
if count != 1:
    raise RuntimeError(f'pilot duty guard: expected one match, found {count}')

source = source.replace(before, after, 1)
path.write_text(source, encoding='utf-8')
print(f'patched {path} -> {git_blob_sha(source)}')
