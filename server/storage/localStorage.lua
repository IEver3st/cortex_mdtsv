local LocalStorage = {}

local function getStoragePath()
    local resourceName = GetCurrentResourceName()
    local dataPath = GetResourcePath(resourceName)
    return ('%s/data/localStorage.json'):format(dataPath)
end

local function readStore()
    local file = io.open(getStoragePath(), 'r')
    if not file then
        return {}
    end

    local content = file:read('*a')
    file:close()

    if content == '' or content == 'null' then
        return {}
    end

    local ok, data = pcall(json.decode, content)
    if ok and type(data) == 'table' then
        return data
    end

    return {}
end

local function writeStore(store)
    local path = getStoragePath()
    local dir = path:gsub('[^/\\]+$', '')
    if lib and lib.mkdir then
        lib.mkdir(dir)
    else
        os.execute('mkdir "' .. dir .. '"')
    end

    local file = io.open(path, 'w+')
    if not file then
        return false
    end

    file:write(json.encode(store or {}))
    file:close()
    return true
end

function LocalStorage.get(key)
    return readStore()[key]
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
    for key, value in pairs(data) do
        store[key] = value
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
