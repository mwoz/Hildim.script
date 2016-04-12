require "seacher"
local findSettings = seacher{
wholeWord = false
,matchCase = false
,wrapFind = true
,backslash = false
,regExp = false
,style = nil
,searchUp = false
,replaceWhat = ''
}
-----------------------------------


function SelectMethod()
	local current_mark_number = tonumber(props['findsel.mark'])
	EditorClearMarks(current_mark_number)
	local sText = editor:GetSelText()

	local flag1 = 0
	if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end

	iFind = 0
	--if current_mark_number < firstNum then current_mark_number = firstNum end
	if string.len(sText) > 0 and editor.SelectionStart == editor:WordStartPosition(editor.SelectionEnd) and editor.SelectionEnd == editor:WordEndPosition(editor.SelectionStart) then
        for m in editor:match(sText, SCFIND_WHOLEWORD + flag1) do
			EditorMarkText(m.pos, m.len, current_mark_number)
			iFind = iFind + 1
		end
    else
        sText = ''
	end
    iMark = props["findtextsimple.count"]
    if StatusBar_obj then StatusBar_obj.Tabs.statusbar.SetFindRes(sText, iFind) end
    if iFind > 0 then strStatus='Sel+{'..tostring(iFind-1)..'}' else strStatus='NoSel'  end
    if iMark ~= '0' then strStatus = strStatus..' | Mark{'..iMark..'}' end
	props['findtext.status'] = strStatus
end

AddEventHandler("OnUpdateUI", SelectMethod)


function GoToIncludeDef(strSelText)
    local function recrGoToIncDef(tblFiles, strText, strSelText)
        local _incStart,_incEnd,incFind,incPath,_start, _end, fName
        while true do
            _start, _end, fName = string.find(strText,'#INCLUDE.([%w%.%_]+)',_start)
            if _start == nil then break end
            if tblFiles[string.lower(fName)] == nil then
                tblFiles[string.lower(fName)] = 1
                local fName2 = get_precomp_tblFiles(string.lower(fName))
                if fName2 ~= nil then
                    incPath = props["precomp_strRootDir"]..'\\'..fName2
                    if shell.fileexists(incPath) then
                        local incF = io.input(incPath)
                        local incText = incF:read('*a')
                        incF:close()
                        _incStart = nil
                        _incStart = recrGoToIncDef(tblFiles, incText, strSelText)
                        if _incStart ~= nil then return _incStart end
                        _incStart,_incEnd,incFind = string.find(incText,'(\n[ ]*Sub[%s]+'..strSelText..')[^%w_]')
                        if _incStart ~=nil then break end
                        _incStart,_incEnd,incFind = string.find(incText,'(\n[ ]*Function[%s]+'..strSelText..')[^%w_]')
                        if _incStart ~=nil then break end
                        _incStart,_incEnd,incFind = string.find(incText,'(<\n[ ]*[^%>]-name%=%"'..strSelText..'%"[^%>]*)')
                        if _incStart ~=nil then break end
                    else
                        print('File '..incPath..' not found!')
                    end
                else
                    print('Library '..fName..' not found!')
                end
            end
           _start = _end + 1
        end

        if _incStart ~=nil then
            OnNavigation("Def")
			scite.Open(incPath)
			_incStart,_incEnd = editor:findtext(incFind)
			editor:SetSel(_incStart+1,_incEnd)
            OnNavigation("Def-")
		end
        return _incStart
    end

    local strText
    if not strSelText or strSelText == '' then strSelText = editor:GetSelText() end
    if strSelText == '' then return end
    strText = editor:GetText()
    local _incStart,_incEnd,incFind,incPath,_start, _end, fName
    local tblFiles = {}

    return recrGoToIncDef(tblFiles, strText, strSelText)

end

function GoToDef(strSelText)
    local incText, strNav
    if not strSelText then strSelText = editor:GetSelText() end
    if strSelText == '' then return end
    incText = editor:GetText()
    local prevLine = editor:GetCurLine()
    local _selSt= editor.SelectionStart
    local _selEnd = editor.SelectionEnd

    strNav = "Def"
    _incStart,_incEnd,incFind = string.find(incText,'\n[ ]*(Sub[ \t]+'..strSelText..')[^%w_]')
    if _incStart ==nil then _incStart,_incEnd,incFind = string.find(incText,'\n[ ]*(Function[ \t]+'..strSelText..')[^%w_]') end
    if _incStart ==nil then
        _incStart,_incEnd,incFind = string.find(incText,'\n[ ]*<([^%>]-name%=%"'..strSelText..'%"[^%>]*)')
        strNav = "Xml"
    end
    if _incStart ==nil then
        _incStart,_incEnd,incFind = string.find(incText,'\n[ ]*<(string id="'..strSelText..'%"[^%>]*)')
        strNav = "String"
    end
    if _incStart ~=nil then
        OnNavigation(strNav)
        iup.SetGlobal('KEYRELEASE','K_RSHIFT')
        iup.SetGlobal('KEYRELEASE','K_LSHIFT')
        editor:SetSel(_incStart,_incEnd)
        if prevLine ~= editor:GetCurLine() then
            OnNavigation(strNav.."-")
            return
        else
            editor:SetSel(_selSt,_selEnd)
        end
    end
    if GoToIncludeDef() then return end
    sql_GoToDefinition(strSelText)
end

AddEventHandler("GoToObjectDefenition", function(txt)
    if cmpobj_GetFMDefault() ~= -1 then
        GoToDef(txt)
        return true
    end
    return false
end)

function GoToXml()
    local strSelText,incText
    strSelText = editor:GetSelText()
    if strSelText == '' then return end
    incText = editor:GetText()

    _incStart,_incEnd,incFind = string.find(incText,'<([^%>]-name%=%"'..strSelText..'%"[^%>]*)')
    if _incStart ~=nil then
        OnNavigation("Xml")
        editor:SetSel(editor:findtext(incFind))
        OnNavigation("Xml-")
        return
    end
end

function FindMarkCurrentSelection()
    local firstNum = ifnil(tonumber(props['findtext.first.mark']),31)
    if firstNum < 1 or firstNum > 31 then firstNum = 31 end
    local sText = editor:GetSelText()
    local flag0 = 0
    if (sText == '') then sText = GetCurrentWord() end
    local flag1 = 0
    if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end
    local bookmark = props['findtext.bookmarks'] == '1'
    local isOutput = props['findtext.output'] == '1'
    local isTutorial = props['findtext.tutorial'] == '1'
    if props['findtext.wholeword'] == '1' then flag0 = SCFIND_WHOLEWORD end

    local current_mark_number = firstNum
    if string.len(sText) > 0 then
        EditorClearMarks(firstNum)
        if bookmark then editor:MarkerDeleteAll(1) end
        local s,e = editor:findtext(sText, flag0 + flag1, 1)
        local count = 0
        if(s~=nil)then
            local m = editor:LineFromPosition(s) - 1
            while s do
                local l = editor:LineFromPosition(s)
                EditorMarkText(s, e-s, current_mark_number)
                count = count + 1
                if l ~= m then
                    if bookmark then editor:MarkerAdd(l,1) end
                    local str = string.gsub(' '..editor:GetLine(l),'%s+',' ')
                    m = l
                end
                s,e = editor:findtext(sText, flag0 + flag1, e+1)
            end
        end
        props["findtextsimple.count"] = tostring(count)
        current_mark_number = current_mark_number + 1
        if current_mark_number > 31 then current_mark_number = firstNum end
        scite.SendEditor(SCI_SETINDICATORCURRENT, current_mark_number)
            -- обеспечиваем возможность перехода по вхождениям с помощью F3 (Shift+F3)
            if flag0 == SCFIND_WHOLEWORD then
                editor:GotoPos(editor:WordStartPosition(editor.CurrentPos))
            else
                editor:GotoPos(editor.SelectionStart)
            end
            scite.Perform('find:'..sText)
            props["findtextsimple.text"] = sText
    else
        props["findtextsimple.count"] = '0'
        props["findtextsimple.text"] = ''
        EditorClearMarks(firstNum)
        if bookmark then editor:MarkerDeleteAll(1) end
        scite.SendEditor(SCI_SETINDICATORCURRENT, firstNum)
    end
end

function FindSelToConcole()
    needCoding = (scite.SendEditor(SCI_GETCODEPAGE) ~= 0)
    local sText = editor:GetSelText()
    findSettings.wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        findSettings.wholeWord= true
    end

    findSettings.findWhat = sText

    findSettings:FindAll(100, false)
end

function Toggle_ToggleSubfolders(bShow)
    local lStart = editor:LineFromPosition(editor.SelectionStart)
    local baseLevel = shell.bit_and(editor.FoldLevel[lStart],SC_FOLDLEVELNUMBERMASK)
    if baseLevel > SC_FOLDLEVELBASE and shell.bit_and(baseLevel,SC_FOLDLEVELHEADERFLAG) == 0 then
        while (baseLevel <= shell.bit_and(editor.FoldLevel[lStart],SC_FOLDLEVELNUMBERMASK)) and (lStart >=0) do lStart = lStart - 1 end
    end
    local lEnd = editor:GetLastChild(lStart, -1)
    local baseLevel = shell.bit_and(editor.FoldLevel[lStart],SC_FOLDLEVELNUMBERMASK)
    for l = lStart + 1, lEnd do
        local level = editor.FoldLevel[l]
        if (shell.bit_and(level,SC_FOLDLEVELHEADERFLAG)~=0 and baseLevel + 1 == shell.bit_and(level,SC_FOLDLEVELNUMBERMASK))then
            editor.FoldExpanded[l] = bShow
            local lineMaxSubord = editor:GetLastChild(l,-1)
            if l < lineMaxSubord then
                if bShow then
                    editor:ShowLines(l + 1, lineMaxSubord)
                else
                    editor:HideLines(l + 1, lineMaxSubord)
                end
                l = lineMaxSubord
            end
        end
    end
end

function Find_FindInDialog(ud)
    local sText = editor:GetSelText()
    local wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        wholeWord= true
    end
    iup.GetDialogChild(iup.GetLayout(),"cmbFindWhat").value = sText
    iup.GetDialogChild(iup.GetLayout(),"cmbFindWhat"):SaveHist()
    iup.GetDialogChild(iup.GetLayout(),"btnFind").action()
end

function FindNextWrd(ud)
    local sText = editor:GetSelText()
    local wholeWord = false
    if (sText == '') then
        sText = GetCurrentWord()
        wholeWord= true
    end
    local fs = seacher{
    wholeWord = wholeWord
    ,matchCase = false
    ,wrapFind = true
    ,backslash = false
    ,regExp = false
    ,style = nil
    ,searchUp = (ud==2)
    ,replaceWhat = ''
    ,findWhat = sText
    }
    local pos = fs:FindNext(true)
    if wholeWord then
        editor.SelectionStart = pos +1
        editor.SelectionEnd = pos +1
    end
end

function FindMarkNext()
    local flag1 = 0
    if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end
    curpos = editor.CurrentPos
    editor:GotoPos(1+curpos)
    editor:SearchAnchor()
    local s = editor:SearchNext( SCFIND_WHOLEWORD + flag1, props["findtextsimple.text"])
    if (-1 == s) then
        editor:GotoPos(0)
        editor:SearchAnchor()
        s = editor:SearchNext( SCFIND_WHOLEWORD + flag1, props["findtextsimple.text"])
        if -1 == s then
            editor:GotoPos(curpos)
        end
    end
    if (s > -1) then
        se = editor.SelectionEnd
        editor:GotoPos(editor.SelectionStart)
        editor:SetSel(editor.SelectionStart,se)
    end
end
function FindMarkPrev()
    local flag1 = 0
    if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end
    curpos = editor.CurrentPos
    --editor:GotoPos(1+curpos)
    editor:SearchAnchor()
    local s = editor:SearchPrev( SCFIND_WHOLEWORD + flag1, props["findtextsimple.text"])
    if (-1 == s) then
        editor:GotoPos(scite.SendEditor(SCI_GETTEXTLENGTH))
        editor:SearchAnchor()
        s = editor:SearchPrev( SCFIND_WHOLEWORD + flag1, props["findtextsimple.text"])
        if -1 == s then
            editor:GotoPos(curpos)
        end
    end
    if (s > -1) then
        se = editor.SelectionEnd
        editor:GotoPos(editor.SelectionStart)
        editor:SetSel(editor.SelectionStart,se)
    end
end
function GoToHandler()
    sb=fGoToHandler()
    if( sb~="")then  print(sb.." Not Found!!!");return end
end
function fGoToHandler()
    local str = editor:GetCurLine()
    local _s1,_s2,typ =  string.find(str,'type="([%w_]*)"')
    local _s1,_s2,name =  string.find(str,'name="([%w_]*)"')
    if(typ==nil or name==nil) then
        print("Control or Name fields not found!")
        return ""
    end
    local prefix = nil
    _s1 = string.find(":textbox:numberbox:datebox:timebox:",  ":"..typ..":")
    if _s1 ~= nil then
        prefix = "_Change"
    else
        _s1 = string.find(":button:checkbox:combobox:combobox2:link:",  ":"..typ..":")
        if _s1 ~= nil then prefix = "_Click" end
    end
    if prefix == nil then
        print(typ.." not supported!")
        return ""
    end
    local sb = "Sub "..name..prefix.."()"
    editor:SearchAnchor()
    _s1 = editor:SearchNext(0, sb)
    if (_s1 > -1) then
        editor:GotoPos(editor.SelectionStart)
        return ""
    else
        return sb
    end
end

function CreateHandler()
    local str = fGoToHandler()
    if str=="" then return end
    local s,e = editor:findtext("'''CONTROLS HANDLING", 0, 0)
    if(s==nil) then
        s,e = editor:findtext("-->", 0, 0)
        if(s==nil) then
            print("'CONTROLS HANDLING not found!")
            return
        end
        editor:GotoPos(s)
		editor:LineUp()
		editor:Home()
		editor:ReplaceSel("'''''''''''CONTROLS HANDLING'''''''''''")
        editor:LineUp()
        editor:LineUp()
        s,e = editor:findtext("'''CONTROLS HANDLING", 0, 0)
    end
    editor:GotoPos(s)
    editor:LineDown()
    editor:Home()
    editor:ReplaceSel(str.."\n    \nEnd Sub\n\n")
    editor:GotoPos(editor.CurrentPos-string.len("\nEnd Sub\n\n"))
end

function OpenFindFiles()
	local output_text = output:GetText()
	local str, path = output_text:match('"(.-)" in "(.-)"')
	path = path:match('^.+\\')
	local filename_prev = ''
	for filename in output_text:gmatch('([^\r\n:]+):%d+:[^\r\n]+') do
		filename = filename:gsub('^%.\\', path)
		if filename ~= filename_prev then
			scite.Open(filename)
			local pos = editor:findtext(str)
			if pos ~= nil then editor:GotoPos(pos) end
			filename_prev = filename
		end
	end
end
local sText
function template_MoveControls()
    local dlg2 = _G.dialogs["ctrlmoover"]
    if dlg2 == nil then

        local txtX2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtY2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtH2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtW2 = iup.text{size='60x0',mask="[+/-]?/d+"}
        local txtX1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtY1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtH1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtW1 = iup.text{size='60x0',mask="[><]?/d+[><]?/d*"}
        local txtCp = iup.text{size='60x0',mask="[+/-]?/d+"}

        local flag2 = 0



        local btn_ok = iup.button  {title="OK"}
        iup.SetHandle("MOVE_BTN_OK",btn_ok)
        local btn_esc = iup.button  {title="Cancel"}
        iup.SetHandle("MOVE_BTN_ESC",btn_esc)
        local btn_clear = iup.button  {title="Clear"}
        iup.SetHandle("MOVE_BTN_CLEAR",btn_clear)

        local vbox = iup.vbox{
            iup.hbox{iup.label{title="Left",size='60x0'},iup.label{title="Top",size='60x0'},iup.label{title="Width",size='60x0'},iup.label{title="Height",size='60x0'},iup.label{title="CptWidth",size='60x0'},gap=20, alignment='ACENTER'},
            iup.hbox{txtX1,txtY1,txtW1,txtH1,gap=20, alignment='ACENTER'},
            iup.hbox{txtX2,txtY2,txtW2,txtH2,txtCp,gap=20, alignment='ACENTER'},
            iup.hbox{btn_ok,iup.fill{},btn_clear,btn_esc},gap=2,margin="4x4" }


        dlg2 = iup.scitedialog{vbox; title="Контрол Мувер",defaultenter="MOVE_BTN_OK",defaultesc="MOVE_BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO",
        sciteparent="SCITE", sciteid="ctrlmoover"}

        function btn_clear:action()
                txtX2.value = ''
                txtY2.value = ''
                txtH2.value = ''
                txtW2.value = ''
                txtX1.value = ''
                txtY1.value = ''
                txtH1.value = ''
                txtW1.value = ''
                txtCp.value = ''
        end

        function btn_ok:action()
            local function InpValue(t)
                str = t.value
                if str.."" == "" then str = "%d*" end
                if str:find("[<>]") ~= nil then str = "%d+" end
                return "("..str..")"
            end
            local strtempl = 'position="'..InpValue(txtX1)..';'..InpValue(txtY1)..';'..InpValue(txtW1)..';'..InpValue(txtH1)..'"([^\n]*)'
            local iLevel = 0
            local strout = editor:GetSelText():gsub("[^\n]+",function(s)
                local strrow = s
                if s:find('<control') then
                    if iLevel == 0 then
                        strrow = s:gsub(strtempl,function(s1,s2,s3,s4,tt)
                            local function f(s,c)
                                if s=="" then return "" end
                                if c.value:len() == 0 then return s end
                                local sval = c.value:sub(2)
                                if sval == nil then sval = 1 end
                                local sign = c.value:sub(0,1)
                                if sign == "-" then return s*1 - sval*1 end
                                if sign == "+" then return s+sval end
                                return c.value
                            end
                            local function ch(s,c)
                                if s=="" then return true end
                                local z1,n1,z2,n2
                                z1,n1,z2,n2=c.value:match("([><]?)(%d+)([><]?)(%d*)")
                                if z1 ~= nil  then
                                    if n1 == nil then n1 = 0 end
                                    if z1 == "<" and s*1 > n1*1 then return false end
                                    if z1 == ">" and s*1 < n1*1 then return false end
                                    if z2.."" ~= "" then
                                        if n2 == nil then n2 = 0 end
                                        if z2 == "<" and s*1 > n2*1 then return false end
                                        if z2 == ">" and s*1 < n2*1 then return false end
                                    end
                                end
                                return true
                            end
                            if ch(s1,txtX1) and ch(s2,txtY1) and ch(s3,txtW1) and ch(s4,txtH1) then
                                local tt2 = tt:gsub('captionwidth="(%d+)"', function(cw)
                                    return 'captionwidth="'..f(cw,txtCp)..'"'
                                    end
                                )
                                return 'position="'..f(s1,txtX2)..';'..f(s2,txtY2)..';'..f(s3,txtW2)..';'..f(s4,txtH2)..'"'..tt2
                            else
                                return 'position="'..s1..';'..s2..';'..s3..';'..s4..'"'..tt
                            end
                        end)
                    end
                if not s:find('/>') then iLevel = iLevel + 1 end
                elseif s:find('</control') then
                    iLevel = iLevel - 1
                end
                return strrow
            end)

            editor:ReplaceSel(strout)
            dlg2:hide()
        end

        function btn_esc:action()
            dlg2:hide()
        end
    else
        dlg2:show()
    end
end


AddEventHandler("OnClick", function(shift, ctrl, alt)
    if editor.Focus and not shift and ctrl and alt then
        FindSelToConcole()
    end
end)
AddEventHandler("OnContextMenu", function(lp, wp, source)       --сшибка err
    if source ~= "FINDREZ" then return end
    local mnu = ''
    if findrez.StyleAt[findrez.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
        mnu = mnu..'Открыть файлы|60000|Закрыть файлы|60003|Закрыть не найденные|60004|||'
    end
    mnu = mnu..'[MAIN]||'..Iif(_G.iuprops['findrez.clickonlynumber'], '^', '')..'DblClick только по номеру|60001|'..
                           Iif(_G.iuprops['findrez.groupbyfile'], '^', '')..'Группировать по имени файла|60002|'
    return mnu:to_utf8(1251)
end)

AddEventHandler("OnMenuCommand", function(msg, source)
    local function fndFiles()
        local t = {}
        if findrez.StyleAt[findrez.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
            local lineNum = findrez:LineFromPosition(findrez.CurrentPos) + 1
            while true do
                local style = findrez.StyleAt[findrez:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    local s = findrez:textrange(findrez:PositionFromLine(lineNum) + 1, findrez:PositionFromLine(lineNum + 1) -1)
                    table.insert(t,s)
                end
                lineNum = lineNum + 1
            end
        end
        return t
    end

    local function CloseIfFound(_,t, bFounded)
        if not t then return end
        for i = 1, #t do
            if t[i]:upper() == string.upper(props['FileDir']..'\\'..props["FileNameExt"]) then
                if bFounded then scite.MenuCommand(IDM_CLOSE) end
                return
            end
        end
        if not bFounded then scite.MenuCommand(IDM_CLOSE) end
    end

    if msg == 60000 then
        if findrez.StyleAt[findrez.CurrentPos] == SCE_SEARCHRESULT_SEARCH_HEADER then
            local lineNum = findrez:LineFromPosition(findrez.CurrentPos) + 1
            while true do
                local style = findrez.StyleAt[findrez:PositionFromLine(lineNum) + 1]
                if style == SCE_SEARCHRESULT_SEARCH_HEADER then break
                elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                    local s = findrez:textrange(findrez:PositionFromLine(lineNum) + 1, findrez:PositionFromLine(lineNum + 1) -1)
                    scite.Open(s)
                end
                lineNum = lineNum + 1
            end
        end
        return true
    elseif msg == 60001 then
        _G.iuprops['findrez.clickonlynumber'] = not _G.iuprops['findrez.clickonlynumber']
        return true
    elseif msg == 60002 then
        _G.iuprops['findrez.groupbyfile'] = not _G.iuprops['findrez.groupbyfile']
        return true
    elseif msg == 60003 then
        DoForBuffers(CloseIfFound, fndFiles(), true)
        return true
    elseif msg == 60004 then
        DoForBuffers(CloseIfFound, fndFiles(), false)
        return true
    end
end)

AddEventHandler("OnDoubleClick", function(shift, ctrl, alt)
    if not findrez.Focus then return end
    local style = findrez.StyleAt[findrez.CurrentPos]
    local lineNum = findrez:LineFromPosition(findrez.CurrentPos)
    local function perfGo(s, p, strI)
        OnNavigation("Go")
        s = s:to_utf8(1251)
        if s ~= props['FilePath'] then scite.Open(s) end
        if strI and strI:len() > 0 then
            editor.TargetStart = editor:PositionFromLine(p)
            editor.TargetEnd = editor:PositionFromLine(p + 1)
            local posFind = editor:SearchInTarget(strI)
            if posFind and posFind >= p then
                editor:SetSel(posFind, posFind + strI:len())
                iup.PassFocus()
                OnNavigation("Go-")
                return
            end
        end
        p = editor:PositionFromLine(p)
        editor:SetSel(p, p)
        iup.PassFocus()
        OnNavigation("Go-")
    end

    local function GetFindTxt(lS, lE)
        local sInd = scite.SendFindRez(SCI_INDICATOREND, 31, lS)
        if lE >= sInd and sInd >= lS then
            local eInd = scite.SendFindRez(SCI_INDICATOREND, 31, sInd)
            return findrez:textrange(sInd, eInd)
        end
    end

    if style == SCE_SEARCHRESULT_FILE_HEADER then
        local s = findrez:textrange(findrez:PositionFromLine(lineNum) + 1, findrez:PositionFromLine(lineNum + 1) -1):to_utf8(1251)
        if s ~= props['FilePath'] then
            OnNavigation("Go")
            scite.Open(s)
            OnNavigation("Go-")
        end
    elseif style == SCE_SEARCHRESULT_LINE_NUMBER or
           (not _G.iuprops['findrez.clickonlynumber'] and style == SCE_SEARCHRESULT_CURRENT_LINE) then
        local lS, lE = findrez:PositionFromLine(lineNum), findrez:PositionFromLine(lineNum + 1) -1
        local s = findrez:textrange(lS, lE)
        local exPath, lHeadPath
        local _,_,p = s:find('^%s+(%d*)')
        if not p then _,_,exPath,p = s:find('^%.\\([^:]*):(%d+)') end
        if not p then _,_,lHeadPath,exPath,p = s:find('^([A-Z]:([^:]*)):(%d*)') end
        if not p then return end
        p = tonumber(p) - 1
        for i = lineNum, 0, -1 do
            style = findrez.StyleAt[findrez:PositionFromLine(i) + 2]
            if style == SCE_SEARCHRESULT_SEARCH_HEADER then
                if not exPath then break end
                if not lHeadPath then
                    lHeadPath = findrez:textrange(findrez:PositionFromLine(i), findrez:PositionFromLine(i +1) -2)
                    _,_,lHeadPath = lHeadPath:find(' in "([^"]+)')
                    if exPath ~= '' then _,_,lHeadPath = lHeadPath:find('(.-)[^\\]+$') end
                    lHeadPath = lHeadPath..exPath
                end
                perfGo(lHeadPath, p, GetFindTxt(lS, lE))
                break
            elseif style == SCE_SEARCHRESULT_FILE_HEADER then
                local s = findrez:textrange(findrez:PositionFromLine(i) + 1, findrez:PositionFromLine(i + 1) -1)
                perfGo(s, p, GetFindTxt(lS, lE))
                break
            end
        end
    end
end)
require "menuhandler"

-- menuhandler:InsertItem('MainWindowMenu', 'Search¦##', {'Find Next Word/Selection', ru='Следующее слово/выделение', action=Find_FindInDialog, key='Ctrl+F3',})
-- menuhandler:InsertItem('MainWindowMenu', 'Search¦##', {'Prevous Word/Selection', ru='Предыдущее слово/выделение', action=function() FindNextWrd(2) end, key='Ctrl+Shift+F3',})

menuhandler:InsertItem('MainWindowMenu', 'Search¦s1',   --TODO переместить в SideBar\FindRepl.lua вместе с функциями
{'FindTextOnSel', plane=1,{
    {'s_FindTextOnSel', separator=1},
    {'Marks', ru='Метки', action=function() ActivateFind(3) end, key='Ctrl+F3',},
    {'Find Next Word/Selection', ru='Слово/выделение - в диалог поиска', action=Find_FindInDialog, key='Ctrl+F3',},
    {'Next Word/Selection', ru='Следующее слово/выделение', action=function() FindNextWrd(2) end, key='Alt+F3',},
    {'Prevous Word/Selection', ru='Предыдущее слово/выделение', action=function() FindNextWrd(2) end, key='Alt+Shift+F3',},
    {'Find All Word/Selection(Ctrl+Alt+Click)', ru='Найти все слова/выделения(Ctrl+Alt+Click)', action=FindSelToConcole, key='Alt+Shift+F',},
}})
menuhandler:InsertItem('MainWindowMenu', 'Edit¦Xml¦xxx',
{'FindTextOnSel', plane=1,{
    {'s_FindTextOnSel', separator=1},
    {'Move Controls...',  ru = 'Переместить контролы...', action=template_MoveControls, key = 'Alt+M', active='editor:LineFromPosition(editor.SelectionStart) ~= editor:LineFromPosition(editor.SelectionEnd)'},
}})
