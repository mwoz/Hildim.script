-- COMMON.lua
-- Version: 1.12.0
---------------------------------------------------
-- ����� �������, �������������� �� ������ ��������
---------------------------------------------------

-- ���� ������ ������������ lua-��������� � �������
package.path  = props["SciteDefaultHome"].."\\tools\\LuaLib\\?.lua;"..package.path
package.cpath = props["SciteDefaultHome"].."\\tools\\LuaLib\\?.dll;"..package.cpath

--------------------------------------------------------
-- ����������� ����������������� ����������� � ������� SciTE
dofile(props["SciteDefaultHome"]..'\\tools\\eventmanager.lua')

-- ������� ������������� URL
dofile (props["SciteDefaultHome"].."\\tools\\URL_detect.lua")

--------------------------------------------------------
-- ������ ����� ������������� props['CurrentWord']
function GetCurrentWord()
	local current_pos = editor.CurrentPos
	return editor:textrange(editor:WordStartPosition(current_pos, true),
							editor:WordEndPosition(current_pos, true))
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

--------------------------------------------------------
-- ������ �-��� string.lower(), string.upper(), string.len()
-- �������� � ������ ������������� �����������
local function StringLower(s, cp)
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

--------------------------------------------------------
-- string.to_pattern ��������� ������, ��������� ��� �������������
-- � ���� �������� � string.find � �.�.
-- ��������: "xx-yy" -> "xx%-yy"
local lua_patt_chars = "[%(%)%.%+%-%*%?%[%]%^%$%%]" -- ����������� ���������� �������� ���:
function string.pattern( s )
	return (s:gsub(lua_patt_chars,'%%%0'))-- ���������� ������������� ��������� �������� �������� %
end

--------------------------------------------------------
-- ��������� �������� �� nil � ���� ��� ���, �� ���������� default, ����� ���������� ��� ��������
function ifnil(val, default)
	if val == nil then
		return default
	else
		return val
	end
end

--------------------------------------------------------
-- ����������� ������������� �� ����� ������� ����� �����������
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

	-- ��� ��������, ������������� � �������:
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
	-- ��� ��������� ��������:
	-- asn1, ave, blitzbasic, cmake, conf, eiffel, eiffelkw, erlang, euphoria, fortran, f77, freebasic, kix, lisp, lout, octave, matlab, metapost, nncrontab, props, batch, makefile, diff, purebasic, vb, yaml
	if style == 1 then return true end
	return false
end


------[[ T E X T   M A R K S ]]-------------------------

-- ��������� ������ �������� ������������� �����
function EditorMarkText(start, length, indic_number)
	local current_indic_number = scite.SendEditor(SCI_GETINDICATORCURRENT)
	scite.SendEditor(SCI_SETINDICATORCURRENT, indic_number)
	scite.SendEditor(SCI_INDICATORFILLRANGE, start, length)
	scite.SendEditor(SCI_SETINDICATORCURRENT, current_indic_number)
end

-- ������� ������ �� ���������� ��������� ��������� �����
--   ���� ��������� ���������� - ��������� ��� ����� �� ���� ������
--   ���� �� ������� ������� � ����� - ��������� ���� �����
function EditorClearMarks(indic_number, start, length)
	local _first_indic, _end_indic
	local current_indic_number = scite.SendEditor(SCI_GETINDICATORCURRENT)
	if indic_number == nil then
		_first_indic, _end_indic = 0, 31
	else
		_first_indic, _end_indic = indic_number, indic_number
	end
	if start == nil then
		start, length = 0, editor.Length
	end
	for indic = _first_indic, _end_indic do
		scite.SendEditor(SCI_SETINDICATORCURRENT, indic)
		scite.SendEditor(SCI_INDICATORCLEARRANGE, start, length)
	end
	scite.SendEditor(SCI_SETINDICATORCURRENT, current_indic_number)
end

----------------------------------------------------------------------------
-- ������� ����� ��� �������� (����� ��� ������� ����� ����� ������������ � ��������, ������� �� �� ������)

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
end

local function EditorInitMarkStyles()
	local string2value = {
		plain    = INDIC_PLAIN,    squiggle = INDIC_SQUIGGLE,
		tt       = INDIC_TT,       diagonal = INDIC_DIAGONAL,
		strike   = INDIC_STRIKE,   hidden   = INDIC_HIDDEN,
		roundbox = INDIC_ROUNDBOX, box      = INDIC_BOX,
		hotspot  = INDIC_HOTSPOT
	}
	for indic_number = 0, 31 do
		local mark = props["indic.style."..indic_number]
		if mark ~= "" then
			local indic_color = mark:match("#%x%x%x%x%x%x") or (props["find.mark"]):match("#%x%x%x%x%x%x") or "#0F0F0F"
			local indic_style = string2value[mark:match("%l+")] or INDIC_ROUNDBOX
			local indic_alpha = tonumber((mark:match("%@%d+") or ""):sub(2)) or 30
			InitMarkStyle(indic_number, indic_style, indic_color, indic_alpha)
		end
	end
	findrez.IndicStyle[31] = INDIC_ROUNDBOX
	findrez.IndicFore[31] = encodeRGB2WIN('#54FFB4')
	findrez.IndicAlpha[31] = 35
end

----------------------------------------------------------------------------
-- ��������� ������������ ������ �����, ���������� ������� �������� �������� �� ������ (��� �������)
local function SetMarginTypeN()
	editor.MarginTypeN[3] = SC_MARGIN_TEXT
	editor.MarginWidthN[3] = 1
end

----------------------------------------------------------------------------
-- �������������� ��������� ��������� ��������� (������������ ��� ������/��������� "�����" � ����)
function CheckChange(prop_name, withIup)
	local cur_prop = ifnil(tonumber(props[prop_name]), 0)
	props[prop_name] = 1 - cur_prop
    if withIup then  _G.iuprops[prop_name] = props[prop_name] end


end

-- ==============================================================
-- ������� ����������� os_copy(source_path,dest_path)
-- ����� z00n <http://www.lua.ru/forum/posts/list/15/89.page>
function os_copy(source_path,dest_path)
	-- "������������" �������
	local function unwind_protect(thunk,cleanup)
		local ok,res = pcall(thunk)
		if cleanup then cleanup() end
		if not ok then error(res,0) else return res end
	end
	-- ����� ������� ��� ������ � ��������� �������
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
--- ������ ����� .abbrev (�������� ���������� #import)
-- @return ������� ��� ����������-�����������
function ReadAbbrevFile(file, abbr_table)
	--[[------------------------------------------
	��������� ������ ����� ���������� �������� ���������
	������� ������������� ��� ������������� ������ io.lines(filename), � ����� ������ file:lines()
	������ ���� �� �������� SciTE: ��� ������� � ����� ������ ������� '\' ���������, ��� ������� ������ ������������ � ���������.
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
				-- ���� ���������� ������ import, �� ���������� �������� ��� �� �������
				if import_file then
					ReadAbbrevFile(file:match('.+\\')..import_file, abbr_table)
				end
			end
		end
	end
	abbrev_file:close()
	return abbr_table
end
--���������� �������� ��� ���� ����������
function DoForBuffers(func, ...)
    BlockEventHandler"OnSwitchFile"
    BlockEventHandler"OnClose"
    BlockEventHandler"OnNavigation"
    BlockEventHandler"OnUpdateUI"
    local curBuf = scite.buffers.GetCurrent()
    local maxN = scite.buffers.GetCount() - 1
    for i = 0,maxN do
        scite.buffers.SetDocumentAt(i)
        func(i, ...)
    end
    scite.buffers.SetDocumentAt(curBuf)
    UnBlockEventHandler"OnUpdateUI"
    UnBlockEventHandler"OnNavigation"
    UnBlockEventHandler"OnClose"
    UnBlockEventHandler"OnSwitchFile"
    return func(nil)
end

-- ==============================================================
-- �������, ������������� ������ ���� ���, ��� �������� ������� �����
--   ( ��������� �� �����, ��� �������� SciTEStartup.lua, ������
--   ������� ��������� �� ������: "Editor pane is not accessible at this time." )
AddEventHandler("OnOpen", function()
	string.lower = StringLower
	string.upper = StringUpper
	string.len = StringLen
	EditorInitMarkStyles()
	SetMarginTypeN()
end, 'RunOnce')

-- ���������� IUP
dofile (props["SciteDefaultHome"].."\\tools\\iupCommon.lua")