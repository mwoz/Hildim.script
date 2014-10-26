require "mblua"

local isText = false
local strStartBasic, strEndBasic
local precomp_tblFiles = {}
props["precomp_strRootDir"] = ""
local precomp_tblAddedtemplates
_G["TemplatesMap"] = {}

function get_precomp_tblFiles(str)
    return precomp_tblFiles[str]
end

--------------------------------------------------------
function prnTable(name)
	--print('> ________________')
	--for k,v in pairs(name) do print(k,v) end
    print(name[1],name[2],name[3])
	--print('> ^^^^^^^^^^^^^^^')
end
function prnTable2(name)
	for i = 1, table.maxn(name) do
		prnTable(name[i])
	end
end

function precom_BuildTemplates()
    if(props["FileNameExt"] ~= "sys.System.xml") then
        print('Команда работает только для шаблона sys.System.xml')
        return
    end
    local start = editor:findtext('<template name="System"')
    local str = editor:GetLine(editor:LineFromPosition(start+1))
    local _,_,version = string.find(str,' version="([^"]+)"')
    local _,_,day,month,year=string.find(str,' released="(%d+)/(%d+)/(%d+)"')
    if(version == nil or day == nil or month == nil or year == nil) then
        print('Некорректный формат строки шаблона меню')
        return
    end
    strCmpDir = 'd:\\Systematica\\Radius\\RadiusServer.stb\\DATA\\'
    er,strOut = shell.exec(strCmpDir..'RadiusTemplateCompiler.exe '..props["precomp_strRootDir"]..' '..strCmpDir..'Radius_Templates_'..year..'-'..month..'-'..day..'_'..version..'.dat', nil, true, true)
    print(er,strOut)
end

local function getLineCount(s)
    local cnt = 0
    for w in string.gmatch(s, "\n") do cnt = cnt+1 end
    return cnt
end

local function RereadTemplateFiles()
require 'gui'
	local precomp_strRootDir = props["precomp_strRootDir"].."\\"
    if precomp_strRootDir == "\\" then return end
    precomp_tblFiles = {}
    local function dir(strPath)
        local p = precomp_strRootDir..strPath
        local folders = gui.files(p.."*",true)
        if not folders then return end

        -- list_dir:clear()
        -- list_dir:add_item ('[..]', {'..','d'})
        for i, d in ipairs(folders) do
            dir(strPath..d.."\\")
        end
        local files = gui.files(precomp_strRootDir..strPath.."*.*")
        if files then
            for i, filename in ipairs(files) do
                filename = string.lower(filename)
                if precomp_tblFiles[filename] == nil then
                    precomp_tblFiles[filename] = strPath..filename
                else
                    if string.find(filename, "%.scc$") == nil then print("!Дубликаты шаблона "..filename) end
                end
            end
        end

    end
    dir("")
end

local function ParseLine(strLine)
    local s,e
	if isText then
		s,e = string.find(strLine,strEndBasic,1,true)
		if nil~= s then isText = false end
        if isText then
            s,e = string.find(strLine,"#INCLUDE",1,true)
            if nil~= s then strLine = "'"..strLine end
        end
		if isText then return strLine else return "'"..strLine end
	else
		s,e = string.find(strLine,strStartBasic)
		if nil~= s then isText = true end
		return "'"..strLine
	end
end

local function OnSave_local()
    local precomp_Map
	local precomp_strRootDir = props["precomp_strRootDir"].."\\"
    if precomp_strRootDir == "\\" then return end
    local strTemplateName = ""
    local function nextPortion(s,label, delta)
        local n = getLineCount(s)

        if n == 0 then return n end
        --n- = n + 1
        local i = table.maxn(precomp_Map)

        local prevShift = precomp_Map[i][1]
        if (prevShift < 0) and (label ~= precomp_Map[i][2]) then return 0 end --пропускаем инклюды в xml
        prevShift = n + prevShift
        --пропускаем однострочные области
        --if if (prevShift < 0) or n> 1 then table.insert(precomp_Map, {prevShift,label,delta}) end
        table.insert(precomp_Map, {prevShift,label,delta})
        return n
    end

    function precomp_CompileTemplLib(strShortName, bIsLib)
    --разбирает библиотеку или сам xml - в зависимости от bIsLib.
        local precomp_strRootDir = props["precomp_strRootDir"].."\\"
        strShortName = string.lower(strShortName)
        local allRight = true
        local strFull = precomp_tblFiles[strShortName]
        if strFull == nil then
            RereadTemplateFiles()
            strFull = precomp_tblFiles[strShortName]
        end
        local strOut = ""

        if strFull ~= nil then
            if precomp_tblAddedtemplates[strShortName] == nil then
                precomp_tblAddedtemplates[strShortName] = 1
                local templFile = io.open(precomp_strRootDir..strFull)
                if templFile then
                    local strSource = templFile:read("*a")
                    local delta = 1
                    local startXml = 0
                    local _
                    if not bIsLib then
                        _,_,strTemplateName = strSource:find('template +name="([^"]+)')
                        startXml = strSource:find("<![CDATA['",1,true)
                        --В 1 строке  будет лежать количество строк от начала скрипта со знаком минус
                        table.insert(precomp_Map,{-getLineCount(string.sub(strSource,1,startXml)),strFull,0})
                    end
                    templFile:close()
                    if _G.iuprops['precompiller.debugmode'] == '1' then
                        strSource = strSource:gsub("'#DEBUG ", ' ')
                    end
                    local d = strSource
                    local prevE = 0
                    local b =0
                    local e = 1
                    local pref,cr,s
                    strOut = ''
                    while true do
                        if b == 0 then b,e,pref,s = strSource:find("^([ \t]*)#INCLUDE%(([^%)]+)%)", e) end
                        if b == nil then b,e,pref,s = strSource:find("(\n[ \t\r]*)#INCLUDE%(([^%)]+)%)", e) end
                        if b == nil then break end

                        local l = strSource:sub(prevE,b - 1 + pref:len())
                        d = strSource:sub(e + 1)
                        local newD = nextPortion(l,strFull, delta)
                        --каждый раз после инклюда увеличиваем дельту на количество строк до предыдущего инклюда
                        delta = delta + newD

                        prevE = e + 1
                        strOut = strOut..l..precomp_CompileTemplLib(s,true)

                        b = nil
                    end
                    nextPortion(d,strFull, delta)
                    strOut = strOut..strSource:sub(prevE)
                else
                    allRight = false
                    print("Not open "..precomp_strRootDir..strFull.." ("..props["precompiller.xmlname"]..")")
                end
            end
        else
            allRight = false
            print("File not found: "..strShortName)

        end
        if allRight then return strOut end
        return false
    end
    local strExt = props["FileExt"]:sub(1, 3):lower()   --таким образом можем компилить шаблоны .xml1 и пр - которые не будут подхватыватся обычным сборщиком
    if (strExt=="inc" or strExt=="xml") then
        local allRight = false
        local strPath = string.sub(props["FilePath"],1,string.len(props["FilePath"])-string.len(props["FileNameExt"]))
        local strOut
        if nil ~= string.find(string.lower(strPath), string.lower(precomp_strRootDir)) and props["precompiller.xmlname"] ~= "" then
            if props["precompiller.ok"] == 'Y' then
                precomp_tblAddedtemplates = {}
                precomp_Map = {}
                strOut = precomp_CompileTemplLib(props["precompiller.xmlname"],false)

--print(strOut)
--prnTable(precomp_tblAddedtemplates)
--prnTable2(precomp_Map)
--[[   local tmpF = io.output(strPath..'tmp.vbs')
  tmpF:write(strOut)
  tmpF:close() ]]
                _G["TemplatesMap"][strTemplateName] = precomp_Map
                allRight = true
                if strOut == false then allRight = false end
            end
            if allRight then
                print(">>>"..props["precompiller.xmlname"].." Build")
                local msg = mblua.CreateMessage()
                strSubj = 'SYSM.SAVETEMPLATE'
                if _G.iuprops["precompiller.radiususername"] ~= '' then
                    strSubj = strSubj..'.'.._G.iuprops["precompiller.radiususername"]
                end
                msg:Subjects(strSubj)
                -- msg:SetPathValue("TemplPath",precomp_strRootDir.."..\\tmp\\debug.xml")
                msg:SetPathValue("TemplText",strOut)

                mblua.Request(function(handle,Opaque,iError,msgReplay)
                    if iError == 0 then
                        print(msgReplay:GetPathValue("strReplay"))
                    else
                        print("Terminal not responded")
                    end
                end,msg,3,nil)
                --mblua.Publish(msg)
                msg:Destroy()
            else
                print(props["precompiller.xmlname"].." Build Erorr!")
            end
        end
    end
end

function TerminalErrorHandler(handle,Opaque,iError,msgReplay)
    if iError == 0 then
        local tempName = msgReplay:GetPathValue("Template")
        local nChar = msgReplay:GetPathValue("ErrorChar")
        local nLine = msgReplay:GetPathValue("ErrorLine")
        local txtError = msgReplay:GetPathValue("ErrorDescr")
        local precomp_Map = _G["TemplatesMap"][tempName]
        if precomp_Map ~= nil then
            local nInd = table.maxn(precomp_Map)
            while nLine < precomp_Map[nInd][1] or precomp_Map[nInd][1] < 0 do
                nInd = nInd-1
                if precomp_Map[nInd][1] < 0 then
                    break
                end
            end
            nLine = nLine - precomp_Map[nInd][1] + precomp_Map[nInd+1][3]
            strErr = props["precomp_strRootDir"]..'\\'..precomp_Map[nInd+1][2]..'('..nLine..', '..nChar..') '..txtError
            print(strErr)
        else
            print("!!!Unmapped Rintime Error in "..msgReplay:GetPathValue("Template"))
        end
        print("--"..msgReplay:GetPathValue("ErrorScript"))
    else
        print("Error In Subscribe")
    end
end

function precomp_doCompile()
    props["precompiller.ok"] = 'Y'
    OnSave_local()
end

function precomp_PreCompileTemplate()
--require( "luacom" )
    if editor.Lexer  ~= SCLEX_FORMENJINE then return end
    local strExt = props["FileExt"]:sub(1, 3):lower()   --таким образом можем компилить шаблоны .xml1 и пр - которые не будут подхватыватся обычным сборщиком
    if strExt ~= 'xml' and strExt ~= 'inc' then return end
    local vbOk = false
    local strXml
    strXml = ""
    isText = false
    if props['FileExt'] == 'inc' then
        for i = 0, editor.LineCount - 1 do
            style = scite.SendEditor(SCI_GETSTYLEAT, editor.LineIndentPosition[i] + 1)
            if style >= SCE_FM_VB_DEFAULT then
                isText = style < SCE_FM_X_DEFAULT
                break;
            end
        end
    end

    strStartBasic = "<!%[CDATA%[''%]"
    strEndBasic = "]]>"

    local i = 0
    local tmpF = io.output(props['sys.calcsybase.dir']..'\\tmp.vbs')
    while true do
        local ttt
        local f,g = editor:GetLine(i,ttt)
        i = i+1
        if f == nil then break end
        str = string.gsub(ParseLine(f),'\n','')

        tmpF:write(str)
    end
    tmpF:close()
    er,strOut = shell.exec('cscript /nologo "'..props['sys.calcsybase.dir']..'\\tmp.vbs"', nil, true, true)
    if er == 0 then
        strOut = ">>>Check VB  OK: "..props['FilePath']
        vbOk = true
    else
        strOut = string.gsub(string.gsub(strOut,(props['sys.calcsybase.dir']..'\\tmp.vbs'):gsub('%p','%%%1'),props['FilePath']),'\n','')
    end
    print( strOut )
    --Проверка XML
    if strExt == 'xml' then

        props["precompiller.xmlname"] = props["FileNameExt"]
        local s,e=editor:findtext("<?.+?>",SCFIND_REGEXP)
        j=editor:LineFromPosition(e)+1
        strXml=string.sub(editor:GetText(),e+3)

        local nline,npos, msg = mblua.CheckXML(strXml)

        if nline ~= nil then
            print(props["FilePath"].." ("..(nline+j)..","..npos..")")
            print(msg)
            vbOk = false
        else
            print(">>>Check XML OK: "..props['FilePath'])
        end

    end
    if strExt == 'xml' then listCalc_addToRecent(props["FileNameExt"]) end
    if vbOk then
        props["precompiller.ok"] = "Y"
    else
        props["precompiller.ok"] = "N"
    end

end

local function OnBeforeSave_local()
    precomp_PreCompileTemplate()
end

local function OnSwitchFile_local(file)
    local strPathNew, iFind = props['FileDir']:gsub('(\\Templates[^\\]*).*', '%1', 1)
    if iFind > 0 then
        if props["precomp_strRootDir"] ~= strPathNew then
            props["precomp_strRootDir"] = strPathNew
            RereadTemplateFiles()
        end
    end
end

AddEventHandler("OnSwitchFile", OnSwitchFile_local)
AddEventHandler("OnOpen", OnSwitchFile_local)
AddEventHandler("OnSave", OnSave_local)
AddEventHandler("OnBeforeSave", OnBeforeSave_local)
