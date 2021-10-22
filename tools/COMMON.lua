-- COMMON.lua
-- Version: 1.12.0
---------------------------------------------------
-- Общие функции, использующиеся во многих скриптах
---------------------------------------------------
--Функция - создатель классов

function class()
    local c = {}
    c.__index = c
    c.__gc = function()
        if c.destroy then
            c.destroy()
        end
    end
    local mt = {}
    mt.__call = function(_, ...)
        self = setmetatable({}, c)
        if c.init then
            c.init(self, ...)
        end
        return self
    end
    return setmetatable(c, mt)
end
CORE = {}
CORE.onDestroy_event = {}
-- Пути поиска подключаемых lua-библиотек и модулей
-- local lib = props["SciteDefaultHome"].."\\tools\\LuaLib\\"
-- package.path  = lib.."?.lua;"..lib.."?\\?.lua;"..lib.."?\\init.lua;"
-- package.cpath = props["SciteDefaultHome"].."\\tools\\LuaLib\\?.dll;"..package.cpath

if not shell then shell = require"shell" end
--------------------------------------------------------
-- Подключение пользовательского обработчика к событию SciTE
dofile(props["SciteDefaultHome"]..'\\tools\\eventmanager.lua')

-- Функция распознавания URL
dofile (props["SciteDefaultHome"].."\\tools\\URL_detect.lua")

--------------------------------------------------------
-- Замена порой неработающего props['CurrentWord']
function GetCurrentWord(ed, p)
    ed = ed or editor
	local current_pos = p or ed.CurrentPos
	return ed:textrange(ed:WordStartPosition(current_pos, true),
							ed:WordEndPosition(current_pos, true))
end
function OnNavigation() end
function editor_LexerLanguage(bMenu)
    if not bMenu and editor.Lexer == 147 then return 'script_wiki' end
    return editor.LexerLanguage or 'script_'..props['FileExt']
end
--------------------------------------------------------
--- Returns current hotspot's text
function GetCurrentHotspot ()
	local s = editor.CurrentPos
	local e = s+1
	local l = editor.Length
	s = s-1 -- we know we're at hotspot
	while editor.StyleHotSpot[editor.StyleAt[s]] and s>=0 do s = s-1 end
	while editor.StyleHotSpot[editor.StyleAt[e]] and e<=l do e = e+1 end
	return editor:textrange(s+1,e)
end

function Iif(b,a,c)
    if b then return a end
    return c
end

--------------------------------------------------------
-- Замена ф-ций string.lower(), string.upper(), string.len()
-- Работает с любыми национальными кодировками
function StringLower(s, cp)
	if not cp then cp = props["editor.code.page"] end
	if cp ~= 65001 then s = s:to_utf8(cp) end
	s = s:utf8lower()
	if cp ~= 65001 then s = s:from_utf8(cp) end
	return s
end

local function StringUpper(s, cp)
    if s == nil then return s end
    s = tostring(s)
	if not cp then cp = props["editor.code.page"] end
	if cp ~= 65001 then s = s:to_utf8(cp) end
	s = s:utf8upper()
	if cp ~= 65001 then s = s:from_utf8(cp) end
	return s
end

local function StringLen(s, cp)
	if not cp then cp = props["editor.code.page"] end
	if cp ~= 65001 then s = s:to_utf8(cp) end
	return s:utf8len()
end

function CORE.Rgb2Str(rgb)
    rgb = math.tointeger(rgb) or 0
    return ''..(rgb & 255)..' '..((rgb >> 8) & 255)..' '..((rgb >> 16) & 255)
end
function CORE.Str2Rgb(s, def)
    local _, _, r, g, b = s:find('(%d+) (%d+) (%d+)')
    if r then
        return (tonumber(b) << 16)|(tonumber(g) << 8)|tonumber(r)
    end
    return def
end

--------------------------------------------------------
-- string.to_pattern возращает строку, пригодную для использования
-- в виде паттерна в string.find и т.п.
-- Например: "xx-yy" -> "xx%-yy"
local lua_patt_chars = "[%(%)%.%+%-%*%?%[%]%^%$%%]" -- управляющие паттернами символов Луа:
function string.pattern( s )
	return (s:gsub(lua_patt_chars,'%%%0'))-- фактически экранирование служебных символов символом %
end

--------------------------------------------------------
-- Проверяет параметр на nil и если это так, то возвращает default, иначе возвращает сам параметр
function ifnil(val, default)
	if val == nil then
		return default
	else
		return val
	end
end

CORE.EOL = function()
    if editor.EOLMode == SC_EOL_CR then return "\r"
    elseif editor.EOLMode == SC_EOL_LF then return "\n" end
    return "\r\n"
end
--------------------------------------------------------
-- Определение соответствует ли стиль символа стилю комментария
function IsComment(pos)
	local style = editor.StyleAt[pos]
    local fmSektor = cmpobj_GetFMDefault()
    if fmSektor >= 0 then
        if fmSektor == SCE_FM_DEFAULT then return false end
        if fmSektor == SCE_FM_VB_DEFAULT then return (style == SCE_FM_VB_COMMENT) end
        if fmSektor == SCE_FM_X_DEFAULT then return (style == SCE_FM_X_COMMENT) end
        return (style == SCE_FM_SQL_LINE_COMMENT or style == SCE_FM_SQL_COMMENT)
    end
	local lexer = props['Language']
	local comment = {
		abap = {1, 2},
		ada = {10},
		asm = {1, 11},
		au3 = {1, 2},
		baan = {1, 2},
		bullant = {1, 2, 3},
		caml = {12, 13, 14, 15},
		cpp = {1, 2, 3, 15, 17, 18},
		csound = {1, 9},
		css = {9},
		d = {1, 2, 3, 4, 15, 16, 17},
		escript = {1, 2, 3},
		flagship = {1, 2, 3, 4, 5, 6},
		forth = {1, 2, 3},
		gap = {9},
		hypertext = {9, 20, 29, 42, 43, 44, 57, 58, 59, 72, 82, 92, 107, 124, 125},
		xml = {9, 29},
		inno = {1, 7},
		latex = {4},
		lua = {1, 2, 3},
		script_lua = {4, 5},
		mmixal = {1, 17},
		nsis = {1, 18},
		opal = {1, 2},
		pascal = {1, 2, 3},
		perl = {2},
		bash = {2},
		pov = {1, 2},
		ps = {1, 2, 3},
		python = {1, 12},
		rebol = {1, 2},
		ruby = {2},
		scriptol = {2, 3, 4, 5},
		smalltalk = {3},
		specman = {2, 3},
		spice = {8},
		sql = {1, 2, 3, 13, 15, 17, 18},
		mssql = {1, 2, 3, 13, 15, 17, 18},
		tcl = {1, 2, 20, 21},
		verilog = {1, 2, 3},
		vhdl = {1, 2}
	}

	-- Для лексеров, перечисленных в массиве:
	for l,ts in pairs(comment) do
		if l == lexer then
			for _,s in pairs(ts) do
				if s == style then
					return true
				end
			end
			return false
		end
	end
	-- Для остальных лексеров:
	-- asn1, ave, blitzbasic, cmake, conf, eiffel, eiffelkw, erlang, euphoria, fortran, f77, freebasic, kix, lisp, lout, octave, matlab, metapost, nncrontab, props, batch, makefile, diff, purebasic, vb, yaml
	if style == 1 then return true end
	return false
end


------[[ T E X T   M A R K S ]]-------------------------

-- Выделение текста маркером определенного стиля
function EditorMarkText(start, length, indic_number)
	local current_indic_number = editor.IndicatorCurrent
	editor.IndicatorCurrent = indic_number
	editor:IndicatorFillRange(start, length)
	editor.IndicatorCurrent = current_indic_number
end

-- Очистка текста от маркерного выделения заданного стиля
--   если параметры отсутствуют - очищаются все стили во всем тексте
--   если не указана позиция и длина - очищается весь текст
function EditorClearMarks(indic_number, start, length, bCo)
    local e
    if bCo then e = coeditor;  else e = editor end
    local _first_indic, _end_indic
	local current_indic_number = e.IndicatorCurrent
	if indic_number == nil then
		_first_indic, _end_indic = 0, 31
	else
		_first_indic, _end_indic = indic_number, indic_number
	end
	if start == nil then
		start, length = 0, e.Length
	end
	for indic = _first_indic, _end_indic do
        e.IndicatorCurrent = indic
		e:IndicatorClearRange(start, length)
	end
	e.IndicatorCurrent = current_indic_number
end

----------------------------------------------------------------------------
-- Задание стиля для маркеров (затем эти маркеры можно tomorrow будет использовать в скриптах, вызывая их по номеру)

-- Translate color from RGB to win
local function encodeRGB2WIN(color)
	if string.sub(color,1,1)=="#" and string.len(color)>6 then
		return tonumber(string.sub(color,6,7)..string.sub(color,4,5)..string.sub(color,2,3), 16)
	else
		return color
	end
end

local function InitMarkStyle(indic_number, indic_style, indic_color, indic_alpha)
	editor.IndicStyle[indic_number] = indic_style
	editor.IndicFore[indic_number] = encodeRGB2WIN(indic_color)
	editor.IndicAlpha[indic_number] = indic_alpha
	coeditor.IndicStyle[indic_number] = indic_style
	coeditor.IndicFore[indic_number] = encodeRGB2WIN(indic_color)
	coeditor.IndicAlpha[indic_number] = indic_alpha
end

local tIndicMap = {_rev ={}}
local indicMin, indicMax = 12, 31

function CORE.InidcFactory(id, description, style, fore, alfa)
    if tIndicMap._rev[id] then return tIndicMap._rev[id] end
    if not _G.iuprops['INDICATORS'] then _G.iuprops['INDICATORS'] = {} end
    local tI = _G.iuprops['INDICATORS']
    if tI[id] then
        style, fore, alfa = tI[id].s, tI[id].f, tI[id].a
    else
        tI[id] = {s = style; f = fore; a = alfa, rem = description}
    end
    for i = indicMin, indicMax do
        if not tIndicMap[i] then
            tIndicMap[i] = id
            tIndicMap._rev[id] = i
            return i
        end
    end
    return nil
end

function CORE.FreeIndic(i)
    if tIndicMap[i] then
        local id = tIndicMap[i]
        tIndicMap._rev[id] = nil
        tIndicMap[i] = nil
    end
end

function CORE.InitMarkStyles()
    local tII
    for i, id in pairs(tIndicMap) do
        if type(i) == 'number' then
            tII = _G.iuprops['INDICATORS'][id]
            InitMarkStyle(i, tII.s, tII.f, tII.a)
        end
    end
end
function CORE.EditMarkColor(iMrk)
    return CORE.Rgb2Str(_G.iuprops['INDICATORS'][tIndicMap[iMrk]].f)
end

local function EditorInitMarkStyles()

	findres.IndicStyle[31] = INDIC_ROUNDBOX
	findres.IndicFore[31] = encodeRGB2WIN('#54FFB4')
	findres.IndicAlpha[31] = 35
end

----------------------------------------------------------------------------
-- Отрисовка вертикальной тонкой линии, отделяющей колонку маркеров фолдинга от текста (для красоты)
local function SetMarginTypeN()
	editor.MarginTypeN[3] = SC_MARGIN_TEXT
	editor.MarginWidthN[3] = 1
end

----------------------------------------------------------------------------
-- Инвертирование состояния заданного параметра (используется для снятия/установки "галок" в меню)
function CheckChange(prop_name, withIup)
	local cur_prop = ifnil(tonumber(props[prop_name]), 0)
	props[prop_name] = 1 - cur_prop
    if withIup then  _G.iuprops[prop_name] = props[prop_name] end
end

-- ==============================================================
-- Функция копирования os_copy(source_path,dest_path)
-- Автор z00n <http://www.lua.ru/forum/posts/list/15/89.page>
function os_copy(source_path,dest_path)
	-- "библиотечная" функция
	local function unwind_protect(thunk,cleanup)
		local ok,res = pcall(thunk)
		if cleanup then cleanup() end
		if not ok then error(res,0) else return res end
	end
	-- общая функция для работы с открытыми файлами
	local function with_open_file(name,mode)
		return function(body)
		local f, err = io.open(name,mode)
		if err then return end
		return unwind_protect(function()return body(f) end,
			function()return f and f:close() end)
		end
	end
	----------------------------------------------
	return with_open_file(source_path,"rb") (function(source)
		return with_open_file(dest_path,"wb") (function(dest)
			assert(dest:write(assert(source:read("*a"))))
			return true
		end)
	end)
end

-- ==============================================================
--- Читает файлы .abbrev (понимает инструкцию #import)
-- @return Таблица пар сокращение-расшифровка
function CORE.ReadAbbrevFile(file, abbr_table)
	--[[------------------------------------------
	Эмулирует чтение файла внутренней функцией редактора
	Функция предназначена для использования вместо io.lines(filename), а также вместо file:lines()
	Читает файл по правилам SciTE: при наличии в конце строки символа '\' считается, что текущая строка продолжается в следующей.
	@usage: for l in scite_io_lines('c:\\some.file') do print(l) end
	  alternative:
	f = io.open('s:\\some.file')
	for l in scite_io_lines(f) do print(l) end
	--]]------------------------------------------
	local function scite_io_lines(file)
		local line_iter = type(file)=='string' and io.lines(file) or file:lines()
		local scite_iter = function()
			local line = line_iter()
			if not line then return end
			-- start [SciTE]
			while string.sub(line,-1)=='\\' do
				line = string.sub(line,1,-2)..line_iter()
			end
			-- end [SciTE]
			return line
		end
		return scite_iter
	end
	--------------------------------------------
	local abbrev_file, err, errcode = io.open(file)
	if not abbrev_file then return abbrev_file, err, errcode end

	local abbr_table = abbr_table or {}
	local ignorecomment = tonumber(props['abbrev.'..props['Language']..'.ignore.comment'])==1
	for line in scite_io_lines(abbrev_file) do
		if line ~= '' and (ignorecomment or line:sub(1,1) ~= '#' ) then
			local _abr, _exp = line:match('^(.-)=(.+)')
			if _abr then
				abbr_table[#abbr_table+1] = {abbr=_abr, exp=_exp}
			else
				local import_file = line:match('^import%s+(.+)')
				-- если обнаружена запись import, то рекурсивно вызываем эту же функцию
				if import_file then
					CORE.ReadAbbrevFile(file:match('.+\\')..import_file, abbr_table)
				end
			end
		end
	end
	abbrev_file:close()
	return abbr_table
end

function CORE.RelativePath(current_path)
    local eDir = props["FileDir"]..'\\'
    local sRet
    if eDir == current_path then
        sRet = ''
    elseif eDir:find('^'..current_path) then
        sRet = eDir:gsub('^'..current_path, ''):gsub('[^\\]+', "..")
    elseif current_path:find('^'..eDir) then
        sRet = current_path:gsub('^'..eDir, '')
    else
        local strBeg = ''
        for subpath in current_path:gmatch('[^\\]+') do
            if not (eDir:find(strBeg..subpath..'\\', 1, true) == 1) then break end
            strBeg = strBeg..subpath..'\\'
        end
        if sRet ~= '' then
        sRet = eDir:sub(#strBeg + 1):gsub('[^\\]+', "..")..current_path:sub(#strBeg + 1)
        else
            sRet = current_path
        end
    end
    return sRet
end

--Выполнение действия для всех документов
local function DoForBuffers_local(func, bStc, cmdEnd, ...)
    scite.BlockUpdate(UPDATE_BLOCK)
    BlockEventHandler"OnSwitchFile"
    BlockEventHandler"OnNavigation"
    BlockEventHandler"OnUpdateUI"
    BlockEventHandler"OnSave"
    BlockEventHandler"OnClose"
    BlockEventHandler"OnBeforeSave"
    BlockEventHandler"OnIdle"
    local curBuf = scite.buffers.GetCurrent()
    local maxN = scite.buffers.GetCount() - 1
    local fvl = editor.FirstVisibleLine
    editor.VScrollBar = false
    for i = maxN,0,-1 do
        scite.buffers.SetDocumentAt(i, bStc, false)
        func(i, ...)
    end
    editor.VScrollBar = true
    editor.FirstVisibleLine = fvl
    UnBlockEventHandler"OnBeforeSave"
    UnBlockEventHandler"OnClose"
    UnBlockEventHandler"OnSave"
    UnBlockEventHandler"OnUpdateUI"
    UnBlockEventHandler"OnNavigation"
    UnBlockEventHandler"OnSwitchFile"
    UnBlockEventHandler"OnIdle"
    scite.buffers.SetDocumentAt(curBuf)
    scite.BlockUpdate(cmdEnd)
    return func(nil)
end
function DoForBuffers(func, ...)
    return DoForBuffers_local(func, true, UPDATE_UNBLOCK, ...)
end
function DoForBuffers_Stack(func, ...)
    return DoForBuffers_local(func, false, UPDATE_FORCE, ...)
end

function CORE.tbl2Out(tIn, sSep, byIpairs, brashes, upLvl)

    local function val2str(v, n)
        local tp = type(v)
        if tp == 'nil' then v = nil
        elseif tp == 'boolean' or tp == 'number' then v = tostring(v)
        elseif tp == 'string' then
            v = "'"..v:gsub('\\', '\\\\'):gsub("'", "\\039").."'"
        elseif tp == 'table' then
            v = '{\n'..CORE.tbl2Out(v, ' ', true)..'}'
        else
            v = nil
        end
        return v
    end

    if type(tIn) == 'table' then
        local t = {}
        local tI
        if tIn.tooutput then tI = tIn:tooutput()
        else tI = tIn end

        if byIpairs then
            for n, v in ipairs(tI) do
                v = val2str(v)
                if v then table.insert(t, v..",") end
            end
        end
        for n, v in pairs(tI) do
            if type(n) == 'string' then
                v = val2str(v)
                if v then table.insert(t, '["'..n..'"] = '..v..","..Iif(upLvl, '\n', '')) end
            end
        end
        local vOut = table.concat(t, sSep)
        if brashes then vOut = Iif(upLvl,'return ', '')..'{\n'..vOut..'}' end
        return vOut
    else
        return val2str(tIn)
    end
end

function debug_prnTb(tb, n)
    local s = string.rep('    ', n)
    for k,v in pairs(tb) do
        if type(v) == 'table' then
            print(s..k..'->  Table')
            debug_prnTb(v, n + 1)
        else
            print(s..k..'->  ', v)
        end
    end
end

function debug_prnArgs(...)
    print('-------------')
    local arg = table.pack(...)
    for i = 1, #arg do
        if type(arg[i]) == 'table' then
            print(i..'->  Table')
            debug_prnTb(arg[i], 1)
        else
            print(i..'->  ',arg[i])
        end
    end
end

function Trim(str)
    return str:gsub('^ +',''):gsub(' +$', '')
end

function catch(what)
   return what[1]
end

function try(what)
   status, result = pcall(what[1])
   if not status then
      what[2](result)
   end
   return result
end
-- ==============================================================
-- Функции, выполняющиеся только один раз, при открытии первого файла
--   ( Выполнить их сразу, при загрузке SciTEStartup.lua, нельзя
--   получим сообщение об ошибке: "Editor pane is not accessible at this time." )
AddEventHandler("OnInitHildiM", function()
	string.lower = StringLower
	string.upper = StringUpper
	string.len = StringLen
	EditorInitMarkStyles()
    CORE.InitMarkStyles()
	SetMarginTypeN()
end)

local s = class()
function s:lop()
    for i = #self.data.lst, self.maxN + 1, -1 do
        table.remove(self.data.lst,i)
        table.remove(self.data.pos, i)
        table.remove(self.data.layout,i)
        table.remove(self.data.bmk, i)
    end
end

function s:init(t)
    self.maxN = t[1]

    if not t[2] then
        self.data = {lst = {}; pos = {}; layout = {}; bmk = {}; enc = {}}
    elseif not t[2].lst then
        tn = {}; tn.lst = t[2]; tn.pos = {}; tn.layout = {}; tn.bmk = {}; tn.enc = {};
        for i = 1,  #t[2] do
            tn.pos[i] = 0
            tn.layout[i] = ''
            tn.bmk[i] = ''
        end
        self.data = tn
    else
        self.data = t[2]
        if not self.data.pos then self.data.pos = {} end
        if not self.data.layout then self.data.layout = {} end
        if not self.data.bmk then self.data.bmk = {} end
        if not self.data.enc then self.data.enc = {} for i = 1, #(self.data.pos) do self.data.enc[i] = 0 end  end
    end
    self:lop()
end
function s:ins(v, p, l, b, e)
    for i = #self.data.lst, 1, -1 do
        if self.data.lst[i] == v then
            table.remove(self.data.lst, i)
            table.remove(self.data.pos, i)
            table.remove(self.data.layout, i)
            table.remove(self.data.bmk, i)
            table.remove(self.data.enc, i)
        end
    end
    table.insert(self.data.lst, 1, v)
    table.insert(self.data.pos, 1, p)
    table.insert(self.data.layout, 1, l)
    table.insert(self.data.bmk, 1, b)
    table.insert(self.data.enc, 1, e)
    self:lop()
end

function s:tooutput()
    local res = {}
    res.lst = self.data.lst
    res.pos = self.data.pos
    res.bmk = self.data.bmk
    res.layout = self.data.layout
    res.enc = self.data.enc
    return res
end

_G.oStack = s

function _T(s) return s end
function _TH(s) return s end
function _TM(s) return s end

if shell.fileexists(props["SciteDefaultHome"]..'\\locale\\HilduM_'..props['locale']..'.locale') then
    dofile(props["SciteDefaultHome"]..'\\locale\\HilduM_'..props['locale']..'.locale')
    _TH = function(s) return __LOCALE.HildiM[s] or s end
    _TM = function(s) return __LOCALE.Menu[s:gsub('&([^& ])', '%1')] or s end
else
    props['locale'] = ''
end

function _GetLocale(fname)
    return function(s) return __LOCALE[fname][s] or s end
end

function _FMT(s, ...)
    local arg = table.pack(...)
    for i = 1, #arg do
        s = s:gsub('%%'..i, arg[i])
    end
    return s
end

function _HildiAlarm(msg, t, p1, p2, p3)

    msg = _FMT(_TH(msg), p1, p2, p3)
    local b1, b2, b3
--MB_OK                       0x00000000L
--MB_OKCANCEL                 0x00000001L
--MB_YESNOCANCEL              0x00000003L
--MB_YESNO                    0x00000004L
    t = t & 0xf
 -- print(t)

    if t == 0 then
        b1 = _TH"OK"
    elseif t == 1 then
        b1 = _TH"OK"
        b2 = _TH"Cancel"
    else
        b1 = _TH"Yes"
        b2 = _TH"No"
    if t == 3 then b3 = _TH"Cancel" end
    end
    local ret = iup.Alarm('HildiM', msg, b1, b2, b3)
--IDOK                1
--IDCANCEL            2
--IDABORT             3
--IDRETRY             4
--IDIGNORE            5
--IDYES               6
--IDNO                7
    local rez = 1
    if t == 1 then
        rez = ret
    elseif t == 3 or t == 4 then
        rez = ret + 5
    if rez == 8 then rez = 2 end
    end
    return rez
end

function _LocalizeText(msg)
    return _TH(msg)
end

function dolocale(s)
    local s_name = s:gsub('.lua$', '')
    local _, _, l_name = s_name:find('([^\\]+)$')
    local trans = false
    if props['locale'] ~= '' then
        if __LOCALE[s_name] then
            trans = true
        elseif shell.fileexists(props["SciteDefaultHome"]..'\\locale\\'..l_name..'_'..props['locale']..'.locale') then
            __LOCALE[s_name] = dofile(props["SciteDefaultHome"]..'\\locale\\'..l_name..'_'..props['locale']..'.locale')
            trans = true
        end
    end
    if trans then
        local f = io.open(props["SciteDefaultHome"]..'\\'..s)
        if not f then print("Can't open "..props["SciteDefaultHome"]..s); return nil end
        local t = 'local _T = _GetLocale("'..s_name:gsub('\\', '\\\\')..'")\r\n'..f:read('*a')
        f:close()
        return dostring(t)
    else
        return dofile(props["SciteDefaultHome"]..'\\'..s)
    end
end


-- Расширение IUP
dofile (props["SciteDefaultHome"].."\\tools\\iupCommon.lua")
