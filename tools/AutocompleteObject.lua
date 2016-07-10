--[[--------------------------------------------------
------------------------------------------------------
Ввод разделителя, заданного в autocomplete.[lexer].start.characters
вызывает список свойств и медодов объекта из соответствующего api файла
Ввод пробела или разделителя изменяют регистр символов в имени объекта в соответствии с записью в api файле
(например "ucase" при вводе автоматически заменяется на "UCase")
Внимание: В скрипте используется функция IsComment (обязательно подключение COMMON.lua)
props["APIPath"] доступно только в SciTE-Ru
------------------------------------------------------
Подключение:
В файл SciTEStartup.lua добавьте строку:
  dofile (props["SciteDefaultHome"].."\\tools\\AutocompleteObject.lua")
задайте в файле .properties соответствующего языка
символ, после ввода которого, будет включатся автодополнение:
  autocomplete.lua.start.characters=.:
------------------------------------------------------
Совет:
Если после ввода разделителя список свойств и методов не возник (хотя они описаны в api файле)
то, возможно, скрипт не смог распознать имя вашего объекта.
Помогите ему в этом, дописав такую строчку в редактируемый документ:
mydoc = document
где mydoc - имя Вашего объекта
document - имя этого же объекта, заданное в api файле

--]]----------------------------------------------------

local current_pos = 0    -- текущая позиция курсора
local current_poslst = 0    -- текущая позиция курсора - при активации листа
local autocom_chars = '' -- паттерн, содержащий экранированные символы из параметра autocomplete.lexer.start.characters - по эти
local fillup_chars = ''  -- паттерн, содержащий экранированные символы из параметра autocomplete.lexer.fillup.characters
local get_api = true     -- флаг, определяющий необходимость перезагрузки api файла
local api_table = {}     -- все строки api файла (очищенные от ненужной нам информации)
local objects_table = {} -- все "объекты", найденные в api файле
local objectsX_table = {}
local alias_table = {}   -- сопоставления "синоним = объект"
local methods_table = {} -- все "методы" заданного "объекта", найденные в api файле
local declarations = {}
local af_current_line
local isXml=false
local apiX_table = {}
local pasteFromXml=false
local calltipinfo = {{-1}} -- в первом поле - строка, в которой открывали толтип - дальше - паровоз из активных толтипов - в структурах:
                        --{позиция,текст,всего_параметров,текущий_параметр{start1,start2,...end}}
local constObjGlobal = '___G___'
local constListId = 7
local constListIdXml = 8
local constListIdXmlPar = 88
local maxListsItems = 16
local bIsListVisible = false
local obj_names = {}
local m_last = nil
local m_ext, m_ptrn = "", ""
local bManualTip = false
local m_tblSubstitution = {}
local curr_fillup_char = ''

local Ext2Ptrn = {}
do
    local patterns = {
        [props['file.patterns.formenjine']]='$(file.patterns.formenjine)',
        [props['file.patterns.cform']]='$(file.patterns.cform)',
        [props['file.patterns.lua']]='$(file.patterns.lua)',
        [props['file.patterns.xml']]='$(file.patterns.xml)',
    }
    for i,v in pairs(patterns) do
        for ext in (i..';'):gfind("%*%.([^;]+);") do
            Ext2Ptrn[ext] = v
        end
    end
end
------------------------------------------------------
function cmpobj_GetFMDefault()
    if(editor.Lexer  ~= SCLEX_FORMENJINE) then return -1 end
    local style = editor.StyleAt[editor.SelectionStart]
    if(style>=SCE_FM_SQL_DEFAULT) then return SCE_FM_SQL_DEFAULT end
    if(style>=SCE_FM_X_DEFAULT) then return SCE_FM_X_DEFAULT end
    if(style>=SCE_FM_VB_DEFAULT) then return SCE_FM_VB_DEFAULT end
    return SCE_FM_DEFAULT
end

local function useAutocomp()
    if editor.Focus then
        iLex = editor.Lexer
        if iLex == SCLEX_FORMENJINE then return cmpobj_GetFMDefault() ~= SCE_FM_SQL_DEFAULT end
        return Ext2Ptrn[props['FileExt']] ~= nil
    end
end
-- Тест для распечатки содержимого заданной таблицы
local function prnTable(name)
	print('> ________________')
	for i = 1, table.maxn(name) do
		print(name[i])
	end
	print('> ^^^^^^^^^^^^^^^')
end
local function prnTable2(name)
	for i = 1, table.maxn(name) do
		prnTable(name[i])
	end
end

local function GetStrAsTable(str)
    local _start, _end, sVar, sValue,sBrash,sPar = string.find(str, '^#$([%w_]+)=([^%s%(]+)([%(]?[%s]*)([^%s]*)', 1)
    if _start ~=nil and sValue ~= nil then --строку разбили на объект, алиас, скобку и параметр - вставляем, как таблицу
        string.gsub(sPar,'^[%s]*','')
        return {sVar, sValue,sBrash,sPar}
    end
    return nil
end

-- Сортирует таблицу по алфавиту и удаляет дубликаты
local function TableSort(table_name)
	table.sort(table_name, function(a, b) return string.upper(a) < string.upper(b) end)
	-- remove duplicates
	for i = table.maxn(table_name)-1, 0, -1 do
		if table_name[i] == table_name[i+1] then
			table.remove (table_name, i+1)
		end
	end
	return table_name
end

local function ShowCallTip(pos,str,s,e)
    local _,_,list = str:find('.-{{(.+)}}')
    local function ls(l)
        local tl = {}
        for w in l:gmatch('[^|]+') do
            table.insert(tl, w)
        end
        tl = TableSort(tl)
        l = table.concat(tl, ',')
        editor.AutoCSeparator = string.byte(',')
        current_poslst = current_pos
        pasteFromXml = false
        if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then l = l:to_utf8(1251) end
        editor:UserListShow(constListIdXmlPar,l)
        if str2 then
            calltipinfo['attr'] = {}
            calltipinfo['attr']['pos'] = pos
            calltipinfo['attr']['str'] = str2
            calltipinfo['attr']['s'] = s
            calltipinfo['attr']['e'] = e
        end
    end
    if list then
        local _,_,str2 = str:find'.-{{.+}}(.+)'
        local _,_,sub = list:find('^(#@%u+)$')
        if sub then list = m_tblSubstitution[sub] end
        if not list:find('|') then
            if list:find('^@@') then
                strfun = list:gsub('^@@', '')
                local callback = loadstring('return '..strfun)()
                callback(function(strList)
                    ls(strList)
                end)
                return
            else
                calltipinfo={0}
                if not bManualTip then
                    editor:SetSel(editor.CurrentPos, editor.CurrentPos)
                    editor:ReplaceSel(list)
                    if str2 then str = str2
                    else return end
                end
            end
        else
            ls(list)
            return
        end
    end
    if not str then calltipinfo={0};return end
    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8(1251) end
    scite.SendEditor(SCI_CALLTIPSHOW,pos,str)
    if  s == nil then return end
    if s > 0 then
        scite.SendEditor(SCI_CALLTIPSETFOREHLT,0xff0000)
        scite.SendEditor(SCI_CALLTIPSETHLT,s+1,e)
    end
    scite.SendEditor(SCI_AUTOCSETCHOOSESINGLE,true)
end

local function isXmlLine()
--определяем, является ли текущая строка тэгом xml
    if editor:PositionFromLine(af_current_line) > current_pos-1 then return false end
    return string.find(','..props["autocomplete."..editor.LexerLanguage..".nodebody.stile"]..',',','..editor.StyleAt[editor.SelectionStart]..',') or (editor.StyleAt[editor.SelectionStart] == 1 and editor.CharAt[editor.SelectionStart] == 62)
end

local function isPosInString()
--определяем, находится ли курсор внутри строки(параметра xml)
    strLine = editor:textrange(editor:PositionFromLine(af_current_line),current_pos)
    i = 0
    for quote in string.gmatch(strLine,'"') do i=i+1 end
    return i%2 == 1
end

local function HideCallTip()
    scite.SendEditor(SCI_CALLTIPCANCEL)
    table.remove(calltipinfo)
    if table.maxn(calltipinfo) == 1 then calltipinfo[1] = 0 end
end

-- Преобразовывает стринг в паттерн для поиска
local function fPattern(str)
	local str_out = ''
	for i = 1, string.len(str) do
		str_out = str_out..'%'..string.sub(str, i, i)
	end
    if str_out ~= '' then str_out = "["..str_out.."]" end
	return str_out
end

------------------------------------------------------

function GetInputObject(line)
--получим конструкцию слева от курсора.одного из типов : object, .field, .metod(), function()
    if string.find(line,"[%s=<>%+%*%-&%%/]$") ~=nil or line == '\n' then
        --будем двигаться по строкам вверх в поисках with, sub, function
        local wrdEndUp = {"^%s*sub%W","^%s*function%W","^%s*end%s+with%W"}
        local strwith = "^%s*with%s+(.+)"

        local nLine = editor:LineFromPosition(editor.CurrentPos) - 1

        while nLine > 0 do
            local strUpLine = editor:GetLine(nLine)
            strUpLine = string.lower(strUpLine)
            local _s, _e, sVar = string.find(strUpLine, "^%s*with%s+(..-)%s*$", 1)
            if sVar ~= nil then
                line = sVar
                break
            end
            local j
            for j=1,table.maxn(wrdEndUp) do
                if string.find(strUpLine,wrdEndUp[j]) ~= nil then
                    nLine = 1
                    break
                end
            end
            nLine = nLine-1
        end
    end

    local lineLen = string.len(line)
    local inputObject = {"","","",nil}
    if props["autocomplete."..editor.LexerLanguage..".nodestart.stile"] == ''..editor.StyleAt[editor.SelectionStart] then inputObject = {"noobj","","",nil} end
    local char = string.sub(line,lineLen,lineLen)
    local bracketsCounter = 0
    if char == ')' then -- ищем object.metod() :TODO - возможно стоит добавить []
        bracketsCounter = 1
        while lineLen > 0 and bracketsCounter > 0  do
            lineLen = lineLen - 1
            char = string.sub(line,lineLen,lineLen)
            if char == ')' then bracketsCounter = bracketsCounter + 1
            elseif char == '(' then bracketsCounter = bracketsCounter - 1
            end
        end
        inputObject[2] = "("--признаком метода или функции в алиасах будет служить (
        inputObject[3] = string.gsub(string.sub(line,lineLen+1,-2),'^[%s]*','')
        lineLen = lineLen - 1
        line = string.sub(line,1,lineLen)
    end
    if bracketsCounter ~= 0 or lineLen <= 0 then return {"","","", nil} end --в строке неправильно расставлены скобки, либо выражение продолженоиз другой строки - вылетаем, нам тут не светит
    local _start, _end, sVar = string.find(line, '(%.?[%w%_]+)$', 1)
    if sVar ~= nil then inputObject[1] = sVar end
    if _start ~= nil then
        local newLine = string.sub(line,1,_start - 1)
        if string.len(newLine) > 0 then
            if string.find(newLine, '[%w_)]$') ~= nil then
                inputObject[4] = GetInputObject(newLine)
    end end end
    -- prnTable(inputObject)
    return inputObject
end

-- Извлечение из api-файла реальных имен объектов, которые соответствуют введенному
-- т.е. введен "объект" wShort, а методы будем искать для WshShortcut и WshURLShortcut
local function GetObjectNames(tableObj)
    if tableObj[4] ~= nil then
        local obj_namesUp = GetObjectNames(tableObj[4])
        if obj_namesUp[1] ~= nil then
            tableObj[1] = obj_namesUp[table.maxn(obj_namesUp)][1]..tableObj[1]
        end
    end

	obj_names = {}
    if tableObj[2]=='' and tableObj[3]=='' then
        -- Поиск по таблице имен "объектов"
        if objects_table[string.upper(tableObj[1])] ~=nil then
            local upObj = string.upper(tableObj[1])
            table.insert(obj_names, {objects_table[upObj].normalName,objects_table[upObj].normalName,'',''})
            return obj_names -- если успешен, то завершаем поиск
        end
    end
	-- Поиск по таблице сопоставлений "объект - синоним"
	for i = 1, table.maxn(alias_table) do
        if string.find(string.lower(tableObj[1]),"^"..alias_table[i][2].."$") and
          ((tableObj[2]=='' and tableObj[3]=='' and alias_table[i][3]=='' and alias_table[i][4]=='')or
          (tableObj[2]~='' and alias_table[i][3]==tableObj[2] and (string.find(tableObj[3],alias_table[i][4])==1 or
          alias_table[i][4]==''))) then
			table.insert(obj_names, alias_table[i])
		end
	end

	for i = 1, table.maxn(declarations) do
		if (string.upper(tableObj[1]) == string.upper(declarations[i][2])) then
			if (tableObj[2]=='' and tableObj[3]=='') then
                table.insert(obj_names, declarations[i])
            else
                for j = 1, table.maxn(alias_table) do
                    if string.find(string.lower(declarations[i][1]),"^"..alias_table[j][2].."$") and
                      (alias_table[j][3]==tableObj[2] and (string.find(tableObj[3],alias_table[j][4],1,true)==1 or
                      alias_table[j][4]=='')) then
                        table.insert(obj_names, alias_table[j])
                    end
                end
            end
		end
	end
	return obj_names
end

local function GetObjectNamesXml()
    strLine = editor:textrange(editor:PositionFromLine(af_current_line),scite.SendEditor(SCI_GETLINEENDPOSITION,af_current_line))
    local names={}
    local _s,_e,s = string.find(strLine,"<([%w]+)")
    if _s ~= nil then
        table.insert(names,{s,s,'',''})
        _s,_e,s = string.find(strLine,' type="([%w]+)"')
        if _s ~= nil then
            if s == "form" then s="formbox" end
            table.insert(names,{s,s,'',''})
        end
    end
    return names
end

local function GetActualText()
--функция возвращает фрагмен текста, в котором ищем присвоения объекта
    if cmpobj_GetFMDefault() == SCE_FM_VB_DEFAULT then
    --для vbscript  внутри форменджина это будет начало текущей ф-ции, либо куски между ф-циями
        local locptrns={"^%s*Sub%s+","^%s*Function%s"}
        local gloptrns={"^%s*End%s+Sub%s+","^%s*End%s+Function%s","^%<%!%-%-"}
        local strtLine=editor:LineFromPosition(editor.CurrentPos)
        local  thislines = {}
        local bActual = true
        for i=strtLine-1,1,-1 do
            local nextActual = false
            local f = editor:GetLine(i,nil)
            if bActual then
                for j=1, table.maxn(gloptrns) do
                    if string.find(f,gloptrns[j]) ~= nil then
                        bActual= false
                        break
                    end
                end
            else
                for j=1, table.maxn(locptrns) do
                    if string.find(f,locptrns[j]) ~= nil then
                        nextActual= true
                        break
                    end
                end
            end
            if bActual then table.insert(thislines,f) end
            if nextActual then
                nextActual = false
                bActual = true
            end
        end
        local iLinesCount = table.maxn( thislines)
        local outpt = ''
        for i=iLinesCount,1,-1 do
            outpt = outpt..thislines[i]
        end
        return outpt
    end
    return string.sub(editor:GetText(),1,editor.CurrentPos)
end

local function FindDeclarationByPattern(text_all, pattern)
	local _start, _end, sVar, sRightString
	_start = 1
	while true do
		_start, _end, sVar, sRightString = string.find(text_all, pattern, _start)
		if _start == nil then break end
		if sRightString ~= '' then
			-- анализируем текст справа от знака "=" (проверяем, объект ли там содержится)
            local input_object = GetInputObject(sRightString)
			if input_object[1] ~= '' then
				local objects = GetObjectNames(input_object)
                if table.maxn(objects) > 0 then
                    for i = table.maxn(declarations), 1, -1 do  --раз нашли новое присвоение данного объекта, удалим все предыдущие
                        if declarations[i][2]== sVar then
                            table.remove(declarations,i)
                        end
                    end
                end
				for i = 1, table.maxn(objects) do
					if objects[i][1] ~= '=' then
						table.insert(declarations, {objects[i][1],sVar,'',''})
					end
				end
			end
		end
		_start = _end + 1
	end
end

-- Поиск деклараций присвоения пользовательской переменной реального объекта
-- т.е. в текущем файле ищем конструкции вида "синоним = объект"
local function FindDeclaration()
    declarations = {}
	local text_all = GetActualText()

    local pattern = props["autocomplete."..editor.LexerLanguage..".setobj.pattern"]
	if pattern == nil or pattern == '' then pattern = '([%w%.%_]+)%s*=%s*([^%c]+)' end
    FindDeclarationByPattern(text_all, pattern)
    pattern = props["autocomplete."..editor.LexerLanguage..".setobj.pattern2"]
	if pattern ~= nil and pattern ~= '' then FindDeclarationByPattern(text_all, pattern) end
end

-- Чтение api файла в таблицы api_table и alias_table(чтобы потом не опрашивать диск, а все тащить из нее)
local function CreateTablesForFile(o_tbl,al_tbl,strApis, needKwd)
    local tbl_MethodList, tbl_Method--в первую табличку вставим методы в качестве ключей, чтоб по ней удалять дубли - а во вторую - в качестве значений
    if needKwd then
        tbl_MethodList,tbl_Method = {},{}
    end
	for api_filename in string.gmatch(strApis, "[^;]+") do
		if api_filename ~= '' then
			local api_file = io.open(api_filename)
			if api_file then
				for line in api_file:lines() do
                    if string.find(line,'^#%$') == 1 and al_tbl ~=nil then -- вставляем алиас
                        local tmp_tbl = GetStrAsTable(line)
                        if tmp_tbl ~= nil then
                            table.insert(al_tbl, tmp_tbl)
                        end
                    elseif string.find(line,'^#@%u') == 1 then
                        local _,_,name,subs = string.find(line,'^(#@%u+) +(.+)')
                        m_tblSubstitution[name] = subs
                    else
                        --line = string.gsub(line,'[%s(].+$','') -- обрезаем комментарии
                        local _s,_e,l,c = string.find(line,'^([^%s%(]+)([^%s%(]?.-)$')
                        if _e ~= nil then
                            local _start, _end, sObj,sMet = string.find(l, '^(.+)'..autocom_chars..'(.+)')
                            if _start == nil then
                                sObj = constObjGlobal
                                sMet = l
                            end

                            local upObj = string.upper(sObj)
                            if o_tbl[upObj] == nil then
                                if o_tbl._fill==nil then o_tbl._fill=true end
                                o_tbl[upObj] = {}
                                o_tbl[upObj].normalName = sObj
                            end
                            table.insert(o_tbl[upObj], {sMet,c})
                            if needKwd then
                                if upObj ~= constObjGlobal and tbl_MethodList[sMet] == nil then
                                    tbl_MethodList[sMet] = 1
                                    table.insert(tbl_Method, sMet)
                                end
                            end
                        end
                    end
				end
				api_file:close()
			else
				o_tbl = {}
			end
		end
	end
    if needKwd then
        return string.lower(table.concat(tbl_Method, ' '))
    end
    return nil
end

local function FillTableFromText(incText,patterns, tblfList)
    local lenP = table.maxn(patterns)
    for i=1,lenP do
        for w,p,pos in string.gmatch(incText,patterns[i]) do
            local step = pos
            while true do
                local _s,_e,c =  string.find(incText,"^%s*%'([^\n]*)",step)
                if _e == nil then break end
                if c ~= nil then p = p.."\n"..c end
                step = _e  + 1
            end
            tblins = objects_table[constObjGlobal]
            if tblins ~= nil then
                table.insert(tblins, {w,p})
                table.insert(tblfList,w)
            end
        end
    end
end

local function ReCreateStructures(strText,tblFiles)
    local rootTag

    if editor:GetLine(0) then _,_,rootTag = (editor:GetLine(0)..''):find('^<(%w+)') end
    rootTag = rootTag or ''

    local tbl_fList= {}
    local function RecrReCreateStructures(strTxt,tblFiles)
        local _incStart,_incEnd,incFind,incPath,_start, _end, fName
        local patterns = {"\n%s*Sub[%s]([%w%_]+)([^\n%']+)()",
                          "\n%s*Function[%s]([%w%_]+)([^\n%']+)()",
                          "\nDim%s*([%w%_]+)([^\n]+)()",
                          "\nConst%s*([%w%_]+)([^\n]+)()"
                        }

        FillTableFromText(strTxt,patterns, tbl_fList)
        while true do     --получим список всех доступных функций
            _start, _end, fName = string.find(strTxt,"\n%'?#INCLUDE.([%w%.%_]+)",_start)
            if _start == nil then
                return
            end
            if tblFiles[string.lower(fName)] == nil then
                tblFiles[string.lower(fName)] = 1
                local fName2 = get_precomp_tblFiles(string.lower(fName))
                if fName2 ~= nil then
                    incPath = props["precomp_strRootDir"]..'\\'..fName2
                    if Favorites_AddFileName ~=nil and StatusBar_obj ~= nil then
                        Favorites_AddFileName(incPath)
                    end
                    if shell.fileexists(incPath) then
                        local incF = io.input(incPath)
                        local incText = incF:read('*a')
                        incF:close()
                        RecrReCreateStructures(incText,tblFiles)
                    else
                        print('File '..incPath..' not found!')
                    end
                else
                    print('Lib '..fName..' not found!')
                end
            end
            _start = _end + 1
        end

    end

    scite.SendEditor(SCI_AUTOCSETCHOOSESINGLE,true)

    local str_vbkwrd = nil
    local str_xmlkwrd = nil
    if editor.Lexer == SCLEX_FORMENJINE then
        if props["keywords6."..Ext2Ptrn[props['FileExt']]]:len() < 10 then
            str_vbkwrd = ' '
        else
            str_vbkwrd = props["keywords6."..Ext2Ptrn[props['FileExt']]]
        end

        if props["keywords4."..Ext2Ptrn[props['FileExt']]]:len() < 10 then
            str_xmlkwrd = ' '
        else
            str_xmlkwrd = props["keywords4."..Ext2Ptrn[props['FileExt']]]
        end
        if m_ptrn ~= (Ext2Ptrn[props['FileExt']] or '&&&&') then
            str_vbkwrd = ' '
            str_xmlkwrd = ' '
        end

        --print(props["keywords6."..Ext2Ptrn[props['FileExt']]]:len())
    end
    m_tblSubstitution = {}
    if m_ext ~= editor.Lexer or str_vbkwrd ~= nil or m_ptrn ~= (Ext2Ptrn[props['FileExt']] or '&&&&')  then
        alias_table = {}
        objects_table = {}
        objectsX_table = {}
        fillup_chars = fPattern(props["autocomplete."..editor.LexerLanguage..".fillup.characters"])
        autocom_chars = fPattern(props["autocomplete."..editor.LexerLanguage..".start.characters"])
        str_vbkwrd = CreateTablesForFile(objects_table,alias_table,props["apii."..(Ext2Ptrn[props['FileExt']] or '&&&&')]..';'..props["apii."..(Ext2Ptrn[props['FileExt']] or '&&&&')..'.'..rootTag], str_vbkwrd ~= nil)
    end
    if Favorites_Clear ~= nil then Favorites_Clear() end
    -----------

    -----------
    if m_ext ~= editor.Lexer or str_xmlkwrd~= nil or m_ptrn ~= (Ext2Ptrn[props['FileExt']] or '&&&&') then
        str_xmlkwrd = CreateTablesForFile(objectsX_table,nil, props["apiix."..(Ext2Ptrn[props['FileExt']] or '&&&&')]..';'..props["apiix."..(Ext2Ptrn[props['FileExt']] or '&&&&')..'.'..rootTag], str_xmlkwrd~=nil)
    end
    if editor.Lexer == SCLEX_FORMENJINE then
        RecrReCreateStructures(editor:GetText(),{})
        if str_vbkwrd ~= nil then
            props["keywords6."..Ext2Ptrn[props['FileExt']]] = str_vbkwrd
            scite.SendEditor(SCI_SETKEYWORDS,5,str_vbkwrd)
        end
        if str_xmlkwrd ~= nil then
            props["keywords4."..Ext2Ptrn[props['FileExt']]] = str_xmlkwrd
            scite.SendEditor(SCI_SETKEYWORDS,3,str_xmlkwrd)
        end
        local kw = string.lower(table.concat(tbl_fList,' '))
        props["keywords16."..Ext2Ptrn[props['FileExt']]] = kw
        scite.SendEditor(3996,15,kw)
        scite.SendEditor(SCI_COLOURISE,0,editor:PositionFromLine(editor.FirstVisibleLine + editor.LinesOnScreen+2))
    else
        RecrReCreateStructures(editor:GetText(),{})
    end
	get_api = false
	return false
end

-- Создание таблицы "методов" заданного "объекта"
local function CreateMethodsTable(obj_names,ob_tbl,strMetBeg)
    local retT = {}
    local sB = string.upper(strMetBeg)
    local last = nil
	for i = 1, table.maxn(obj_names) do
        local upObj = string.upper(obj_names[i][1])
        if ob_tbl[upObj] ~=nil then
            if ob_tbl[upObj]["last"] ~= nil then last = ob_tbl[upObj]["last"] end
            for j=1,table.maxn(ob_tbl[upObj]) do
                if string.find(string.upper(ob_tbl[upObj][j][1]),'^'..sB) then
                    table.insert(retT,ob_tbl[upObj][j][1])
                end
            end
        end
	end
    return retT, last
end

-- Показываем раскрывающийся список "методов"
local function ShowUserList(nPos,iId, last)

	local list_count = table.getn(methods_table)
	if list_count > 0 then
		methods_table = TableSort(methods_table)
        local iSel = 0
        if last ~= nil then
            for i = 1, table.maxn(methods_table) do
                if methods_table[i] == last then
                    iSel = i
                    break
                end
            end
        end
        local sep = '‡'--'Только для этого сепаратора будет производится поиск по аббревиатуре!'
		local s = table.concat(methods_table, sep)
		if s ~= '' then
            editor.AutoCSeparator = string.byte(sep)
            scite.SendEditor(SCI_AUTOCSETMAXHEIGHT,maxListsItems)
            if iId ~= nil then
                editor:UserListShow(iId, s)
            else
                -- scite.SendEditor(SCI_AUTOCSHOW,nPos,s)
                editor:UserListShow(7, s)
            end
            if iSel ~= 0  then
                m_last = last
            end
            bIsListVisible = true
			return true
		else
			return false
		end
	else
		return false
	end
end

local function TryTipFor(sObj,sMet,api_tb,pos)

    api_t = api_tb[string.upper(sObj)]
    if api_t == nil then return false end
    local lLen = table.maxn(api_t)
	for i = 1, lLen do
		local line = api_t[i][1]
		-- ищем строки, которые начинаются с заданного "объекта"
		local _, _end = string.find(string.upper(line), "^"..string.upper(sMet).."$")
		if _end ~= nil then
            local s,e,l,p,d  = string.find(api_t[i][2], "^(%s*%()([^%)%(]+%))(.-)$") --если этто функция - найдем параметры
            if e == nil then
                l = ''
                p = ''
                d = api_t[i][2]
            end
            local nParams=0
            local pozes={}
            local sParam = 0
            local eParam = 0
            strMethodName = api_t[i][1]
            if sObj ~= constObjGlobal then strMethodName = sObj.."."..strMethodName end
            if l ~= '' then
                --разобьем на параметры
                local poz=string.len(strMethodName)
                table.insert(pozes,poz)
                sParam=poz
                for w in string.gmatch(p,"[^%,%)]*[%,%)]") do
                    poz=poz+string.len(w)
                    table.insert(pozes,poz)
                    if nParams==0 then eParam = poz end
                    nParams=nParams+1
                end
            end
            local brk = ''
            if p ~= '' and d ~= '' then brk = '\n' elseif p == '' and d == '' then return false end
            local str=strMethodName..l..p..brk..string.gsub(d,"\\n","\n")
            table.insert(calltipinfo,{pos,str,nParams,1,pozes})
            calltipinfo[1] = af_current_line
            ShowCallTip(pos,str,sParam,eParam)
            return true
		end
	end
    return false
end

local function CallTipXml(sMethod)
    local object_names=GetObjectNamesXml()
    if object_names[1] ~= nil then
        for i=1,table.maxn(object_names) do
            if TryTipFor(object_names[i][1],sMethod,objectsX_table,current_pos) then break end
        end
        bManualTip = false
    end
end

-- Вставляет выбранный из раскрывающегося списка метод в редактируемую строку
local function OnUserListSelection_local(tp,str)
	editor:SetSel(current_poslst, editor.CurrentPos)
    local fmDef = cmpobj_GetFMDefault()
    local s, shift = nil,0
    if tp == constListIdXmlPar then
        if calltipinfo['attr'] then
            ShowCallTip(calltipinfo['attr']['pos'],calltipinfo['attr']['str'],calltipinfo['attr']['s'],calltipinfo['attr']['e'])
        end
        calltipinfo={0}
        s = str:gsub(' .*','')
    elseif pasteFromXml then
        s = str..'=""'
    elseif editor.LexerLanguage == 'xml' or fmDef == SCE_FM_X_DEFAULT or fmDef == SCE_FM_DEFAULT then
        if (iup.GetGlobal('SHIFTKEY') == 'ON' and curr_fillup_char ~= '>') or curr_fillup_char == ' ' or curr_fillup_char == '/' then
            shift = 2
            s = str..'/>'
            if curr_fillup_char == '/' then curr_fillup_char = '' end
        else
            shift = #str + 3
            s = str..'></'..str..'>'
            if curr_fillup_char == '>' then curr_fillup_char = '' end
        end
    else
        s = str
    end

	editor:ReplaceSel(s)
    if pasteFromXml then
        editor.CurrentPos = editor.CurrentPos - 1
        editor:SetSel( editor.CurrentPos, editor.CurrentPos)
        CallTipXml(str)
    else
        if shift > 0 then
            editor.CurrentPos = editor.CurrentPos - shift
            editor:SetSel( editor.CurrentPos, editor.CurrentPos)
        end
        --Если objects_tabl содержит несколько(2) имен объектов, то вроде бы первый родительский,а второй чайлдовый. сохраним наш выбор для чайлдового
        if table.maxn(obj_names) > 0 then
            local upObj = string.upper(obj_names[table.maxn(obj_names)][1])
            objects_table[upObj]['last'] = str
            -- for i = 1, table.maxn(obj_names) do
                -- local upObj = string.upper(obj_names[i][1])
                -- if objects_table[upObj] ~=nil then
                    -- for j=1,table.maxn(objects_table[upObj]) do
                        -- if objects_table[upObj][j][1] == str then
                            -- objects_table[upObj]['last'] = str
                            -- bIsListVisible = false
                            -- return
                        -- end
                    -- end
                -- end
            -- end
            end
    end
    bIsListVisible = false
 end

local function RunAutocomplete(char,pos,word)
	FindDeclaration()

    local input_object = GetInputObject(editor:textrange(editor:PositionFromLine(af_current_line),pos-1))
    if input_object[1] =='' then return '' end

	-- Если слева от курсора отсутствует слово, которое можно истолковать как имя объекта, то выходим
    obj_names = GetObjectNames(input_object)
	if table.maxn(obj_names) == 0 then return false end
    --Возможно, среди obj_names есть и свойства и конструкторы( .Fremes .Frames( ) - тогда свойства надо удалить
    local bIsProps = false
    local bIsConstr = false
	for i = 1, table.maxn(obj_names) do
		if obj_names[i][3] ~= '' then bIsConstr = true else bIsProps=true end
	end
    local last
	methods_table, last = CreateMethodsTable(obj_names,objects_table,word)

    current_poslst = current_pos
	return ShowUserList(string.len(word), nil, last)
end

local function AutocompleteObject(char)
	if get_api == true then
		ReCreateStructures()
	end
	if objects_table._fill == nil then return false end

	return RunAutocomplete(char,current_pos,'')
end

local function CallTip(char,pos)

	if get_api == true then
		ReCreateStructures()
	end
	if objects_table._fill == nil then return false end
    local strLine = editor:textrange(editor:PositionFromLine(af_current_line),pos-1)
    --найдем, что у нас слева - метод или функция
    local _start, _end, sSep, sMetod = string.find(strLine,"("..autocom_chars.."?)([%w%_]+)$")
    if sSep == '' then
      return TryTipFor(constObjGlobal,sMetod,objects_table,pos)
    elseif sSep ~=nil then
        FindDeclaration()

        strLine = string.sub(strLine,1,_start-1)
        local input_object = GetInputObject(strLine)
        obj_names = GetObjectNames(input_object)
        for i=1,table.maxn(obj_names) do
            if TryTipFor(obj_names[i][1],sMetod,objects_table,pos) then return true end
        end
    end
    return false
end

local function TipXml()
    local strLine = editor:textrange(editor:PositionFromLine(af_current_line),current_pos-1)
    --найдем, что у нас слева - метод или функция
    local _start, _end, sMetod = string.find(strLine,"([%w]+)$")
    if _start ~= nil then
        object_names=GetObjectNamesXml()
        if object_names[1] ~= nil then
            for i=1,table.maxn(object_names) do
                if TryTipFor(object_names[i][1],sMetod,apiX_table,current_pos) then break end
            end
        end
    end
    return false
end

local function ResetCallTipParams()
    if scite.SendEditor(SCI_AUTOCACTIVE) then return end
    local tip=calltipinfo[table.maxn(calltipinfo)]
    local pos = current_pos
    if tip[1] > current_pos  then
        if editor:WordEndPosition(current_pos)+1 == tip[1] then
            ShowCallTip(tip[1],tip[2],0,0)
            return
        end
    elseif objectsX_table._fill ~= nil then
        if isXmlLine() then --для xml показываем тип, пока он внутри строки, иначе прячем
            if isPosInString() then
                ShowCallTip(tip[1],tip[2],0,0)
            else
                HideCallTip()
            end
            return
        end
    end
    local strParams = nil -- = editor:textrange(tip[1],current_pos)
    if tip[1] <= current_pos  then
        strParams = editor:textrange(tip[1],current_pos)
    end
    if strParams == nil then
        HideCallTip()
        return
    end
    local bracets = 0
    local iParCount = 1
    local ilen = string.len(strParams)

    for i=1,ilen do
        local ch=string.sub(strParams,i,i)
        if ch == "(" then
            bracets = bracets + 1
        elseif ch == ")" then
            bracets = bracets - 1
        elseif ch == "," and bracets == 0 then
            iParCount = iParCount + 1
        end
        if iParCount > tip[3] or bracets < 0 then
            HideCallTip()
            return
        end
        if ch==" " and bracets == 0 and iParCount == tip[3] then
            --if string.find( strParams, "$" )
            if string.find(strParams, "[^%,%s]%s%s+$") ~= nil then
                HideCallTip()
                return
            end
        end
    end

    calltipinfo[table.maxn(calltipinfo)][4] = iParCount
    local s = tip[5][iParCount]
    local e = tip[5][iParCount+1]
    ShowCallTip(tip[1],tip[2],s,e)
end

local function OnUpdateUI_local()
    if calltipinfo[1] ~= 0 then
        current_pos = editor.CurrentPos
        af_current_line = editor:LineFromPosition(current_pos)
        if calltipinfo[1] ~= af_current_line then--проверяем, не осталось ли информации в scalloping
            calltipinfo={0}
            return false
        else --обеспечим обработку передвижения
            return ResetCallTipParams()
        end
    elseif m_last ~= nil then
        scite.SendEditor(SCI_AUTOCSELECT,m_last)
        m_last = nil
    end
end

local function ListXml()
    if isPosInString() then return false end
    local object_names=GetObjectNamesXml()
    if object_names[1] ~= nil then
        methods_table = CreateMethodsTable(object_names,objectsX_table,'')
        current_poslst = current_pos
        pasteFromXml = true
        return ShowUserList(0,constListIdXml)
    end
    return false
end

-- ОСНОВНАЯ ПРОЦЕДУРА (обрабатываем нажатия на клавиши)
local function OnChar_local(char)
    if bIsListVisible and not pasteFromXml and fillup_chars ~= '' and string.find(char,fillup_chars) then
    --обеспечиваем вставку выбранного в листе значения вводе одного из завершающих символов(fillup_chars - типа (,. ...)
    --делать это через  SCI_AUTOCSETFILLUPS неудобно - не поддерживается пробел, и  start_chars==fillup_chars - лист сразу же закрывается,
        if scite.SendEditor(SCI_AUTOCACTIVE) then
            --editor:SetSel(editor:WordStartPosition(editor.CurrentPos), editor.CurrentPos)
            curr_fillup_char = char
            scite.SendEditor(SCI_AUTOCCOMPLETE)
            editor:ReplaceSel(curr_fillup_char)
            curr_fillup_char = ''
        else
            bIsListVisible = false
        end
    end

	if IsComment(editor.CurrentPos-2) then return false end  -- Если строка закомметирована, то выходим
    current_pos = editor.CurrentPos
    af_current_line = editor:LineFromPosition(current_pos)
    local result = false

    local bResetCallTip = true
	local autocomplete_start_characters = props["autocomplete."..editor.LexerLanguage..".start.characters"]
    if cmpobj_GetFMDefault() == SCE_FM_X_DEFAULT then autocomplete_start_characters = autocomplete_start_characters..'<' end

	local calltip_start_characters = props["calltipex."..editor.LexerLanguage..".parameters.start"]
	-- Если введенного символа нет в параметре autocomplete.lexer.start.characters, то выходим
	if not (autocomplete_start_characters == '' and calltip_start_characters == '') then
              -- if get_api then autocom_chars = fPattern(autocomplete_start_characters) end
        if objectsX_table._fill ~= nil and ( char == ' ' or char == '=' )  then
            if isXmlLine() then
                if char == ' ' then
                    local r = ListXml()
                    return r or result
                else
                    local r = TipXml()
                    return r or result
                end
            else
                pasteFromXml = false
            end
        end
        if string.find(autocomplete_start_characters, char, 1, 1) ~= nil then
            pasteFromXml = false
            if calltipinfo[1] ~= 0 then scite.SendEditor(SCI_CALLTIPCANCEL) end
            local r=AutocompleteObject(char)
            if r then bResetCallTip = false end
            return  r or result
        elseif string.find(calltip_start_characters, char, 1, 1) ~= nil then
            local r = CallTip(char,current_pos)
            return r or result
        end
    end
    if calltipinfo[1] and calltipinfo[1] ~= 0  then --будем считать,  что разделители параметров - только запятые
        if (calltipinfo[table.maxn(calltipinfo)][3] or 0) > 0 and bResetCallTip then
            ResetCallTipParams()
            result = true
        end
    end
    if char=='\n' then HideCallTip() end
    return result
end
------------------------------------------------------
function ShowTipManualy()
	local calltip_start_characters = props["calltipex."..editor.LexerLanguage..".parameters.start"]
	-- Если введенного символа нет в параметре autocomplete.lexer.start.characters, то выходим
    if calltip_start_characters == '' then return end
    current_pos = editor.CurrentPos
    af_current_line = editor:LineFromPosition(current_pos)
    if objectsX_table._fill ~= nil then
        if isXmlLine() then --для xml показываем тип, пока он внутри строки, иначе прячем
            if isPosInString() then
                local posLine = editor:PositionFromLine(af_current_line)
                local str=editor:textrange(posLine,current_pos)
                local _s,_e,sMethod = string.find(str,'(%w+)="[^"]*$')
                if sMethod == nil then return end
                bManualTip = true
                CallTipXml(sMethod)
                return
            end
        end
    end

    local cp = current_pos
    repeat
        char = editor:textrange(cp-1,cp)
        cp = cp-1
    until string.find(calltip_start_characters,char,1,true) == nil

    pos=editor:WordEndPosition(cp)+1
    char = editor:textrange(pos-1,pos)
    CallTip(char,pos)
end

function ShowListManualy()
    if cmpobj_GetFMDefault() == SCE_FM_SQL_DEFAULT or editor.Lexer == SCLEX_MSSQL then
        ShowListManualySql()
        return
    end
    if not isXmlLine() then pasteFromXml = false end
	if get_api == true then
		ReCreateStructures()
	end
	if objects_table._fill == nil then return false end
    current_pos = editor.CurrentPos
    af_current_line = editor:LineFromPosition(current_pos)
    char = editor:textrange(current_pos-1,current_pos)
    if string.find(char,"%s") then
        methods_table = CreateMethodsTable({{constObjGlobal,constObjGlobal,'',''}},objects_table,'')
        current_poslst = current_pos
        ShowUserList(0)
        return
    elseif string.find(char,autocom_chars) then
        RunAutocomplete(char,current_pos,'')
        return
    end
    current_poslst = editor:WordStartPosition(current_pos)
    wordpart = editor:textrange(current_poslst,current_pos)
    char = editor:textrange(current_poslst-1,current_poslst)
    if string.find(char,autocom_chars) then
        tmpPos=current_poslst
        RunAutocomplete(char,current_poslst,wordpart)
        current_poslst=tmpPos
        return
    else
        methods_table = CreateMethodsTable({{constObjGlobal,constObjGlobal,'',''}},objects_table,wordpart)
        ShowUserList(string.len(wordpart))
        return
    end
end
------------------------------------------------------
AddEventHandler("OnChar", function(char)
    if not useAutocomp() then return end
	if props['macro-recording'] ~= '1' and OnChar_local(char) then return true end
	return result
end)
AddEventHandler("OnUserListSelection", function(tp,sel_value)
    if not useAutocomp() then return end
	if tp == constListIdXml or tp == constListId or tp == constListIdXmlPar then
		if OnUserListSelection_local(tp, sel_value) then return true end
	end
    scite.SendEditor(SCI_AUTOCSETCHOOSESINGLE,true)
end)
AddEventHandler("OnSwitchFile", function(file)
    local pr = _G.iuprops["spell.autospell"]
    _G.iuprops["spell.autospell"] = 0
	get_api = true
    ReCreateStructures()
    if Favorites_AddFileName ~=nil and StatusBar_obj ~= nil then
        Favorites_ListFILL()
    end
    m_ext = editor.Lexer
    if m_ext == SCLEX_FORMENJINE then m_ptrn = (Ext2Ptrn[props['FileExt']] or '&&&&') end
    _G.iuprops["spell.autospell"] = pr
end)
AddEventHandler("OnOpen", function(file)
	get_api = true
    ReCreateStructures()
    if Favorites_AddFileName ~=nil and StatusBar_obj ~= nil then
        Favorites_ListFILL()
    end
    m_ext = editor.Lexer
    if m_ext == SCLEX_FORMENJINE then m_ptrn = (Ext2Ptrn[props['FileExt']] or '&&&&') end
end)
AddEventHandler("OnBeforeSave", function() get_api = true end)
AddEventHandler("OnUpdateUI", OnUpdateUI_local)

