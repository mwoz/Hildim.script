
local _show_flags = tonumber(_G.iuprops['sidebar.functions.flags']) == 1
local _show_params = tonumber(_G.iuprops['sidebar.functions.params']) == 1

local _group_by_flags = tonumber(_G.iuprops['sidebar.functions.group']) == 1
local _sort = _G.iuprops['sidebar.functions.sort']
if _sort == '' then _sort = 'name' end
local  i

local fnTryGroupName

local tree_func

local currentLine = -1
local currFuncData = -1

local currentItem = 0
local lineMap  -- падает дерево на userdata(((
lineMap = {}

local table_functions = {}
-- 1 - function names
-- 2 - line number
-- 3 - function parameters with parentheses
--[[local function prnTb(tb, n)
    local s = string.rep('    ', n)
    for k,v in pairs(tb) do
        if type(v) == 'table' then
            print(s..k..'->  Table')
            prnTb(v, n + 1)
        else
            print(s..k..'->  ', v)
        end
    end
end]]
local _backjumppos -- store position if jumping
local line_count = 0
local layout --имена полей - имена бранчей, значения - true/false, если отсутствует - значит открыто
layout = {}
local m__CLASS = '~~ROOT'
local m_Par1
local Lang2lpeg = {}
do
	local P, V, Cg, Ct, Cc, S, R, C, Carg, Cf, Cb, Cp, Cmt = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.S, lpeg.R, lpeg.C, lpeg.Carg, lpeg.Cf, lpeg.Cb, lpeg.Cp, lpeg.Cmt

	--@todo: переписать с использованием lpeg.Cf
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

	local PosToLine = function (pos) return editor:LineFromPosition(pos-1) end

--v------- common patterns -------v--
	-- basics
	local EOF = P(-1)
	local BOF = P(function(s,i) return (i==1) and 1 end)
	local NL = P"\n"-- + P"\f" -- pattern matching newline, platform-specific. \f = page break marker
	local AZ = R('AZ','az')+"_"
	local N = R'09'
	local ANY =  P(1)
	local ESCANY = P'\\'*ANY + ANY
	local SINGLESPACE = S'\n \t\r\f'
	local SPACE = SINGLESPACE^1

	-- simple tokens
	local IDENTIFIER = AZ * (AZ+N)^0 -- simple identifier, without separators

	local Str1 = P'"' * ( ESCANY - (S'"'+NL) )^0 * (P'"' + NL)--NL == error'unfinished string')
	local Str2 = P"'" * ( ESCANY - (S"'"+NL) )^0 * (P"'" + NL)--NL == error'unfinished string')
	local STRING = Str1 + Str2

	-- c-like-comments
	local line_comment = '//' * (ESCANY - NL)^0*NL
	local block_comment = '/*' * (ESCANY - P'*/')^0 * (P('*/') + EOF)
	local COMMENT = (line_comment + block_comment)^1

	local SC = SPACE + COMMENT
	local IGNORED = SPACE + COMMENT + STRING
	-- special captures
	local cp = Cp() -- pos capture, Carg(1) is the shift value, comes from start_code_pos
	local cl = cp/PosToLine -- line capture, uses editor:LineFromPosition
	local par = C(P"("*(1-P")")^0*P")") -- captures parameters in parentheses
--^------- common patterns -------^--

	do --v------- asm -------v--
		-- redefine common patterns
		local SPACE = S' \t'^1
		local NL = P"\r\n"

		local IGNORED = (ESCANY - NL)^0 * NL -- just skip line by line

		-- define local patterns
		local p = P"proc"
		local F = P"FRAME"
		-- create flags:
		F = Cg(F*Cc(true),'F')
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local par = C((ESCANY - NL)^0)
		local def1 = I*SPACE*(p+F)
		local def2 = p*SPACE*I*P','^-1
		local def = (SPACE+P'')*Ct((def1+def2)*(SPACE*par)^-1)*NL
		-- resulting pattern, which does the work
		local patt = (def + IGNORED + 1)^0 * EOF

		Lang2lpeg.Assembler = lpeg.Ct(patt)
	end --do --^------- ASM -------^--

	do --v------- Lua -------v--
		-- redefine common patterns
    local IDENTIFIER = IDENTIFIER *(P'.' * IDENTIFIER)^0 *(P':' * IDENTIFIER)^- 1
		-- LONG BRACKETS
		local long_brackets = #(P'[' * P'='^0 * P'[') *
			function (subject, i1)
				local level = _G.assert( subject:match('^%[(=*)%[', i1) )
				local _, i2 = subject:find(']'..level..']', i1, true)  -- true = plain "find substring"
				return (i2 and (i2+1)) or #subject+1--error('unfinished long brackets')
				-- ^ if unfinished long brackets then capture till EOF (at #subject+1)
		end
		local LUALONGSTR = long_brackets

		local multi  = P'--' * long_brackets
		local single = P'--' * (1 - NL)^0 * NL
		local COMMENT = multi + single
		local SC = SPACE + COMMENT

		local IGNORED = SPACE + COMMENT + STRING + LUALONGSTR

		-- define local patterns
		local f = P"function"
		local l = P"local"
		-- create flags
		l = Cg(l*SC^1*Cc(true),'LocaleFun')^-1
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		local I2 = (C(IDENTIFIER) /(function(a) local _, _, c = a:find('^(.-)[%.:]'); m__CLASS = c or '~~ROOT' ;return a end)) * cl
		-- definitions to capture:
		local funcdef1 = l*f*SC^1*I2*SC^0*par -- usual function declaration
        local funcdef2 = l * I * SC^0 * "=" * SC^0 * P"(" * f * SC^0 * par -- declaration through assignment
        local aeh = P'AddEventHandler' * Cg(Cc(true),'EventHandler') * (SC + P'(')^0 * S[["']] * I * S[["']]
		local def = Ct((funcdef1 + funcdef2 + aeh)*(Cc'' / function() return m__CLASS end))
		-- resulting pattern, which does the work
		local patt = (def + IGNORED^1 + IDENTIFIER + 1)^0 * (EOF) --+ error'invalid character')

		Lang2lpeg.Lua = lpeg.Ct(patt)
	end --do --^------- Lua -------^--

	do --v----- Pascal ------v--
		-- redefine common patterns
		local IDENTIFIER = IDENTIFIER*(P'.'*IDENTIFIER)^0
		local STRING = P"'" *( ANY - (P"'"+NL) )^0 *(P"'"+NL) --NL == error'unfinished string')
		--^ there's no problem with pascal strings with double single quotes in the middle, like this:
		--  'first''second'
		--  in the loop, STRING just matches the 'first'-part, and then the 'second'.

		local multi1  = P'(*' *(1-P'*)')^0 * (P'*)' + EOF)--unfinished long comment
		local multi2  = P'{' *(1-P'}')^0 * (P'}' + EOF)--unfinished long comment
		local single = P'//' * (1 - NL)^0 * NL
		local COMMENT = multi1 + multi2 + single

		local SC = SPACE + COMMENT
		local IGNORED = SPACE + COMMENT + STRING

		-- define local patterns
		local f = AnyCase"function"
		local p = AnyCase"procedure"
		local c = AnyCase"constructor"
		local d = AnyCase"destructor"
		local restype = AZ^1
		-- create flags:
		-- f = Cg(f*Cc(true),'f')
		restype = Cg(C(restype),'')
		p = Cg(p*Cc(true),'p')
		c = Cg(c*Cc(true),'c')
		d = Cg(d*Cc(true),'d')
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local procdef = Ct((p+c+d)*SC^1*I*SC^0*par^-1)
		local funcdef = Ct(f*SC^1*I*SC^0*par^-1*SC^0*P':'*SC^0*restype*SC^0*P';')
		-- resulting pattern, which does the work
		local patt = (procdef + funcdef + IGNORED^1 + IDENTIFIER + 1)^0 * EOF

		Lang2lpeg.Pascal = lpeg.Ct(patt)
	end --^----- Pascal ------^--

	do --v----- C++ ------v--
		-- define local patterns
		local keywords = P'if'+P'else'+P'switch'+P'case'+P'while'+P'for'
		local nokeyword = -(keywords)
		local type = P"static "^-1*P"const "^-1*P"enum "^-1*P'*'^-1*IDENTIFIER*P'*'^-1
		local funcbody = P"{"*(ESCANY-P"}")^0*P"}"
		-- redefine common patterns
		local IDENTIFIER = P'*'^-1*P'~'^-1*IDENTIFIER
		IDENTIFIER = IDENTIFIER*(P"::"*IDENTIFIER)^-1
		-- create flags:
		type = (C(type)/function(a) m_Par1 = a end) * Cg('', '')
		-- create additional captures
		local I = nokeyword *(C(IDENTIFIER) /(function(a) local _, _, c, e = a:find('^(.-)::(.+)'); m__CLASS = c or '~~ROOT'; return e or a end)) * cl
		-- definitions to capture:
		local funcdef = nokeyword * Ct((type * SC^1)^- 1 * I * SC^0 *(par / function(a) return ': '..m_Par1..' '..a end ) * SC^0 *(#funcbody) *(Cc'' / function() return m__CLASS end))
		local classconstr = nokeyword*Ct((type*SC^1)^-1*I*SC^0*par*SC^0*P':'*SC^0*IDENTIFIER*SC^0*(P"("*(1-P")")^0*P")")*SC^0*(#funcbody)) -- this matches smthing like PrefDialog::PrefDialog(QWidget *parent, blabla) : QDialog(parent)
		-- resulting pattern, which does the work
		local patt = (classconstr + funcdef + IGNORED^1 + IDENTIFIER + ANY)^0 * EOF

		Lang2lpeg['C++'] = lpeg.Ct(patt)
	end --^----- C++ ------^--

	do --v----- JS ------v--
		-- redefine common patterns
		local NL = NL + P"\f"
		local regexstr = P'/' * (ESCANY - (P'/' + NL))^0*(P'/' * S('igm')^0 + NL)
		local STRING = STRING + regexstr
		local IGNORED = SPACE + COMMENT + STRING
		-- define local patterns
		local f = P"function"
		local m = P"method"
		local funcbody = P"{"*(ESCANY-P"}")^0*P"}"
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local funcdef =  Ct((f+m)*SC^1*I*SC^0*par*SC^0*(#funcbody))
		local eventdef = Ct(P"on"*SC^1*P'"'*I*P'"'*SC^0*(#funcbody))
		-- resulting pattern, which does the work
		local patt = (funcdef + eventdef + IGNORED^1 + IDENTIFIER + 1)^0 * EOF

		Lang2lpeg.JScript = lpeg.Ct(patt)
	end --^----- JS ------^--

	do --v----- VB ------v--
		-- redefine common patterns
		local SPACE = (S(" \t")+P"_"*S(" \t")^0*(P"\r\n"))^1
		local SC = SPACE
		local BR = P'"'
		local NL = (P"\r\n")^1*SC^0
		local STRING = P'"' * (ANY - (P'"' + P"\r\n"))^0*P'"'
		local COMMENT = (P"'" + P"REM ") * (ANY - P"\r\n")^0
		local IGNORED = SPACE + COMMENT + STRING
		local I = C(IDENTIFIER)*cl
		-- define local patterns
		local f = AnyCase"function"
		local p = AnyCase"property"
			local let = AnyCase"let"
			local get = AnyCase"get"
			local set = AnyCase"set"
			local public = AnyCase"public"
			local private = AnyCase"private"
		local s = AnyCase"sub"
        local fr=Cmt(AnyCase"<frame name=",(function(s,i) if _group_by_flags then return i else return nil end end))
        local str=Cmt(AnyCase"<string id=",(function(s,i) if _group_by_flags then return i else return nil end end))
		local con=Cmt(AnyCase"const",(function(s,i) if _group_by_flags then return i else return nil end end))
		local dim=Cmt(AnyCase"dim",(function(s,i) if _group_by_flags then return i else return nil end end))
		--local class=Cmt(AnyCase"class",(function(s,i) if _group_by_flags then return i else return nil end end))

		--local scr=P("<script>")
		--local stt=P("<stringtable>")

		local restype = (P"As"+P"as")*SPACE*Cg(C(AZ^1),'')
		let = Cg(let*Cc(false),' {LET}')
		get = Cg(get*Cc(false),' {GET}')
		set = Cg(set*Cc(false),' {SET}')
		private = Cg(private*Cc(false),' {PRIVATE}')
		public = Cg(public*Cc(false),' {PUBLIC}')
        p = Cg(p*Cc(true),'Property')
		p = NL*((private+public)*SC^1)^0*p*SC^1*(let+get+set)
		s = NL*((private+public)*SC^1)^0*Cg(s*Cc(true),'Sub')
		f = NL*((private+public)*SC^1)^0*Cg(f*Cc(true),'Function')
		dim = NL*Cg(dim*Cc(true),"Dim")
		con = NL*Cg(con*Cc(true),"Constant")
		fr = NL*Cg(fr*Cc(true),"Frame")
		str = NL*Cg(str*Cc(true),"String")
        local ec = NL*AnyCase"end"*SC^1*(AnyCase"class") / (function(a,b) m__CLASS = '~~ROOT'; end)

		local e = NL*AnyCase"end"*SC^1*(AnyCase"sub"+AnyCase"function"+AnyCase"property")
		local body = (IGNORED^1 + IDENTIFIER + 1 - f - s - p - e)^0*e

		-- definitions to capture:
		f = f*SC^1*I*SC^0*par
		p = p*SC^1*I*SC^0*par
		s = s*SC^1*I*SC^0*par
		con = con*SC^1*I
		dim = dim*SC^1*I
		fr = fr*BR^1*I
		str = str*BR^1*I
		local class = (AnyCase"class")*SC^1*(I / function(a,b) m__CLASS = a; end)
		local def = Ct(((f + s + p)*(SPACE*restype)^-1)*(Cc('')/function() return m__CLASS end))*body + Ct(dim+con+fr+str)+class + ec
		-- resulting pattern, which does the work

		local patt = (def + IGNORED^1 + IDENTIFIER + (1-NL)^1 + NL)^0 * EOF

		Lang2lpeg.VisualBasic = lpeg.Ct(patt)
	end --^----- VB ------^--]]


	do --v------- Python -------v--
		-- redefine common patterns
		local SPACE = S' \t'^1
		local IGNORED = (ESCANY - NL)^0 * NL -- just skip line by line
		-- define local patterns
		local c = P"class"
		local d = P"def"
		-- create flags:
		c = Cg(c*Cc(true),'class')
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local def = (c+d)*SPACE*I
		def = (SPACE+P'')*Ct(def*SPACE^-1*par)*SPACE^-1*P':'
		-- resulting pattern, which does the work
		local patt = (def + IGNORED + 1)^0 * EOF

		Lang2lpeg.Python = lpeg.Ct(patt)
	end --do --^------- Python -------^--

	do --v------- nnCron -------v--
		-- redefine common patterns
		local IDENTIFIER = (ANY - SPACE)^1
		local SPACE = S' \t'^1
		local IGNORED = (ESCANY - NL)^0 * NL -- just skip line by line
		-- define local patterns
		local d = P":"
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local def = d*SPACE*I
		def = Ct(def*(SPACE*par)^-1)*IGNORED
		-- resulting pattern, which does the work
		local patt = (def + IGNORED + 1)^0 * EOF

		Lang2lpeg.nnCron = lpeg.Ct(patt)
	end --do --^------- nnCron -------^--

	do --v------- CSS -------v--
		-- helper
		local function clear_spaces(s)
			return s:gsub('%s+',' ')
		end
 		-- redefine common patterns
		local IDENTIFIER = (ANY - SPACE)^1
		local NL = P"\r\n"
		local SPACE = S' \t'^1
		local IGNORED = (ANY - NL)^0 * NL -- just skip line by line
		local par = C(P"{"*(1-P"}")^0*P"}")/clear_spaces -- captures parameters in parentheses
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		-- definitions to capture:
		local def = Ct(I*SPACE*par)--*IGNORED
		-- resulting pattern, which does the work
		local patt = (def + IGNORED + 1)^0 * EOF

		Lang2lpeg.CSS = lpeg.Ct(patt)
	end --do --^------- CSS -------^--

	do --v----- * ------v--
		-- redefine common patterns
		local NL = P"\r\n"+P"\n"+P"\f"
		local SC = S" \t\160" -- без понятия что за символ с кодом 160, но он встречается в SciTEGlobal.properties непосредственно после [Warnings] 10 раз.
		local COMMENT = P'#'*(ANY - NL)^0*NL
		-- define local patterns
		local somedef = S'fFsS'*S'uU'*S'bBnN'*AZ^0 --пытаемся поймать что-нибудь, похожее на определение функции...
		local section = P'['*(ANY-P']')^1*P']'
		-- create flags
		local somedef = Cg(somedef, '')
		-- create additional captures
		local I = C(IDENTIFIER)*cl
		section = C(section)*cl
		local tillNL = C((ANY-NL)^0)
		-- definitions to capture:
		local def1 = Ct(somedef*SC^1*I*SC^0*(par+tillNL))
		local def2 = (NL+BOF)*Ct(section*SC^0*tillNL)*NL

		-- resulting pattern, which does the work
		local patt = (def2 + def1 + COMMENT + IDENTIFIER + 1)^0 * EOF
		-- local patt = (def2 + def1 + IDENTIFIER + 1)^0 * EOF -- чуть медленнее

		Lang2lpeg['*'] = lpeg.Ct(patt)
	end --^----- * ------^--

	do --v------- autohotkey -------v--
		-- redefine
		local NL = P'\n'+P'\r\n'
		-- local NL = S'\r\n'
		local ESCANY = P'`'*ANY + ANY

		-- helper
		local I = (ESCANY-S'(){},=:;\r\n')^1
		local LINE = (ESCANY-NL)^0
		local block_comment = '/*' * (ESCANY - P'*/')^0 * (P('*/') + EOF)
		local line_comment  = P';'*LINE*(NL + EOF)
		local COMMENT = line_comment + block_comment
		local BALANCED = P{ "{" * ((1 - S"{}") + V(1))^0 * "}" } -- capture balanced {}
		-- definitions to capture:
		local label     = C( I*P':'*#(1-S'=:'))*cl*LINE
		local keystroke = C( I*P'::' )*cl*LINE
		local hotstring = C( P'::'*I*P'::'*LINE )*cl
		local directive = C( P'#'*I )*cl*LINE
		local func      = C( I )*cl*par*(COMMENT+NL)^0*BALANCED
		local def = Ct( keystroke + label + hotstring + directive + func )
		-- resulting pattern, which does the work
		local patt = (SPACE^0*def + NL + COMMENT + LINE*NL)^0 * LINE*(EOF) --+ error'invalid character')

		Lang2lpeg.autohotkey = lpeg.Ct(patt)
	end --do --^------- autohotkey -------^--

	do --v----- SQL ------v--
		-- redefine common patterns
		--идентификатор может включать точку
		local IDENTIFIER = (P"["+AZ) * (AZ+N+P"."+P"$"+P"["+P"]")^0
		local STRING = (P'"' * (ANY - P'"')^0*P'"') + (P"'" * (ANY - P"'")^0*P"'")
		local COMMENT = ((P"--" * (ANY - NL)^0*NL) + block_comment)^1
		local SC = SPACE

		local cr = AnyCase"create"*SC^1
		local pr = AnyCase"proc"*AnyCase"edure"^0
		local vi = AnyCase"view"
		local tb = AnyCase"table"
		local tr = AnyCase"trigger"
		local fn = AnyCase"function"
		local IGNORED = SPACE + COMMENT + STRING
		-- create flags
		tr = Cg(cr*tr*SC^1*Cc(true),'Trigger')
		tb = Cg(cr*tb*SC^1*Cc(true),'Table')
		vi = Cg(cr*vi*SC^1*Cc(true),'View')
		pr = Cg(cr*pr*SC^1*Cc(true),'Proc')
		fn = Cg(cr*fn*SC^1*Cc(true),'Function')

		local I = C(IDENTIFIER)*cl
		--параметры процедур и вью(и функций) - всё от имени до as
		local parpv = C((1-AnyCase"as")^0)*AnyCase"as"
		--параметры таблиц содержат комментарии и параметры
		local partb = C((P"("*(COMMENT + (1-S"()")+par)^1*P")"))
		-- -- definitions to capture:
		pr = pr*I*SC^0*parpv
		vi = vi*I*SC^0*parpv
		fn = fn*I*SC^0*parpv
		tb = tb*I*SC^0--*partb
		tr = tr*I*SC^1*AnyCase"on"*SC^1*I --"параметр" триггера - идентификатор после I
		local def = Ct(( pr + vi + tb + tr+ fn))
		-- resulting pattern, which does the work
		local patt = (def + IGNORED^1 + IDENTIFIER + 1)^0 * EOF

		Lang2lpeg.SQL = lpeg.Ct(patt)
	end --^----- SQL ------^--

end

local Lang2CodeStart = {
	['Pascal']='^IMPLEMENTATION$',
}

local Lexer2Lang = {
	['asm']='Assembler',
	['cpp']='C++',
	['js']='JScript',
	['vb']='VisualBasic',
	['vbscript']='VisualBasic',
	['css']='CSS',
	['pascal']='Pascal',
	['python']='Python',
	['sql']='SQL',
	['lua']='Lua',
	['nncrontab']='nnCron',
}

local Ext2Lang = {}
do -- Fill_Ext2Lang
	local patterns = {
		[props['file.patterns.asm']]='Assembler',
		[props['file.patterns.cpp']]='C++',
		[props['file.patterns.wsh']]='JScript',
		[props['file.patterns.vb']]='VisualBasic',
		[props['file.patterns.wscript']]='VisualBasic',
		[props['file.patterns.formenjine']]='VisualBasic',
		['*.css']='CSS',
		['*.sql']='SQL',
		[props['file.patterns.pascal']]='Pascal',
		[props['file.patterns.py']]='Python',
		[props['file.patterns.lua']]='Lua',
		[props['file.patterns.nncron']]='nnCron',
		['*.ahk']='autohotkey',
		['*.m']='SQL',
	}
	for i,v in pairs(patterns) do
		for ext in (i..';'):gfind("%*%.([^;]+);") do
			Ext2Lang[ext] = v
		end
	end
end -- Fill_Ext2Lang

local function Functions_GetNames()

	table_functions = {}
	if editor.Length == 0 then return end

	local ext = props["FileExt"]:lower() -- a bit unsafe...
	local lang = Ext2Lang[ext]
    if lang == "VisualBasic" then
        fnTryGroupName = (function(s,f) if s == 'Sub' or s == 'Function'  or s == 'Property' then return f else return s end end)
    elseif lang == 'Lua' then
        fnTryGroupName = (function(s, f) if s == '' then return f end return s end)
    elseif lang == 'C++' then
        fnTryGroupName = (function(s, f) return f end)
    else
        fnTryGroupName = (function(s) return s end)
    end
	local start_code = Lang2CodeStart[lang]
	local lpegPattern = Lang2lpeg[lang]
	if not lpegPattern then
		lang = Lexer2Lang[props['Language']]
		start_code = Lang2CodeStart[lang]
		lpegPattern = Lang2lpeg[lang]
		if not lpegPattern then
			start_code = Lang2CodeStart['*']
			lpegPattern = Lang2lpeg['*']
		end
	end

	local textAll = editor:GetText()
	local start_code_pos = start_code and editor:findtext(start_code, SCFIND_REGEXP) or 0

    m__CLASS = '~~ROOT'
	-- lpegPattern = nil
	table_functions = lpegPattern:match(textAll, start_code_pos+1) -- 2nd arg is the symbol index to start with

end

local function GetFlags (funcitem)
	if not _show_flags then return '' end
	local res = ''
	local add = ''
    local res2 = ''
	for flag,value in pairs(funcitem) do
		if type(flag)=='string' then
			if type(value)=='boolean' then	if value then add = flag else res2 = res2..flag; add = '' end
			elseif type(value)=='string' then	add = flag .. value
			elseif type(value)=='number' then add = flag..':'..value
			else add = flag  end
			res = res .. add
		end
	end

	--if res~='' then res = res .. ' ' end
	return (res or ''), res2
end

local function GetParams (funcitem)
	if not _show_params then return '' end
	return (funcitem[3] and ' '..funcitem[3]) or ''
end

local function fixname (funcitem)
	local flag, flag2 = GetFlags(funcitem)
	return funcitem[1]..(flag2 or '')..GetParams(funcitem),flag
end

local function getPath(id)
    if iup.GetAttributeId(tree_func, 'KIND', id) == 'BRANCH' then return '' end
    local id2 = iup.GetAttributeId(tree_func, 'PARENT', id)
    if id2 == nil then return '' end
    return iup.GetAttributeId(tree_func, 'TITLE', id2)..':'..iup.GetAttributeId(tree_func, 'TITLE', id)
end

local function Functions_ListFILL()
	local function SortFuncList(a,b)
		if _group_by_flags then --Если установлено, сначала сортируем по флагу
			local fa = fnTryGroupName(GetFlags(a), a[4])
			local fb = fnTryGroupName(GetFlags(b), b[4])
			if fa ~=fb then return fa < fb end
		end
		if _sort == 'order' then
			return a[2] < b[2]
		else
			return a[1]:lower() < b[1]:lower()
		end
	end

    table.sort(table_functions, SortFuncList)

	-- remove duplicates
	for i = #table_functions, 2, -1 do
		if table_functions[i][2] == table_functions[i-1][2] then
			table.remove (table_functions, i)
		end
	end
    local tbFolders = {}

	local prevFoderFlag = "_NO_FLAG_"
	local cp = editor.CodePage

    lineMap = {}
    local j = 1
    local tbBranches = {}

    tree_func.delnode0 = "CHILDREN"
    tree_func.title0 = props['FileName']:from_utf8(1251)
    local rootCount = 0
    --debug_prnArgs(table_functions)
	for i, a in ipairs(table_functions) do
		local t,f = fixname(a)

        local node = {}
        node.leafname = t
        node.imageid = f

        if _group_by_flags then

            if tbFolders[fnTryGroupName(f, a[4])] == nil then
                j = j + 1
                tbBranches[table.maxn(tbBranches) + 1] = fnTryGroupName(f, a[4])
                if fnTryGroupName(f, a[4]) == '~~ROOT'  then
                    tbFolders[fnTryGroupName(f, a[4])] = -i +1
                else tbFolders[fnTryGroupName(f, a[4])] = table.maxn(tbBranches) end
			end
		else

            iup.SetAttribute(tree_func, 'ADDLEAF'..j - 1, t)
            iup.SetAttribute(tree_func, 'IMAGE'..j, 'IMAGE_'..f)
            lineMap[getPath(j)] = a[2]
		end
        j = j + 1
	end

    if _group_by_flags then
        for i = table.maxn(tbBranches), 1, -1 do
            if  tbBranches[i] ~= '~~ROOT' then
                iup.SetAttribute(tree_func, 'ADDBRANCH0', tbBranches[i])
            end
        end

        --[[local f2 = 0
        if tbFolders['~~ROOT'] ~= nil then f2 = tbFolders['~~ROOT'] + #table_functions  end]]
        for i, a in ipairs(table_functions) do
            local t,f = fixname(a)
            local node = {}
            node.leafname = t
            node.imageid = f

            local f1 = tbFolders[fnTryGroupName(f, a[4])]

            iup.SetAttribute(tree_func, 'ADDLEAF'..i +  f1 - 1, t)
            iup.SetAttribute(tree_func, 'IMAGE'..i +  f1, 'IMAGE_'..f)

--[[            if fnTryGroupName(f, a[4]) == '~~ROOT' then
                k = i + f1
            else
                k = i + f1 + f2
            end]]

            lineMap[getPath(i +  f1)] = a[2]
        end
    end
    -- Восстановим  лэйаут
    for  i=1, tree_func.count do
        if iup.GetAttribute(tree_func, 'KIND'..i) == 'BRANCH' then
            if layout[iup.GetAttribute(tree_func, 'TITLE'..i)] == 'COLLAPSED' then
                iup.SetAttribute(tree_func, 'STATE'..i, 'COLLAPSED')
            end
        end
    end

	--сортируем по ордеру, чтобы удобнее искать имя по строке
	table.sort(table_functions,function(a,b) return a[2] < b[2] end)
	currFuncData = -1
end

local function Functions_SortByOrder()
	_sort = 'order'
    _G.iuprops['sidebar.functions.sort'] = _sort
	Functions_ListFILL()
end

local function Functions_SortByName()
	_sort = 'name'
    _G.iuprops['sidebar.functions.sort'] = _sort
	Functions_ListFILL()
end

local function Functions_ToggleParams ()
	_show_params = not _show_params
    _G.iuprops['sidebar.functions.params'] = Iif(_show_params,1,0)
	Functions_ListFILL()
end

local function Functions_ToggleFlags ()
	_show_flags = not _show_flags
	if not _show_flags then
		_group_by_flags = false
        _G.iuprops['sidebar.functions.flags'] = 0
        _G.iuprops['sidebar.functions.group'] = 1
    else
        _G.iuprops['sidebar.functions.flags'] = 1
	end
	Functions_ListFILL()
end

local function ShowCompactedLine(line_num)
	local function GetFoldLine(ln)
		while editor.FoldExpanded[ln] do ln = ln-1 end
		return ln
	end
	while not editor.LineVisible[line_num] do
		local x = GetFoldLine(line_num)
		editor:ToggleFold(x)
		line_num = x - 1
	end
end

local function Functions_GotoLine()
	local pos = lineMap[getPath(tree_func.value)]
	if pos ~= nil then
		OnNavigation("Func")
		ShowCompactedLine(pos)
		editor:GotoLine(pos)
		OnNavigation("Func-")
	end
    return pos
end

-- По имени функции находим строку с ее объявлением (инфа берется из table_functions)
local function Func2Line(funcname)
	if not next(table_functions) then
		Functions_GetNames()
	end
	for i = 1, #table_functions do
		if funcname == table_functions[i][1] then
			return table_functions[i][2]
		end
	end
end

-- Переход на строку с объявлением функции
local function JumpToFuncDefinition(funcname)
	local line = Func2Line(funcname)
	if line then
		editor:GotoLine(line)
		return true -- обрываем дальнейшую обработку OnDoubleClick (выделение слова и пр.)
	end
end

local function OnSwitch()
    Functions_GetNames()
    Functions_ListFILL()
    line_count = editor.LineCount
    curSelect = -1
end

local curSelect
curSelect = -1

local function  _OnUpdateUI()
    if SideBar_Plugins.functions.Bar_obj.TabCtrl.value_handle.tabtitle == SideBar_Plugins.functions.id then
        if editor.Focus then
            local line_count_new = editor.LineCount
            local def_line_count = line_count_new - line_count
            if def_line_count ~= 0 then --С прошлого раза увеличилось количество строк в файле
                    local cur_line = editor:LineFromPosition(editor.CurrentPos)
                    for i = 1, tree_func.count - 1 do
                        --if lineMap[i] ~=nil and lineMap[i] > cur_line then
                        local iDx = getPath(i)
                        if lineMap[iDx] ~= nil and lineMap[iDx] ~= '' and lineMap[iDx] >= cur_line then
                            -- в мэпе для всех функций ниже текущей строки изменим значение на сдвиг
                            lineMap[iDx] = lineMap[iDx] + def_line_count
                        end
                    end
                line_count = line_count_new
            end
        end

        local l = editor:LineFromPosition(editor.SelectionStart)
        if currentLine ~= l then
            currentLine = l
            local i,tb,fData ,t,f
            fData = -1
            for i,f in pairs(lineMap) do
                -- найдем ближайшую сверху функцию к текущей строке (строку, содержащую функцию)
                if f <= currentLine and f > fData then fData = f end
            end
            if fData ~= currFuncData then
                -- выяснилось, что с прошлого раза мы переместились в другую функцию
                if currFuncData > -1 then
                    iup.SetAttribute(tree_func, "MARK"..currFuncData, "NO")
                end
                for  i=0, tree_func.count do
                    local iDx = getPath(i)
                    if lineMap[iDx] == fData then
                        -- выделяем "функцию", в теле которой находится пользователь, но только если она не в свернутой папке - иначе выделяем саму папку
                        local pId = tonumber(iup.GetAttribute(tree_func, "PARENT"..i))
                        if iup.GetAttribute(tree_func, "STATE"..pId) == 'EXPANDED' then pId = i end
                        currFuncData = fData
                        iup.SetAttribute(tree_func, "MARKED"..pId, "YES")
                        iup.SetAttribute(tree_func, "COLOR"..pId, "30 180 30")
                        if curSelect > -1 then iup.SetAttribute(tree_func, "COLOR"..curSelect, "0 0 0");--[[iup.SetAttribute(tree_func, "COLOR"..curSelect, "0 0 0") ]]end
                        curSelect = pId
                        tree_func.topitem="YES"
                        return
                    end
                end
                -- мы находимся над первой функцией - пометим корневую папку
                iup.SetAttribute(tree_func, "MARKED0", "YES")
                iup.SetAttribute(tree_func, "COLOR0", "30 180 30")
                iup.SetAttribute(tree_func, "COLOR"..curSelect, "0 0 0")
                curSelect = 0
                currFuncData=-1
            end
            return
        end
    end
end

local function OnMySave()
    OnSwitch()
    currentLine = -1
    curSelect = -1
    _OnUpdateUI()
    iup.PassFocus()
end

local function Functions_ToggleGroup()
	_group_by_flags = not _group_by_flags
	if _group_by_flags then
		_show_flags = true
        _G.iuprops['sidebar.functions.group'] = 1
        _G.iuprops['sidebar.functions.flags'] = 1
    else
        _G.iuprops['sidebar.functions.group'] = 1
	end

    Functions_GetNames()
    Functions_ListFILL()
end

function menu_GoToObjectDefenition()    --TODO!!! - перенести в этот файл создание пункта менб!
	local handled = false
	local strFunc = GetCurrentWord()
	local current_pos = editor.CurrentPos
	editor:SetSel(editor:WordStartPosition(current_pos, true),
							editor:WordEndPosition(current_pos, true))
	if GoToObjectDefenition then
		handled = GoToObjectDefenition(strFunc)
	end
	if not handled then
		OnNavigation("Def")
		handled = JumpToFuncDefinition(strFunc)
		OnNavigation("Def-")
	end
	return handled
end

local function _OnDoubleClick(shift, ctrl, alt)
	if shift then
		return menu_GoToObjectDefenition()
	end
end

local function SaveLayoutToProp()
    local i,s, prp
    prp = ""
    for i,s in pairs(layout) do
        if s == 'COLLAPSED' then prp = prp..'|'..i  end
    end
    _G.iuprops['sidebar.functions.layout'] = prp
end

local function Functions_Print()
    for i,v in ipairs(table_functions) do
        if type(v) == 'table' and ( v.Property or v.Function or v.Sub) then
            print(v[4]..' '..v[1]..v[3])
        end
    end
end

local function Finc_Init()
    local prp = _G.iuprops['sidebar.functions.layout'] or ""
    local w
    for w in string.gmatch(prp, "[^|]+") do
       layout[w] = 'COLLAPSED'
    end
    local line = nil                                                                                              --RGB(73, 163, 83)  RGB(30,180,30)
    tree_func = iup.tree{minsize = '0x5'}
        --Обработку нажатий клавиш производим тут, чтобы вернуть фокус редактору
        tree_func.size = nil

        tree_func.button_cb = (function(_,but, pressed, x, y, status)

        if but == 51 and pressed == 0 then --right

            local mnu = iup.menu
            {
              iup.submenu
              {
                iup.menu
                {
                  iup.item{title="Order",value=Iif(_sort == "order", "ON", "OFF"),action=Functions_SortByOrder},
                  iup.item{title="Name",value=Iif(_sort == "name", "ON", "OFF"),action=Functions_SortByName}
                }
                ;title="Sort By"
              },
              iup.item{title="Show Parameters",value=Iif(_show_params, "ON", "OFF"),action=Functions_ToggleParams},
              iup.item{title="Group By Flags",value=Iif(_group_by_flags, "ON", "OFF"),action=Functions_ToggleGroup},
              iup.item{title="Print",action=Functions_Print},
            }:popup(iup.MOUSEPOS,iup.MOUSEPOS)
        elseif but == 49 and iup.isdouble(status) then --dbl left
            line = Functions_GotoLine()
        end
        if pressed == 0 and line ~= nil then
            iup.PassFocus()
            line = nil
        end
    end)
    tree_func.k_any = (function(_,number)
        if number == 13 then
            Functions_GotoLine()
            iup.PassFocus()
        elseif number == 65307 then
            iup.PassFocus()
        end
    end)
    tree_func.branchopen_cb = function(_,number)
        layout[iup.GetAttribute(tree_func, 'TITLE'..number)] = 'EXPANDED'
        SaveLayoutToProp()
    end
    tree_func.branchclose_cb = function(_,number)
        layout[iup.GetAttribute(tree_func, 'TITLE'..number)] = 'COLLAPSED'
        SaveLayoutToProp()
    end
    tree_func.branchclose_cb = function(h) if h.value=='0' then return -1 end end
    iup.SetAttributeId(tree_func, 'IMAGEEXPANDED', 0, 'tree_µ')

    SideBar_Plugins.functions = {   -- iup.vbox{   };
        handle = tree_func;
        OnSwitchFile = OnSwitch;
        OnSave = OnMySave;
        OnOpen = OnSwitch;
        OnUpdateUI = _OnUpdateUI;
        OnDoubleClick = _OnDoubleClick;
		OnNavigation = OnNavigate;
        --tabs_OnSelect = OnSwitch;
        on_SelectMe = function() OnSwitch(); iup.SetFocus(tree_func); iup.Flush();end
        }

end

return {
    title = 'Functions',
    code = 'functions',
    sidebar = Finc_Init,
}




