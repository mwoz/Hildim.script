require "mblua"
require "gui"
local msg_SqlObjectMap = nil

local dirName

local function AddObjectFromFile(filename)
    local j = 0
    local fname = filename:lower()
    if fname:find("\\update") then return end
    if fname:find("\\upgrade") then return end
    for line in io.lines(fname) do
        j = j + 1
        if line == nil then break end
        local s,e,w
        s,e,typ,w = line:lower():find("create%s+([%w_]+)%s+([%w_%.]+)")
        if s~=nil then
            typ = typ:lower()
            if typ=='proc' or typ=='procedure' or typ=='view' or typ=='table' or typ=='trigger' or typ=='function'  then
                s = w:find("%.")
                if(s~=nil) then w = w:sub(s+1); end

                msg_SqlObjectMap:SetPathValue(w.."\\file", fname:lower())
                msg_SqlObjectMap:SetPathValue(w.."\\line", j)
            end
        end
    end
end
local function dir(strPath)
    local p = strPath
    local fld = gui.files(strPath.."*",true)
    if not fld then
        print(strPath.." is empty or not exists!")
        return
    end

    for i, d in ipairs(fld) do
        dir(strPath..d:from_utf8(1251).."\\")
    end
    local files = gui.files(strPath.."*.m")
    if files then
        local i,filename
        for i, filename in ipairs(files) do
            AddObjectFromFile(strPath..filename:from_utf8(1251))
        end
    end
    files = gui.files(strPath.."*.sql")
    if files then
        for i, filename in ipairs(files) do
            AddObjectFromFile(strPath..filename:from_utf8(1251))
        end
    end
end

msg_SqlObjectMap = nil
msg_SqlObjectMap = mblua.CreateMessage()
for dirName in string.gmatch(strPath, "[^;]+") do
    dir(dirName.."\\")
end
msg_SqlObjectMap:Store(strOut)
print("Sql object map reloaded")


