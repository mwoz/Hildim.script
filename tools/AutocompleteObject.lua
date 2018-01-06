--[[--------------------------------------------------
------------------------------------------------------
Ввод разделителя, заданного в autocomplete.[lexer].start.characters
вызывает список свойств и методов объекта из соответствующего api файла
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
local AutocomplAutomatic
local obj_names = {}
local m_last = nil
local m_ext, m_ptrn = "", ""
local bManualTip = false
local m_tblSubstitution = {}
local curr_fillup_char = ''
local inheritors, inheritorsX = {}, {} --таблицы наследования объектов
local objPatern
local Ext2Ptrn = {}
do
    local patterns = {
        [props['file.patterns.formenjine']]='$(file.patterns.formenjine)',
        [props['file.patterns.cform']]='$(file.patterns.cform)',
        [props['file.patterns.lua']]='$(file.patterns.lua)',
        [props['file.patterns.xml']]='$(file.patterns.xml)',
        [props['file.patterns.html']]='$(file.patterns.html)',
        ['*.css']='$(file.patterns.css)',
    }
    for i, v in pairs(patterns) do
        for ext in (i..';'):gmatch("%*%.([^;]+);") do
            Ext2Ptrn[ext] = v
        end
    end
end

local function SetListVisibility(bSet)
    if bSet then
        props['autocompleteword.automatic.blocked'] = '1'
    else
        props['autocompleteword.automatic.blocked'] = '0'
    end
    bIsListVisible = bSet
end

local CUR_POS = {}
function CUR_POS:Use(pos)
    self.use = pos
end
function CUR_POS:Get(fld)
    return self.use or editor[fld or 'CurrentPos']
end
function CUR_POS:OnShow()
    if self.use then
        self.bymouse = true
    else
        self.bymouse = nil
    end
end


local INCL_DEF, PATT
do
    local INCL = lpeg.P'#INCLUDE(' * lpeg.C((1 - lpeg.S')\n')^1)
    INCL_DEF = lpeg.Ct((lpeg.P{INCL + 1 * lpeg.V(1)} )^1)

    local m__CLASS = '~~ROOT'
	local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt, B = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt, lpeg.B

	local function AnyCase(str)
		local res = P'' --empty pattern to start with
		local ch, CH
		for i = 1, #str do
			ch = str:sub(i,i):lower()
			CH = ch:upper()
			res = res * S(CH..ch)
		end
		assert(res:match(str))
		return res
	end

	local PosToLine = function (pos) return 1 end


	local EOF = P(-1)
	local BOF = P(function(s,i) return (i==1) and 1 end)
	local NL = P"\n"-- + P"\f" -- pattern matching newline, platform-specific. \f = page break marker
	local AZ = R('AZ','az')+"_"
	local N = R'09'
	local ANY =  P(1)
	local ESCANY = P'\\'*ANY + ANY
	local SINGLESPACE = S'\n \t\f'
	local SPACE = SINGLESPACE^1

	-- simple tokens
	local IDENTIFIER = AZ * (AZ+N)^0 -- simple identifier, without separators

	local Str1 = P'"' * ( ESCANY - (S'"'+NL) )^0 * (P'"' + NL)--NL == error'unfinished string')
	local Str2 = P"'" * ( ESCANY - (S"'"+NL) )^0 * (P"'" + NL)--NL == error'unfinished string')
	local STRING = Str1 + Str2

	-- special captures
	local cp = Cp() -- pos capture, Carg(1) is the shift value, comes from start_code_pos
	local cl = cp/PosToLine -- line capture, uses editor:LineFromPosition
	local par = Cg(C(   (P"("*(1-P")")^0*P")")^-1      ), 'params') -- captures parameters in parentheses
	--local par = C(   P"("*(1-P")")^0*P")" + (P'  ')      ) -- captures parameters in parentheses


    local SPACE = (S(" \t")+P"_"*S(" \t")^0*(P"\n"))^1
    local SC = SPACE
    local BR = P'"'
    local NL = (P"\n")^1*SC^0
    local STRING = P'"' * (ANY - (P'"' + P"\n"))^0*P'"'
    local COMMENT = (P"'" + P"REM ") * (ANY - P"\n")^0
    local IGNORED = SPACE + COMMENT + STRING
    local I = Cg(C(IDENTIFIER),'ID')
    -- define local patterns
    local f = AnyCase"function"
    local p = AnyCase"property"
        local let = AnyCase"let"
        local get = AnyCase"get"
        local set = AnyCase"set"
        local public = AnyCase"public"
        local private = AnyCase"private"
    local s = AnyCase"sub"

    --local restype = P' '^1 * P"'"^-1* P' '^0 * (P"As"+P"as")*SPACE*Cg(C(AZ^1),'type')
    local restype = P' '^0 * P"'"^- 1 * P' '^0 * (P"As" + P"as")* P' '^1 * Cg(C(AZ^1 ), 'output')

    let = Cg(let * Cc(true), 'LET')
    get = Cg(get*Cc(true),'GET')
    set = Cg(set*Cc(true),'SET')
    private = Cg(private * Cc(true), 'PRIVATE')
    public = Cg(public*Cc(true),'PUBLIC')
    p = Cg(p*Cc(true),'Property')
    p = NL*((private+public)*SC^1)^0*p*SC^1*(let+get+set)
    s = NL*((private+public)*SC^1)^0*Cg(s*Cc(true),'Sub')
    f = NL*((private+public)*SC^1)^0*Cg(f*Cc(true),'Function')
    local ec = NL*AnyCase"end"*SC^1*(AnyCase"class") / (function(a,b) m__CLASS = '~~ROOT'; end)
    local DESCLINE = S' \t'^0 * Cg(C((P'\n' * S' \t'^0 * (#P"'") *(1 - S'\n')^0)^0)/function(a) return (a or ''):gsub('^ *\n *', ''):gsub("'", ''):gsub('\n *', '\\n'):gsub(' +', ' ') end, 'comment')

    local e = NL*AnyCase"end"*SC^1*(AnyCase"sub"+AnyCase"function"+AnyCase"property")
    local body = (IGNORED^1 + IDENTIFIER + 1 - f - s - p - e)^0 * e

    -- definitions to capture:
    f = f*SC^1*I*SC^0*par
    p = p*SC^1*I*SC^0*par
    s = s*SC^1*I*SC^0*par

    local class = (AnyCase"class")*SC^1*(I / function(a,b) m__CLASS = a; end)
    local def = Ct(((f + s + p)*(restype)^-1)*DESCLINE*( Cg(Cc('')/function() return m__CLASS end, 'CLASS') ))*body +class + ec
    -- resulting pattern, which does the work

    PATT = (def + IGNORED^1 + IDENTIFIER + (1-NL)^1 + NL)^0 * EOF

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
        return props['pattern.name$'] ~= ''
    end
end

local function GetStrAsTable(str)
    local _start, _end, sVar, sSign, sFnc, sValue, sBrash, sPar = string.find(str, '^#$((.)([^=]+))=([^%s%(&]+)([%(&]?[%s]*)([^%s]*)', 1)
    if _start ~=nil and sValue ~= nil then --строку разбили на объект, алиас, скобку и параметр - вставляем, как таблицу
        if sSign == '=' then
            sVar = load('return '..sFnc)() --выполняем строку между знаками равенства, как функцию, возвращаемая строка - имя объекта
            if not sVar then return nil end
        end
        string.gsub(sPar, '^[%s]*', '')
        return {sVar, sValue, sBrash, sPar}
    end
end

-- Сортирует таблицу по алфавиту и удаляет дубликаты
local function TableSort(table_name)
	table.sort(table_name, function(a, b) return string.upper(a) < string.upper(b) end)
	-- remove duplicates
	for i = #table_name-1, 0, -1 do
		if table_name[i] == table_name[i+1] then
			table.remove (table_name, i+1)
		end
	end
	return table_name
end


local ulFromCT_data

local function isXmlLine(cp)
--определяем, является ли текущая строка тэгом xml
    cp = cp or CUR_POS:Get('SelectionStart')
    if editor:PositionFromLine(af_current_line) > current_pos - 1 then return false end
    return string.find(','..props["autocomplete."..editor_LexerLanguage()..".nodebody.stile"]..',', ','..editor.StyleAt[cp]..',') or (editor.StyleAt[CUR_POS:Get('SelectionStart')] == 1 and editor.CharAt[CUR_POS:Get('SelectionStart')] == 62)
end

local function ShowCallTip(pos, str, s, e, reshow)
    local s1, _, list = str:find('{{(.-)}}', s)
    local function ls(l)
        if not l:find('|') then
            editor:ReplaceSel(l)
            return
        end
        local tl = {}
        for w in l:gmatch('[^|]+') do
            table.insert(tl, w)
        end
        tl = TableSort(tl)
        l = table.concat(tl, ',')
        editor.AutoCSeparator = string.byte(',')
        current_poslst = current_pos
        pasteFromXml = false
        if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then l = l:to_utf8() end
        editor:SetSel(editor:WordStartPosition(editor.CurrentPos,true), editor:WordEndPosition(editor.CurrentPos,true))
        editor:UserListShow(constListIdXmlPar, l)
    end
    local function IsWordCharParam()
        for i = editor.CurrentPos, 0, -1 do
            local ch = editor.CharAt[i]
            if ch == 44 or ch == 40 then return true end --, [,]  =  44   [(]  =   40
            if editor.WordChars:find(string.char(ch), 1, true) then return false end
        end
    end
    if s1 and list and (e > s1 or e == 0) and not reshow and not CUR_POS.use and
        (not calltipinfo['attr'] or (calltipinfo['attr']['enter'] or s) ~= s or IsWordCharParam()) then
        local _, _, str2 = str:find'.-{{.+}}(.+)'
        local _, _, sub = list:find('^(#@[%u%d]+)$')

        if str2 or true then
            calltipinfo['attr'] = {}
            calltipinfo['attr']['pos'] = pos
            calltipinfo['attr']['str'] = str
            calltipinfo['attr']['s'] = s
            calltipinfo['attr']['e'] = e
        end
        if sub then list = m_tblSubstitution[sub]
            if type(list) == 'function' then list = list(function(strList) ls(strList) end) end
        end
        if not list then return end
        local cp = editor.CurrentPos
        for i = cp, 1, -1 do
            if editor.CharAt[i] == 32 then cp = i; break end
        end
        if not list:find('|') and isXmlLine(cp) then
            calltipinfo ={0}
            if not bManualTip and not CUR_POS.use then
                editor:SetSel(editor.CurrentPos, editor.CurrentPos)
                editor:ReplaceSel(list)
                if str2 then str = str2
                else return end
            end
        elseif not CUR_POS.use then
            ulFromCT_data = list
            editor:SetSel(editor:WordStartPosition(editor.CurrentPos, true), editor:WordEndPosition(editor.CurrentPos, true))
            scite.RunAsync(function()
                if #ulFromCT_data > 0 and not CUR_POS.use then
                    local tl = {}
                    for w in ulFromCT_data:gmatch('[^|]+') do
                        table.insert(tl, w)
                    end
                    tl = TableSort(tl)
                    ulFromCT_data = table.concat(tl, ',')
                    editor.AutoCSeparator = string.byte(',')
                    current_poslst = current_pos
                    pasteFromXml = false
                    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then ulFromCT_data = ulFromCT_data:to_utf8() end
                    editor:UserListShow(constListIdXmlPar, ulFromCT_data)
                end
            end)
            return
        end
    end
    if not str then calltipinfo ={0};return end

    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8() end
    str = str:gsub('({{[^}]+}})', ''):gsub('^ +', ''):gsub(' +$', '')
    if str == '' then return end
    CUR_POS:OnShow()
    editor:CallTipShow(pos, str) --:gsub('[{}#@]', '_'))
    if s == nil or CUR_POS.use then return end
    if s > 0 then
        editor.CallTipForeHlt = 0xff0000
        editor:CallTipSetHlt(s + 1, e)
    end
    editor.AutoCHooseSingle = true
end

local function isPosInString()
--определяем, находится ли курсор внутри строки(параметра xml)
    strLine = editor:textrange(editor:PositionFromLine(af_current_line),current_pos)
    i = 0
    for quote in string.gmatch(strLine,'"') do i=i+1 end
    return i%2 == 1
end

local function HideCallTip()
    editor:CallTipCancel()
    table.remove(calltipinfo)
    if #calltipinfo == 1 then calltipinfo[1] = 0 end
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

local function GetInputObject(line)
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
            for j=1,#wrdEndUp do
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
    if props["autocomplete."..editor_LexerLanguage()..".nodestart.stile"] == ''..editor.StyleAt[editor.SelectionStart] or editor.CharAt[editor.SelectionStart] == 60 then
        inputObject = {"noobj", "", "", nil}
        return inputObject
    end
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
    local _start, _end, sVar = string.find(line, objPatern, 1)

    if sVar ~= nil then inputObject[1] = sVar end
    if _start ~= nil then
        local newLine = string.sub(line,1,_start - 1)
        if string.len(newLine) > 0 then
            if string.find(newLine, '[%w_)]$') ~= nil then
                inputObject[4] = GetInputObject(newLine)
    end end end
    return inputObject
end

-- Извлечение из api-файла реальных имен объектов, которые соответствуют введенному
-- т.е. введен "объект" wShort, а методы будем искать для WshShortcut и WshURLShortcut
local function GetObjectNames(tableObj)
    if tableObj[4] ~= nil then
        local obj_namesUp = GetObjectNames(tableObj[4])
        if obj_namesUp[1] ~= nil then
            tableObj[1] = obj_namesUp[#obj_namesUp][1]..tableObj[1]
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
	for i = 1, #alias_table do
        if string.find(string.lower(tableObj[1]),"^"..alias_table[i][2].."$") and
          ((tableObj[2]=='' and tableObj[3]=='' and alias_table[i][3]=='' and alias_table[i][4]=='')or
          (tableObj[2]~='' and alias_table[i][3]==tableObj[2] and (string.find(tableObj[3],alias_table[i][4])==1 or
          alias_table[i][4]==''))) then
			table.insert(obj_names, alias_table[i])
		end
	end
	for i = 1, #declarations do
		if (string.upper(tableObj[1]) == string.upper(declarations[i][2])) then
			if (tableObj[2]=='' and tableObj[3]=='') then
                table.insert(obj_names, declarations[i])
            else
                for j = 1, #alias_table do
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
    local strLine = editor:textrange(editor:PositionFromLine(af_current_line), CUR_POS:Get())-- editor:PositionFromLine(af_current_line + 1))
    local names ={}
    local i = 0
    repeat
        local _s, _e, s, p = string.find(strLine, ".*<([%w]*)([^>]*)$") --".*<([%w]+)")
        if _s ~= nil and s ~= '' then

            table.insert(names,{s, s, '', ''})
            strLine = editor:textrange(editor:PositionFromLine(af_current_line - i), editor:PositionFromLine(af_current_line + 1) - 2)
            local _s, _e, s1 = string.find(strLine, ' type="([%w&]+)"')
            if _s ~= nil then
                s1 = s1:lower()
                if s1 == "form" then s1 = "formbox" end
                table.insert(names,{s1, s1, '', ''})
                table.insert(names,{s..'&'..s1, s..'&'..s1, '', ''})
            end
            return names
        elseif strLine:find('[<>]') then return names end
            --table.insert(names,{"noobj", '', '', ''})
        --end
        i = i + 1
        strLine = editor:textrange(editor:PositionFromLine(af_current_line - i), editor:PositionFromLine(af_current_line - i + 1) - 2)
    until af_current_line - i == 0
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
                for j=1, #gloptrns do
                    if string.find(f,gloptrns[j]) ~= nil then
                        bActual= false
                        break
                    end
                end
            else
                for j=1, #locptrns do
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
        local iLinesCount = # thislines
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
                if #objects > 0 then
                    for i = #declarations, 1, -1 do  --раз нашли новое присвоение данного объекта, удалим все предыдущие
                        if declarations[i][2]== sVar then
                            table.remove(declarations,i)
                        end
                    end
                end
				for i = 1, #objects do
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

    local pattern = props["autocomplete."..editor_LexerLanguage()..".setobj.pattern"]
	if pattern == nil or pattern == '' then pattern = '([%w%.%_]+)%s*=%s*([^%c]+)' end
    FindDeclarationByPattern(text_all, pattern)
    pattern = props["autocomplete."..editor_LexerLanguage()..".setobj.pattern2"]
	if pattern ~= nil and pattern ~= '' then FindDeclarationByPattern(text_all, pattern) end
end

-- Чтение api файла в таблицы api_table и alias_table(чтобы потом не опрашивать диск, а все тащить из нее)
local function CreateTablesForFile(o_tbl, al_tbl, strApis, needKwd, inh_table)
    local tbl_MethodList, tbl_Method--в первую табличку вставим методы в качестве ключей, чтоб по ней удалять дубли - а во вторую - в качестве значений
    if needKwd then
        tbl_MethodList,tbl_Method = {},{}
    end
    local strLua = nil
    local b1Chr = (#props["autocomplete."..editor_LexerLanguage()..".start.characters"] == 1)
	for api_filename in string.gmatch(strApis, "[^;]+") do
        if api_filename ~= '' then
            local api_file = io.open(api_filename)
            if api_file then
                for line in api_file:lines() do
                    if strLua then
                        strLua = strLua..'\n'..line
                    elseif line:byte() == 35 then --#
                        if string.find(line, '^#%-%-') == 1 then -- зачитываем луа
                            strLua = ''
                        elseif string.find(line, '^#%$') == 1 then -- вставляем алиас
                            local _, _, inh, parent = line:find("^#%$([%w]+)=#%$([%w_]+)")
                            if parent then
                                if not inh_table[inh] then inh_table[inh] = {} end
                                table.insert(inh_table[inh], parent)
                            elseif al_tbl ~= nil then
                                local tmp_tbl = GetStrAsTable(line)
                                if tmp_tbl ~= nil then
                                    table.insert(al_tbl, tmp_tbl)
                                end
                            end
                        elseif string.find(line, '^#@%u') == 1 then
                            local _, _, name, subs = string.find(line, '^(#@[%u%d]+) +(.+)')
                            m_tblSubstitution[name] = subs
                        end
                    else
                        local _s, _e, l, c = string.find(line, '^([^%s%(]+)([^%s%(]?.-)$')
                        if _e ~= nil then
                            local _start, _end, sObj, sChr, sMet = string.find(l, '^(.+)('..autocom_chars..')(.+)')
                            if _start == nil then
                                sObj = constObjGlobal
                                sMet = l
                            end

                            local upObj = string.upper(sObj)
                            if o_tbl[upObj] == nil then
                                if o_tbl._fill == nil then o_tbl._fill = true end
                                o_tbl[upObj] = {}
                                o_tbl[upObj].normalName = sObj
                            end
                            if b1Chr then table.insert(o_tbl[upObj], {sMet, c}) else table.insert(o_tbl[upObj], {sMet, c, sChr}) end
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
    if strLua then

        local tFn = assert(load(strLua))()
        if tFn and type(tFn) == 'table' then
            for n, f in pairs(tFn) do
                m_tblSubstitution[n] = f
            end
        end
    end
    if needKwd then
        return string.lower(table.concat(tbl_Method, ' '))
    end
    return nil
end


local function FillTableFromText(tblfList, tStruct)
    tblins = objects_table[constObjGlobal]
    if tblins then
        for i = 1,  #tStruct do
            if tStruct[i].CLASS == '~~ROOT' then
                table.insert(tblins, {tStruct[i].ID, (tStruct[i].params or '')..'\n'..tStruct[i].comment})
                table.insert(tblfList, tStruct[i].ID)
                if alias_table and tStruct[i].output then
                    table.insert(alias_table, {
                        tStruct[i].output:lower(),
                        tStruct[i].ID:lower(), '(', ''
                    })
                    if tStruct[i].params == '()' or tStruct[i].params == '' then
                        table.insert(alias_table, {
                            tStruct[i].output:lower(),
                            tStruct[i].ID:lower(), '', ''
                        })
                    end
                end
            end
        end
    end
end

local function ReCreateStructures(strText, tblFiles)
    local rootTag
    if editor:GetLine(0) then _,_,rootTag = (editor:GetLine(0)..''):find('^<(%w+)') end
    rootTag = rootTag or ''

    local tbl_fList= {}
    local function RecrReCreateStructures(strTxt,tblFiles)
        local _incStart,_incEnd,incFind,incPath, fName

        local tblIncl = (INCL_DEF:match(strTxt or '', 1) or {})
        local t = lpeg.Ct(PATT):match(strTxt, 1) or {}
        FillTableFromText(tbl_fList, t)
        for idx = 1, #tblIncl do
        --while true do     --получим список всех доступных функций
            fName = tblIncl[idx]

            if tblFiles[string.lower(fName)] == nil then
                tblFiles[string.lower(fName)] = 1
                local fName2 = get_precomp_tblFiles(string.lower(fName))
                if fName2 ~= nil then
                    incPath = props["precomp_strRootDir"]..'\\'..fName2
                    if Favorites_AddFileName ~= nil then -- and StatusBar_obj ~= nil
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
                end
            end
        end
    end
    editor.AutoCHooseSingle = true

    local str_vbkwrd = nil
    local str_xmlkwrd = nil
    if editor.Lexer == SCLEX_FORMENJINE then
        if props["keywords6$"]:len() < 10 then
            str_vbkwrd = ' '
        else
            str_vbkwrd = props["keywords6$"]
        end

        if props["keywords4$"]:len() < 10 then
            str_xmlkwrd = ' '
        else
            str_xmlkwrd = props["keywords4$"]
        end
        if m_ptrn ~= props['pattern.name$'] then
            str_vbkwrd = ' '
            str_xmlkwrd = ' '
        end

    end
    m_tblSubstitution = {}
    if m_ext ~= editor.Lexer or str_vbkwrd ~= nil or m_ptrn ~= props['pattern.name$']  then
        alias_table = {}
        objects_table = {}
        objectsX_table = {}
        fillup_chars = fPattern(props["autocomplete."..editor_LexerLanguage()..".fillup.characters"])
        autocom_chars = fPattern(props["autocomplete."..editor_LexerLanguage()..".start.characters"])
        inheritors = {}
        str_vbkwrd = CreateTablesForFile(objects_table, alias_table, props["apii$"], str_vbkwrd ~= nil, inheritors)
    end
    if Favorites_Clear ~= nil then Favorites_Clear() end
    -----------

    -----------
    if m_ext ~= editor.Lexer or str_xmlkwrd~= nil or m_ptrn ~= props['pattern.name$'] then
        inheritorsX = {}
        str_xmlkwrd = CreateTablesForFile(objectsX_table, nil, props["apiix$"], str_xmlkwrd~= nil, inheritorsX)
    end
    if editor.Lexer == SCLEX_FORMENJINE then
        RecrReCreateStructures(editor:GetText():gsub('\r\n', '\n'),{})
        if str_vbkwrd ~= nil then
            props['keywords6.$('..props['pattern.name$']..')'] = str_vbkwrd
            editor.KeyWords[5] = str_vbkwrd
        end
        if str_xmlkwrd ~= nil then
            props['keywords4.$('..props['pattern.name$']..')'] = str_xmlkwrd
            editor.KeyWords[3] = str_xmlkwrd
        end
        local kw = string.lower(table.concat(tbl_fList,' '))
        props['keywords16.$('..props['pattern.name$']..')'] = kw
        scite.SendEditor(3996, 15, kw)
        editor:Colourise(0, editor:PositionFromLine(editor.FirstVisibleLine + editor.LinesOnScreen + 2))
    else
        RecrReCreateStructures(editor:GetText():gsub('\r\n', '\n'),{})
    end
	get_api = false
	return false
end

local function EnrichFromInheritors(obj_names, inh_table)
    local tblobj = {}
    for i = 1, #obj_names do
        local cyrType = obj_names[i][1]
        if type(obj_names[i][1]) == 'function' then
            cyrType = obj_names[i][1]()
        end

        tblobj[cyrType:upper()] = true
        if inh_table and inh_table[cyrType] then
            for j = 1,  #inh_table[cyrType] do
                tblobj[inh_table[cyrType][j]:upper()] = true
            end
        end
    end
    return tblobj
end

-- Создание таблицы "методов" заданного "объекта"
local function CreateMethodsTable(obj_names, ob_tbl, strMetBeg, inh_table)
    local retT = {}
    local sB = string.upper(strMetBeg:gsub('[^%w_.:]',''))
    local last = nil
    local tblobj = EnrichFromInheritors(obj_names, inh_table)
    for upObj, _ in pairs(tblobj) do
        if ob_tbl[upObj] ~=nil then
            if ob_tbl[upObj]["last"] ~= nil then last = ob_tbl[upObj]["last"] end
            for j=1,#ob_tbl[upObj] do
                if string.find(string.upper(ob_tbl[upObj][j][1]),'^'..sB) then
                    table.insert(retT,ob_tbl[upObj][j][1])
                end
            end
        end
	end
    return retT, last
end

-- Показываем раскрывающийся список "методов"
local function ShowUserList(nPos, iId, last)
    calltipinfo['attr'] = nil
	local list_count = #methods_table
	if list_count > 0 then
		methods_table = TableSort(methods_table)
        local iSel = 0
        if last ~= nil then
            for i = 1, #methods_table do
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
            editor.AutoCMaxHeight = maxListsItems
            if nPos > 0 then editor.CurrentPos = editor.CurrentPos - nPos end
            editor:UserListShow(iId or 7, s)
            if nPos > 0 then editor.CurrentPos = editor.CurrentPos + nPos end

            if iSel ~= 0 then
                m_last = last
            end
            SetListVisibility(true)
			return true
        else
			return false
		end
	else
		return false
	end
end

local function TryTipFor(sObj, sMet, api_tb, pos)
    api_t = api_tb[string.upper(sObj)]
    if api_t == nil then return false end
    local lLen = #api_t
    for i = 1, lLen do
        local line = api_t[i][1]
        -- ищем строки, которые начинаются с заданного "объекта"
        local _, _end = string.find(string.upper(line or ''), "^"..string.upper(sMet or '').."$")
        if _end ~= nil then
            local s, e, l, p, d = string.find(api_t[i][2], "^(%s*%()([^%)%(]+%))(.-)$") --если это функция - найдем параметры
            if e == nil then
                l = ''
                p = ''
                d = api_t[i][2]
            end
            local nParams = 0
            local pozes ={}
            local sParam = 0
            local eParam = 0
            strMethodName = api_t[i][1]
            --if sObj ~= constObjGlobal then strMethodName = sObj.."."..strMethodName end
            if l ~= '' then
                --разобьем на параметры
                local poz = string.len(strMethodName)
                table.insert(pozes, poz)
                sParam = poz
                for w in string.gmatch(p, "[^%,%)]*[%,%)]") do
                    poz = poz + string.len(w)
                    table.insert(pozes, poz)
                    if nParams == 0 then eParam = poz end
                    nParams = nParams + 1
                end
            end
            local brk = ''
            if p ~= '' and d ~= '' then brk = '\n' elseif p == '' and d == '' then return false end
            local str = strMethodName..l..p..brk..string.gsub(d, "\\n", "\n")
            table.insert(calltipinfo,{pos, str, nParams, 1, pozes})
            calltipinfo[1] = af_current_line
            ShowCallTip(pos, str, sParam, eParam)
            return true
        end
    end
    return false
end

local function CallTipXml(sMethod)
    local object_names = GetObjectNamesXml()
    if object_names[1] ~= nil then
        local tblobj = EnrichFromInheritors(object_names, inheritorsX)
        for upObj, _ in pairs(tblobj) do
            if TryTipFor(upObj, sMethod, objectsX_table, current_pos) then break end
        end
        bManualTip = false

    end
end

-- Вставляет выбранный из раскрывающегося списка метод в редактируемую строку
local blockCT = false
local ResetCallTipParams
local function OnUserListSelection_local(tp, str)
    editor:BeginUndoAction()
    editor:SetSel(current_poslst, editor.CurrentPos)
    local fmDef = cmpobj_GetFMDefault()
    local s, shift = nil, 0
    if tp == constListIdXmlPar then
        if calltipinfo['attr'] then
            ShowCallTip(calltipinfo['attr']['pos'], calltipinfo['attr']['str'], calltipinfo['attr']['s'], calltipinfo['attr']['e'], true)
            calltipinfo['attr']['enter'] = calltipinfo['attr']['s']
        end
        --calltipinfo ={0}
        s = str:gsub(' .*', '')
        local sSt = editor.CurrentPos
        local isX = isXmlLine()
        for i = editor.CurrentPos - 1, editor:PositionFromLine(editor:LineFromPosition(editor.CurrentPos)), -1 do
            if editor.CharAt[i] == 34 or
                (not isX and (editor.CharAt[i] == 40 or editor.CharAt[i] == 44)) then
                sSt = i + 1
                break -- ["]  =   34 [,]  =   44 [(]  =   40
            end
        end

        editor:SetSel(sSt, editor.CurrentPos)
    elseif pasteFromXml then
        s = str..'=""'
    elseif editor_LexerLanguage() == 'xml' or editor_LexerLanguage() == 'hypertext' or fmDef == SCE_FM_X_DEFAULT or fmDef == SCE_FM_DEFAULT then
        local tip, sign, txt
        for _, t in ipairs(objects_table['NOOBJ']) do
            if t[1] == str then
                _, _ , tip, sign, txt = t[2]:find('^%s*(.-)([\\>])(.-)%s*$')
                if not tip then tip = t[2] end
                break
            end
        end
        editor:ReplaceSel(str)
        editor:SetSel(editor.CurrentPos, editor.CurrentPos)
        if ABBREV then
            local isAbbr, _, CancellFromForm = ABBREV.TryInsAbbrev('<'..str)
            if isAbbr and not CancellFromForm then
                editor:EndUndoAction()
                editor:AutoCCancel()
                SetListVisibility(false)
                CallTipXml(str)
                return
            elseif isAbbr then
                editor:ReplaceSel('<'..str)
                editor:SetSel(editor.SelectionEnd, editor.SelectionEnd)
            end
        end
        if isXmlLine() then
            if txt and #txt > 1 and ((iup.GetGlobal('SHIFTKEY') == 'OFF' and curr_fillup_char ~= '/') or curr_fillup_char == '>') then
                local pl = string.rep(' ', editor.LineIndentation[editor:LineFromPosition(editor.SelectionStart)])
                txt = txt:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\b', pl):gsub('\\t', string.rep(' ', editor.TabWidth))
                local _, _, nodeBg, nodeEnd = txt:find('([^|]*)|?(.*)')
                shift = #str + 3 + #nodeEnd
                if #nodeEnd == 0 then shift = #str + 4 + #nodeBg end
                s = '>'..nodeBg..nodeEnd..'</'..str..'>'
                if curr_fillup_char == '>' then curr_fillup_char = '' end
            elseif sign == '>' then
                shift = 1
                s = '>'
                if curr_fillup_char == '' then curr_fillup_char = '' end
            elseif ((sign or '1') == '1') == (iup.GetGlobal('SHIFTKEY') == 'ON' and curr_fillup_char ~= '>') or curr_fillup_char == ' ' or curr_fillup_char == '/' then
                shift = 2
                s = '/>'
                if curr_fillup_char == '/' then curr_fillup_char = '' end
            else
                shift = #str + 3
                s = '></'..str..'>'
                if curr_fillup_char == '>' then curr_fillup_char = '' end
            end
        end

        if (tip or '') ~= '' then
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8() end
            editor:CallTipShow(editor.CurrentPos, tip)
        end
    else
        local sc = str:lower()
        local bSet = false
        s = str
        if #props["autocomplete."..editor_LexerLanguage()..".start.characters"] > 1 then
            for i = 1,  #obj_names do
                local tblObj = objects_table[obj_names[i][1]:upper()]
                for _, t in ipairs(tblObj) do
                    if t[1] == str then
                        s = t[3]..str
                        editor.SelectionStart = editor.SelectionStart - 1
                        bSet = true
                        break
                    end
                end
                if bSet then break end
            end
        end
    end

    editor:ReplaceSel(s)
    if pasteFromXml then
        editor.CurrentPos = editor.CurrentPos - 1
        editor:SetSel( editor.CurrentPos, editor.CurrentPos)
        blockCT = true
        CallTipXml(str)
        blockCT = false
    else
        if shift > 0 then
            editor.CurrentPos = editor.CurrentPos - shift
            editor:SetSel( editor.CurrentPos, editor.CurrentPos)
        end
        --Если objects_tabl содержит несколько(2) имен объектов, то вроде бы первый родительский,а второй чайлдовый. сохраним наш выбор для чайлдового
        if #obj_names > 0 then
            local upObj = obj_names[#obj_names][1]
            if type(upObj) == 'function' then
                upObj = upObj()
            else
                upObj = upObj:upper()
            end
            if objects_table[upObj] then objects_table[upObj]['last'] = str end
        end
    end
    SetListVisibility(false)
    editor:EndUndoAction()
end

local function RunAutocomplete(char, pos, word)
    FindDeclaration()

    local input_object = GetInputObject(editor:textrange(editor:PositionFromLine(af_current_line), pos - 1))
    if input_object[1] =='' then return '' end
	-- Если слева от курсора отсутствует слово, которое можно истолковать как имя объекта, то выходим
    obj_names = GetObjectNames(input_object)
	if #obj_names == 0 then return false end

    --Возможно, среди obj_names есть и свойства и конструкторы( .Fremes .Frames( ) - тогда свойства надо удалить
    local bIsProps = false
    local bIsConstr = false
	for i = 1, #obj_names do
		if obj_names[i][3] ~= '' then bIsConstr = true else bIsProps=true end
	end
    local last
	methods_table, last = CreateMethodsTable(obj_names, objects_table, word, inheritors)

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

local function CallTip(char, pos)
    if get_api == true then
        ReCreateStructures()
    end
    if objects_table._fill == nil then return false end
    local strLine = editor:textrange(editor:PositionFromLine(af_current_line), pos - 1)
    if not strLine then return end -- возможно для ридонли файлов
    --найдем, что у нас слева - метод или функция
    local _start, _end, sSep, sMetod = string.find(strLine, "("..autocom_chars.."?)([%w%_]+)$")
    if sSep == '' then
        return TryTipFor(constObjGlobal, sMetod, objects_table, pos)
    elseif sSep ~= nil then
        FindDeclaration()

        strLine = string.sub(strLine, 1, _start - 1)
        local input_object = GetInputObject(strLine)
        obj_names = GetObjectNames(input_object)
        local tblobj = EnrichFromInheritors(obj_names, inheritors)
        for upObj, _ in pairs(tblobj) do
            if TryTipFor(upObj, sMetod, objects_table, pos) then return true end
        end
    end
    return false
end

local function TipXml()
    local strLine = editor:textrange(editor:PositionFromLine(af_current_line), current_pos - 1)
    --найдем, что у нас слева - метод или функция
    local _start, _end, sMetod = string.find(strLine, "([%w]+)$")
    if _start ~= nil then
        object_names = GetObjectNamesXml()
        if object_names[1] ~= nil then
            local tblobj = EnrichFromInheritors(obj_names, inheritorsX)
            for upObj, _ in pairs(tblobj) do
                if TryTipFor(upObj, sMetod, apiX_table, current_pos) then break end
            end
        end
    end
    return false
end

ResetCallTipParams = function(bHidden)

    if editor:AutoCActive() then return end
    local tip = calltipinfo[#calltipinfo]
    local pos = current_pos
    if tip[1] > current_pos then
        if editor:WordEndPosition(current_pos) + 1 == tip[1] then
            ShowCallTip(tip[1], tip[2], 0, 0)
            return
        end
    elseif objectsX_table._fill ~= nil then
        if isXmlLine() then --для xml показываем тип, пока он внутри строки, иначе прячем
            if isPosInString() then
                ShowCallTip(tip[1], tip[2], 0, 0)
            else
                HideCallTip()
            end
            return
        end
    end
    local strParams = nil -- = editor:textrange(tip[1],current_pos)
    if tip[1] <= current_pos then
        strParams = editor:textrange(tip[1], current_pos)
    end
    if strParams == nil then
        HideCallTip()
        return
    end
    local bracets = 0
    local iParCount = 1
    local ilen = string.len(strParams)

    for i = 1, ilen do
        local ch = string.sub(strParams, i, i)
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
        if ch == " " and bracets == 0 and iParCount == tip[3] then
            --if string.find( strParams, "$" )
            if string.find(strParams, "[^%,%s]%s%s+$") ~= nil then
                HideCallTip()
                return
            end
        end
    end

    calltipinfo[#calltipinfo][4] = iParCount
    local s = tip[5][iParCount]
    local e = tip[5][iParCount + 1]
    if not bHidden then ShowCallTip(tip[1], tip[2], s, e) else editor:CallTipCancel() end
end

local function OnUpdateUI_local(bChange, bSelect, flag)
    if (bChange == 0 and bSelect == 0) or blockCT then return end

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
        editor:AutoCSelect(m_last)
        m_last = nil
    end
end

local function ListXml(s)
    if isPosInString() then return false end
    local object_names = GetObjectNamesXml()
    if object_names[1] ~= nil then
        methods_table = CreateMethodsTable(object_names, objectsX_table, s or '', inheritorsX)
        current_poslst = current_pos
        pasteFromXml = object_names[1][1] ~= 'noobj'
        return ShowUserList((s or ''):len(),constListIdXml)
    end
    return false
end

-- ОСНОВНАЯ ПРОЦЕДУРА (обрабатываем нажатия на клавиши)
local function OnChar_local(char)

    if bIsListVisible and not pasteFromXml and fillup_chars ~= '' and string.find(char, fillup_chars) then
        --обеспечиваем вставку выбранного в листе значения вводе одного из завершающих символов(fillup_chars - типа (,. ...)
        --делать это через  SCI_AUTOCSETFILLUPS неудобно - не поддерживается пробел, и  start_chars==fillup_chars - лист сразу же закрывается,
        if editor:AutoCActive() then
            --editor:SetSel(editor:WordStartPosition(editor.CurrentPos), editor.CurrentPos)
            curr_fillup_char = char
            editor:AutoCComplete()
            editor:ReplaceSel(curr_fillup_char)
            curr_fillup_char = ''
        else
            SetListVisibility(false)
        end
    end

    if bIsListVisible and not editor:AutoCActive() then SetListVisibility(false) end

	if IsComment(editor.CurrentPos - 2) then return false end -- Если строка закомментирована, то выходим
    current_pos = editor.CurrentPos
    af_current_line = editor:LineFromPosition(current_pos)
    local result = false
    local bResetCallTip = true
	local autocomplete_start_characters = props["autocomplete."..editor_LexerLanguage()..".start.characters"]
    if cmpobj_GetFMDefault() == SCE_FM_X_DEFAULT then autocomplete_start_characters = autocomplete_start_characters..'<' end
	local calltip_start_characters = props["calltipex."..editor_LexerLanguage()..".parameters.start"]
	-- Если введенного символа нет в параметре autocomplete.lexer.start.characters, то выходим
	if not (autocomplete_start_characters == '' and calltip_start_characters == '') then
        if objectsX_table._fill ~= nil and ( char == ' ' or char == '=' ) then
            if isXmlLine() then
                if char == ' ' then
                    if editor.CharAt[editor.SelectionStart] ~= 60 then
                        local r = ListXml()
                        return r or result
                    end
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
            if calltipinfo[1] ~= 0 then editor:CallTipCancel() end
            local r = AutocompleteObject(char) --Показываем список методов
            if r then bResetCallTip = false end
            return r or result
        elseif string.find(calltip_start_characters, char, 1, 1) ~= nil then
            local r = CallTip(char, current_pos) --Показываем подсказку
            return r or result
        end
    end
    if calltipinfo[1] and calltipinfo[1] ~= 0 then --будем считать,  что разделители параметров - только запятые

        if (calltipinfo[#calltipinfo][3] or 0) > 0 and bResetCallTip then
            result = ((props['autocompleteword.automatic'] or '') ~= '1')
            ResetCallTipParams(not resut)
        end
    end
    if char == '\n' then HideCallTip() end

    return result
end
------------------------------------------------------
function ShowTipManualy()
    calltipinfo['attr'] = nil
    current_pos = CUR_POS:Get()
    af_current_line = editor:LineFromPosition(current_pos)
    if objectsX_table._fill ~= nil then
        local _s, _e, sMethod
        if isXmlLine() then --для xml показываем тип, пока он внутри строки, иначе прячем
            if isPosInString() then
                local posLine = editor:PositionFromLine(af_current_line)
                local str = editor:textrange(posLine, current_pos)
                _s, _e, sMethod = string.find(str, '(%w+)="[^"]*$')
                if sMethod == nil then return end
            else
                local posLine = editor:PositionFromLine(af_current_line)
                current_pos = editor:WordEndPosition(current_pos, true)
                local str = editor:textrange(posLine, current_pos)
                _s, _e, sMethod = string.find(str, '<(%w+)$')
                if sMethod ~= nil then
                    local _,tip, sign
                    for _, t in ipairs(objects_table['NOOBJ']) do
                        if t[1] == sMethod then
                            _, _ , tip = t[2]:find('^([^\\>]*)')
                            break
                        end
                    end
                    tip = (tip or ''):gsub('^ +', ''):gsub(' +$', '')
                    if tip == '' then return end
                    if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8() end
                    CUR_POS:OnShow()
                    editor:CallTipShow(CUR_POS:Get(), tip)
                    return
                else
                    _s, _e, sMethod = string.find(str, ' (%w+)$')
                    if sMethod == nil then return end
                end
            end
            bManualTip = true
            CallTipXml(sMethod)
            return
        end
    end

	local calltip_start_characters = props["calltipex."..editor_LexerLanguage()..".parameters.start"]
	-- Если введенного символа нет в параметре autocomplete.lexer.start.characters, то выходим
    if calltip_start_characters == '' then return end

    local cp = current_pos
    if false then
    else
        repeat
            char = editor:textrange(cp - 1, cp)
            cp = cp - 1
        until string.find(calltip_start_characters, char, 1, true) == nil

        pos = editor:WordEndPosition(cp) + 1
        char = editor:textrange(pos - 1, pos)
        CallTip(char, pos)
    end
end

function ShowListManualy()
    if cmpobj_GetFMDefault() == SCE_FM_SQL_DEFAULT or editor.Lexer == SCLEX_MSSQL then
        ShowListManualySql()
        return
    end
    pasteFromXml = (isXmlLine() ~= false)
	if get_api == true then
		ReCreateStructures()
	end
	if objects_table._fill == nil then return false end
    current_pos = editor.CurrentPos
    af_current_line = editor:LineFromPosition(current_pos)
    char = editor:textrange(current_pos - 1, current_pos)
    if pasteFromXml then
        for i = current_pos, 0,- 1 do
            char = editor:textrange(i - 1, i)
            if char == ' ' then
                ListXml(editor:textrange(i, current_pos))
                current_poslst = i
                return
            elseif char == '<' then
                pasteFromXml = false
                local word = editor:textrange(i , current_pos)
                methods_table, last = CreateMethodsTable({{'noobj','noobj','',''}}, objects_table, word, inheritors)

                ShowUserList(string.len(word), nil, last)
                current_poslst = i
                return
            elseif not string.find(char, "[%w_]") then
                return
            end
        end
    elseif string.find(char, "%s") then
        methods_table = CreateMethodsTable({{constObjGlobal, constObjGlobal, '', ''}}, objects_table, '')
        current_poslst = current_pos
        ShowUserList(0)
        return
    elseif string.find(char, autocom_chars) then
        RunAutocomplete(char, current_pos, '')
        return
    end
    current_poslst = editor:WordStartPosition(current_pos)
    wordpart = editor:textrange(current_poslst, current_pos)
    char = editor:textrange(current_poslst - 1, current_poslst)
    if string.find(char, autocom_chars) then
        tmpPos = current_poslst
        RunAutocomplete(char, current_poslst, wordpart)
        current_poslst = tmpPos
        return
    else
        methods_table = CreateMethodsTable({{constObjGlobal, constObjGlobal, '', ''}}, objects_table, wordpart)
        ShowUserList(string.len(wordpart))
        return
    end
end

local function OnDwellStart_local(pos, word)
    if (_G.iuprops['menus.tooltip.show'] or 0) ~= 1 then return end
    if pos == 0 then
        if CUR_POS.bymouse then
            HideCallTip()
            CUR_POS.bymouse = nil
        end
    else
        CUR_POS:Use(pos + 1)
        ShowTipManualy()
        CUR_POS:Use()
    end
end
------------------------------------------------------
AddEventHandler("OnChar", function(char)
    if not useAutocomp() then return end
	if props['macro-recording'] ~= '1' and OnChar_local(char) then return true end
	return result
end)
local bRun = true
AddEventHandler("OnUserListSelection", function(tp, sel_value)
    if not useAutocomp() then return end
	if bRun and(tp == constListIdXml or tp == constListId or tp == constListIdXmlPar) then
		if OnUserListSelection_local(tp, sel_value) then return true end
	end
    editor.AutoCHooseSingle = true
end)
local function OnSwitchLocal()
    editor.MouseDwellTime = 1000 --Пусть будет всегда, для всех, кто хочет
    CUR_POS.bymouse = nil
    CUR_POS:Use()
    bManualTip = false
	get_api = true
    ReCreateStructures()
    if Favorites_AddFileName ~=nil then  --  and StatusBar_obj ~= nil
        Favorites_ListFILL(true)
    end
    m_ext = editor.Lexer
    if m_ext == SCLEX_FORMENJINE then m_ptrn = props['pattern.name$'] end
    objPatern = Iif(editor_LexerLanguage() == 'css', '(%.?[%w%_-]+)$', '(%.?[%w%_]+)$')
end
AddEventHandler("OnSwitchFile", function(file)
    local pr = _G.iuprops["spell.autospell"]
    OnSwitchLocal()
    _G.iuprops["spell.autospell"] = pr
end)
AddEventHandler("OnOpen", OnSwitchLocal)
AddEventHandler("OnBeforeSave", function() get_api = true end)
AddEventHandler("OnUpdateUI", OnUpdateUI_local)
AddEventHandler("OnDwellStart", OnDwellStart_local)
