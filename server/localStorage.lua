local LocalStorage = {}

local function getStoragePath()
    local resourceName = GetCurrentResourceName()
    local dataPath = GetResourcePath(resourceName)
    return ('%s/data/localStorage.json'):format(dataPath)
end

local function ensureDataDir()
    local path = getStoragePath()
    local dir = path:gsub('[^/\\]+$', '')

    if lib and lib.mkdir then
        lib.mkdir(dir)
    else
        os.execute('mkdir "' .. dir .. '"')
    end
end

local function readStore()
    local path = getStoragePath()
    local file = io.open(path, 'r')

    if not file then
        return {}
    end

    local content = file:read('*a')
    file:close()

    if content == '' or content == 'null' then
        return {}
    end

    local success, data = pcall(json.decode, content)
    if not success or type(data) ~= 'table' then
        return {}
    end

    return data
end

local function writeStore(data)
    if type(data) ~= 'table' then
        data = {}
    end

    ensureDataDir()

    local path = getStoragePath()
    local tempPath = path .. '.tmp'
    local backupPath = path .. '.bak'
    local content = json.encode(data)
    local file = io.open(tempPath, 'wb')

    if not file then
        print('[cortex_mdt] Error: Could not open localStorage.json.tmp for writing')
        return false
    end

    file:write(content)
    file:flush()
    file:close()

    local verifyFile = io.open(tempPath, 'rb')
    local verifyContent = verifyFile and verifyFile:read('*a') or nil
    if verifyFile then verifyFile:close() end
    local verified, decoded = pcall(json.decode, verifyContent or '')
    if not verified or type(decoded) ~= 'table' then
        os.remove(tempPath)
        print('[cortex_mdt] Error: Refusing to replace localStorage.json with invalid JSON')
        return false
    end

    local current = io.open(path, 'rb')
    local hadCurrent = current ~= nil
    if current then current:close() end

    os.remove(backupPath)
    if hadCurrent then
        local backedUp, backupError = os.rename(path, backupPath)
        if not backedUp then
            os.remove(tempPath)
            print(('[cortex_mdt] Error: Could not back up localStorage.json: %s'):format(tostring(backupError)))
            return false
        end
    end

    local replaced, replaceError = os.rename(tempPath, path)
    if not replaced then
        if hadCurrent then
            os.rename(backupPath, path)
        end
        os.remove(tempPath)
        print(('[cortex_mdt] Error: Could not replace localStorage.json: %s'):format(tostring(replaceError)))
        return false
    end

    return true
end

function LocalStorage.get(key)
    local store = readStore()
    return store[key]
end

function LocalStorage.set(key, value)
    local store = readStore()
    store[key] = value
    return writeStore(store)
end

function LocalStorage.getAll()
    return readStore()
end

function LocalStorage.setMultiple(data)
    if type(data) ~= 'table' then
        return false
    end

    local store = readStore()

    for k, v in pairs(data) do
        store[k] = v
    end

    return writeStore(store)
end

function LocalStorage.remove(key)
    local store = readStore()
    store[key] = nil
    return writeStore(store)
end

function LocalStorage.clear()
    return writeStore({})
end

return LocalStorage
