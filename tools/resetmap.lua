if not mblua then mblua = require"mblua" end
require "shell"
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

local function AddDEFFromFile(filename)
    local j = 0
    local fname = filename:lower()
    for line in io.lines(fname) do
        j = j + 1
        if line == nil then break end
        local s,e,w
        s,e,w = line:lower():find("define%(([%w_]+)")
        if s~=nil then
            msg_SqlObjectMap:SetPathValue(w.."\\file", fname:lower())
            msg_SqlObjectMap:SetPathValue(w.."\\line", j)
        end
    end
end

local function dir(strPath)
    local p = strPath
    local files = scite.findfiles(p.."*")
    if not files then return end
    if #files < 3 then return end

    for i, filenameT in ipairs(files) do
        filename = string.lower(filenameT.name)
        if filenameT.isdirectory then
            if filename ~= '.' and filename ~= '..' then dir(p..filename.."\\") end
        else
            local _,_,ext = filename:find('%.(%w+)$')
            if ext then
                ext = ext:lower()
                local f = AddObjectFromFile
                if ext == 'h' then f = AddDEFFromFile end
                if ext == 'h' or ext == 'sql' or ext == 'm' then
                    f(p..filename)
                end
            end
        end
    end
end

msg_SqlObjectMap = nil
msg_SqlObjectMap = mblua.CreateMessage()
for dirName in string.gmatch(strPath, "[^;]+") do
    dir(dirName.."\\")
end
msg_SqlObjectMap:Store(strOut)


