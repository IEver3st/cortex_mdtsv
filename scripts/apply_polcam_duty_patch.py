from __future__ import annotations

import hashlib
from pathlib import Path


def git_blob_sha(text: str) -> str:
    payload = text.encode('utf-8')
    header = f'blob {len(payload)}\0'.encode('utf-8')
    return hashlib.sha1(header + payload).hexdigest()


def replace_once(source: str, before: str, after: str, label: str) -> str:
    count = source.count(before)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return source.replace(before, after, 1)


cameras_path = Path('server/cameras.lua')
cameras = cameras_path.read_text(encoding='utf-8')
expected_blob = '044a20f2f6f318812c0ad1d24b56fab54aca05d3'
actual_blob = git_blob_sha(cameras)
if actual_blob != expected_blob:
    raise RuntimeError(
        f'server/cameras.lua changed before patching: expected {expected_blob}, found {actual_blob}'
    )

cameras = replace_once(
    cameras,
    """local function officerIsOnDuty(source)
    if not playerExists(source) then return false end
    local framework = rawget(_G, 'CortexMdtFramework')
    if type(framework) == 'table' and type(framework.isOnDuty) == 'function' then
        local ok, onDuty = pcall(framework.isOnDuty, source)
        if ok then return onDuty == true end
    end
    return GetPlayerPed(source) ~= 0
end
""",
    """local function officerIsOnDuty(source)
    if not playerExists(source) then return false end
    local framework = rawget(_G, 'CortexMdtFramework')
    if type(framework) ~= 'table' or type(framework.isOnDuty) ~= 'function' then
        return false
    end

    local ok, onDuty = pcall(framework.isOnDuty, source)
    return ok and onDuty == true
end

local function airFeedCrewIsOnDuty(feed)
    if type(feed) ~= 'table' then return false end

    local config = getAirSupportConfig()
    local operatorSource = tonumber(feed.operatorSource)
    if not operatorSource or operatorSource <= 0 then
        return false
    end

    if config.requireOperatorOnDuty ~= false and not officerIsOnDuty(operatorSource) then
        return false
    end

    local pilotSource = tonumber(feed.pilotSource)
    if config.requirePilotOnDuty ~= false
        and pilotSource and pilotSource > 0
        and pilotSource ~= operatorSource
        and not officerIsOnDuty(pilotSource) then
        return false
    end

    return true
end
""",
    'authoritative duty helper',
)

cameras = replace_once(
    cameras,
    """local function getAirFeedById(feedId)
    local config = getAirSupportConfig()
    if config.enabled == false then return nil end
    local resource = getAirResource()
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, feed = pcall(function() return exports[resource]:GetAirFeedById(feedId) end)
    return ok and sanitizeAirFeed(feed) or nil
end
""",
    """local function getAirFeedById(feedId)
    local config = getAirSupportConfig()
    if config.enabled == false then return nil end
    local resource = getAirResource()
    if GetResourceState(resource) ~= 'started' then return nil end
    local ok, feed = pcall(function() return exports[resource]:GetAirFeedById(feedId) end)
    local sanitized = ok and sanitizeAirFeed(feed) or nil
    if sanitized and not airFeedCrewIsOnDuty(sanitized) then
        return nil
    end
    return sanitized
end
""",
    'air feed lookup guard',
)

cameras = replace_once(
    cameras,
    """        if feed and feed.operatorSource > 0
            and sameRoutingBucket(source, feed.operatorSource, config.allowCrossRoutingBuckets) then
""",
    """        if feed and feed.operatorSource > 0
            and airFeedCrewIsOnDuty(feed)
            and sameRoutingBucket(source, feed.operatorSource, config.allowCrossRoutingBuckets) then
""",
    'air feed listing guard',
)

cameras = replace_once(
    cameras,
    """                    local allowed = playerExists(viewer) and officerIsOnDuty(viewer)
                        and feed and feed.operatorSource > 0 and playerExists(feed.operatorSource)
                        and sameRoutingBucket(viewer, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets)
""",
    """                    local allowed = playerExists(viewer) and officerIsOnDuty(viewer)
                        and feed and feed.operatorSource > 0 and playerExists(feed.operatorSource)
                        and airFeedCrewIsOnDuty(feed)
                        and sameRoutingBucket(viewer, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets)
""",
    'live air feed guard',
)

cameras = replace_once(
    cameras,
    """        if not feed or feed.operatorSource <= 0
            or not sameRoutingBucket(source, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets) then
            return { ok = false, error = 'Air-support feed is unavailable or outside your routing bucket.' }
""",
    """        if not feed or feed.operatorSource <= 0
            or not airFeedCrewIsOnDuty(feed)
            or not sameRoutingBucket(source, feed.operatorSource, getAirSupportConfig().allowCrossRoutingBuckets) then
            return { ok = false, error = 'Air-support feed is unavailable, off duty, or outside your routing bucket.' }
""",
    'air feed open guard',
)

cameras_path.write_text(cameras, encoding='utf-8')

config_path = Path('shared/config.lua')
config = config_path.read_text(encoding='utf-8')
config = replace_once(
    config,
    """Config.AirSupport = {
    enabled = true,
    resource = 'cortex_polcam',
    syncIntervalMs = 200,
    allowCrossRoutingBuckets = false,
}
""",
    """Config.AirSupport = {
    enabled = true,
    resource = 'cortex_polcam',
    syncIntervalMs = 200,
    allowCrossRoutingBuckets = false,
    requireOperatorOnDuty = true,
    requirePilotOnDuty = true,
}
""",
    'air support duty defaults',
)
config_path.write_text(config, encoding='utf-8')

print(f'patched {cameras_path} -> {git_blob_sha(cameras)}')
print(f'patched {config_path} -> {git_blob_sha(config)}')
