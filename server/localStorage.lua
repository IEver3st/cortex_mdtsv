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
    local file = io.open(path, 'w')

    if not file then
        print('[cortex_mdt] Error: Could not open localStorage.json for writing')
        return false
    end

    local content = json.encode(data)
    file:write(content)
    file:close()

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
