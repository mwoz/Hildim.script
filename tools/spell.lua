local spell = require "luahunspell"
require "shell"

local sRu= spell(props["SciteDefaultHome"]..'\\dics\\ru_RU.aff',props["SciteDefaultHome"]..'\\dics\\ru_RU.dic')
local sEn= spell(props["SciteDefaultHome"]..'\\dics\\en_US.aff',props["SciteDefaultHome"]..'\\dics\\en_US.dic')
local pUserRu = props["SciteDefaultHome"]..'\\dics\\user_RU.dic'
local pUserEn = props["SciteDefaultHome"]..'\\dics\\user_EN.dic'
sRu:add_dic(pUserRu)
sEn:add_dic(pUserEn)
assert(sRu, 'dict Ru not loaded')
assert(sEn, 'dict En not loaded')
local tblVariants = {}

local mark = tonumber(props["spell.mark"])
local cHeck,cSpell,cSkip=0,1,2
local commentsStyles
local cADDYODIC,cADDBYZXAMPLE = '<Add-to-Dic>','<Add-with-Example>'
local constFirstSpell = 65000     --65535 - ����������� ��������� ��������      coow
local constAddToDic = 65500
local constWithExample = 65501

local fmSpellTag={caption=true,caption_ru=true,tooltiptext=true,tooltiptext_ru=true,text=true}

local comment = {
    abap = {[1] = true, [2] = true},
    ada = {[10] = true},
    asm = {[1] = true, [11] = true},
    au3 = {[1] = true, [2] = true},
    baan = {[1] = true, [2] = true},
    bullant = {[1] = true, [2] = true, [3] = true},
    caml = {[12] = true, [13] = true, [14] = true, [15] = true},
    cpp = {[1] = true, [2] = true, [3] = true, [15] = true, [17] = true, [18] = true},
    csound = {[1] = true, [9] = true},
    css = {[9] = true},
    d = {[1] = true, [2] = true, [3] = true, [4] = true, [15] = true, [16] = true, [17] = true},
    escript = {[1] = true, [2] = true, [3] = true},
    flagship = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true},
    forth = {[1] = true, [2] = true, [3] = true},
    gap = {[9] = true},
    hypertext = {[9] = true, [20] = true, [29] = true, [42] = true, [43] = true, [44] = true, [57] = true, [58] = true, [59] = true, [72] = true, [82] = true, [92] = true, [107] = true, [124] = true, [125] = true},
    xml = {[9] = true, [29] = true},
    inno = {[1] = true, [7] = true},
    latex = {[4] = true},
    lua = {[1] = true, [2] = true, [3] = true},
    script_lua = {[4] = true, [5] = true},
    mmixal = {[1] = true, [17] = true},
    nsis = {[1] = true, [18] = true},
    opal = {[1] = true, [2] = true},
    pascal = {[1] = true, [2] = true, [3] = true},
    perl = {[2] = true},
    bash = {[2] = true},
    pov = {[1] = true, [2] = true},
    ps = {[1] = true, [2] = true, [3] = true},
    python = {[1] = true, [12] = true},
    rebol = {[1] = true, [2] = true},
    ruby = {[2] = true},
    scriptol = {[2] = true, [3] = true, [4] = true, [5] = true},
    smalltalk = {[3] = true},
    specman = {[2] = true, [3] = true},
    spice = {[8] = true},
    sql = {[1] = true, [2] = true, [3] = true, [13] = true, [15] = true, [17] = true, [18] = true},
    mssql = {[1] = true, [2] = true, [3] = true, [13] = true, [15] = true},
    tcl = {[1] = true, [2] = true, [20] = true, [21] = true},
    verilog = {[1] = true, [2] = true, [3] = true},
    vhdl = {[1] = true, [2] = true}
}
local CheckNeedSpell

local function CheckNeedSpellFM(iStyle,p)
    --SCE_FM_VB_COMMENT,SCE_FM_VB_STRING,SCE_FM_X_COMMENT,SCE_FM_SQL_COMMENT,SCE_FM_SQL_LINE_COMMENT
    --print("          "..iStyle)
    if iStyle == 11 or iStyle == 14 or iStyle == 54 or iStyle == 81 or iStyle == 82 then return cSpell
    elseif iStyle == 52 then  --SCE_FM_X_STRING
        if fmSpellTag[editor:textrange(editor:WordStartPosition(p-2),p-1)] then return cSpell end
        return cSkip
    end
    return cHeck
end

local function CheckNeedSpellAll(iStyle,p)
    if commentsStyles[iStyle] then return cSpell end
    return cHeck
end

local function SpellRange(posStart, posEnd)
    if posStart == 0 then posStart = 1 end
    local e,s = posStart,0
    local bSpell
    local str = editor:textrange(posStart-1, posEnd+1)
    for s,word,e in str:gmatch('[ \t\n\r!-/:-?\[-^{-�]()([A-Za-z�-���]+)()') do
        if string.find(str:sub(e,e),'[ \t\n\r!-/:-?\[-^{-�]') then
            if word:byte() >=160 then
                bSpell = sRu:spell(word)
            else
                if(word:sub(2) == word:sub(2):lower()) then
                    bSpell = sEn:spell(word)
                else bSpell = true  end
            end
            if not bSpell then
                EditorMarkText(posStart+s-2,e-s, mark)
            end
        end
    end
end

local function OnSwitch_local()
    if(editor.Lexer  == SCLEX_FORMENJINE) then
        CheckNeedSpell = CheckNeedSpellFM
    else
        CheckNeedSpell = CheckNeedSpellAll
        commentsStyles = comment[props['Language']]
        if commentsStyles == nil then commentsStyles = {[1]=true} end
    end
end

local function SpellLexer(posStart, posEnd)
    if posEnd < 0 then posEnd = editor.TextLength end
    if not CheckNeedSpell then OnSwitch_local() end
    if posStart > posEnd then
        print('SpellLexer error:', posStart, posEnd)
        return
    end
    --print(posS tart, posend)
    EditorClearMarks(mark,posStart, posEnd - posStart)
    local iStyle
    local bNedSpell,iSpellingStyle, posStartSpell = cHeck,-1,posEnd
    for i = posStart, posEnd do
        iStyle = editor.StyleAt[i]
        if bNedSpell==cSpell and (iStyle ~= iSpellingStyle or i == posEnd) then
            SpellRange(posStartSpell, i)
            bNedSpell,iSpellingStyle, posStartSpell = cHeck,-1,posEnd
        elseif bNedSpell==cSkip and iStyle ~= iSpellingStyle then
            bNedSpell = cHeck
        elseif bNedSpell==cHeck then

            bNedSpell = CheckNeedSpell(iStyle,i)
            if bNedSpell~=cHeck then
                iSpellingStyle, posStartSpell = iStyle,i
            end
        end
    end
end

local sPel, pUser, curLine
local function OnUserListSelection_local(tp,str)
    local function saveDic(newWord,pUser)
        local text    = ''
        local tbl     = {}
        local file
        if shell.fileexists(pUser) then
            file = io.input(pUser)
            text = file:read('*a')
            text = text:gsub('^.-\n','')
            text = text..'\n'
            file:close()
        end
        text = text..newWord
        for w in string.gmatch(text, "[^\n\r]+") do
            table.insert(tbl, w)
        end
        table.sort(tbl)
        text = #tbl..'\n'..table.concat(tbl,'\n')
        file = io.output(pUser)
        file:write(text)

        file:flush()
        file:close()
    end
    if tp == 800 then
        local s = scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos)
        local e = scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos)
        if str == cADDBYZXAMPLE then
            local dlg = _G.dialogs["spell"]
            if dlg == nil then
                local txt_sorse = iup.text{size='70x0'}
                local txt_example = iup.text{value="", size="70x0"}
                local btn_ok = iup.button  {title="OK"}
                iup.SetHandle("BTN_OK",btn_ok)

                local btn_esc = iup.button  {title="Cancel"}
                iup.SetHandle("BTN_ESC",btn_esc)

                local vbox = iup.vbox{ iup.hbox{iup.label{title="��������:", gap=3},txt_sorse,iup.label{title="�������:"}, txt_example}, iup.hbox{btn_ok,btn_esc,gap=200},gap=2,margin="4x4" }
                local result = false

                local dlg = iup.scitedialog{vbox; title="���������� �� �������",defaultenter="BTN_OK",defaultesc="BTN_ESC",maxbox="NO",minbox ="NO",resize ="NO", sciteparent="SCITE", sciteid="spell",
                show_cb =(function(h, state)
                    if state == 0 then
                        local s = scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos)
                        local e = scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos)

                        local word = editor:textrange(s,e)
                        txt_sorse.value = word

                        txt_example.value = ''
                        if word:byte() >=160 then
                            sPel = sRu
                            pUser = pUserRu
                        else
                            sPel = sEn
                            pUser = pUserEn
                        end
                        curLine = editor:LineFromPosition(s)
                    end
                end) }

                function btn_ok:action()                        -- � ��������� ��������      coow
                    local bOk = false
                    local ex = txt_example.value
                    if #ex > 0 then
                        if(sPel:spell(ex)) then
                            local t = sPel:stem(ex)
                            for _,v in ipairs(t) do
                                if(ex == v) then bOk = true; break end
                            end
                            if bOk then
                                local word = txt_sorse.value
                                local strFlag = sPel:add_with_affix(word,ex)
                                saveDic(word..'/'..strFlag,pUser)
                                SpellLexer(editor:PositionFromLine(curLine), editor.LineEndPosition[curLine])
                            end
                        end
                    end

                    if bOk then
                        dlg:hide()
                        --[[iup.Destroy(dlg)]]
                    else
                        txt_example.value = '<bAd>'
                    end
                end

                function btn_esc:action() --�����
                    dlg:hide()
                    txt_sorse.value = 'sdsdsds'
                    --[[iup.Destroy(dlg)]];
                end
            else
                dlg:show();
            end
        elseif str == cADDYODIC then
            local word = editor:textrange(s,e)
            --EditorClearMarks(mark,s,e-s)
            local sPel, pUser
            if word:byte() >=160 then
                sPel = sRu
                pUser = pUserRu
            else
                sPel = sEn
                pUser = pUserEn
            end
            sPel:add_word(word)
            saveDic(word,pUser)
            curLine = editor:LineFromPosition(s)
            SpellLexer(editor:PositionFromLine(curLine), editor.LineEndPosition[curLine])

        else
            editor.TargetStart = s
            editor.TargetEnd = e
            editor:ReplaceTarget(str)
        end
        return true
    end
end

local function OnClick_Local(shift, ctrl, alt)
	if scite.SendEditor(SCI_INDICATORVALUEAT, mark, editor.CurrentPos) == 1 and alt then
        local word = editor:textrange(scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos), scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos))
        local s
        if word:byte() >=192 then
            s = sRu
        else
            s = sEn
        end
        local t = s:suggest(word)
        local found = false
        local str = ''
        for _,v in ipairs(t) do
            str = str..v..'�'
        end
        str = str..cADDYODIC..'�'..cADDBYZXAMPLE
        editor.AutoCSeparator = string.byte('�')
        scite.SendEditor(SCI_AUTOCSETMAXHEIGHT,16)

        editor:UserListShow(800, str)

        bIsListVisible = true
        current_poslst = editor.CurrentPos
        return true
    end
end

local function OnColorise_local(s,e)
--print(props["spell.autospell"])
    if tonumber(props["spell.autospell"]) == 1 and editor.Lexer ~= SCLEX_ERRORLIST then
        SpellLexer(s, e)
    end
end

function spell_Selected()
    local posStart,posEnd = editor.SelectionStart, editor.SelectionEnd
    EditorClearMarks(mark,posStart, posEnd - posStart)
    SpellRange(editor.SelectionStart, editor.SelectionEnd)
end

function spell_ByLex()
    local s,e = editor.SelectionStart,editor.SelectionEnd
    if s==e then s,e = 0,editor.TextLength end
    props["spell.autospell"] = 0
    editor:Colourise(s,e)
    props["spell.autospell"] = 1
    SpellLexer(s,e)
end

function spell_ErrorList()
--[[    local iPos = scite.SendEditor(SCI_INDICATOREND, mark, 1)
    print(editor:textrange(editor:WordStartPosition(iPos, true),
							editor:WordEndPosition(iPos, true)))
    print(scite.SendEditor(SCI_INDICATOREND, mark, editor:WordEndPosition(iPos, true)), iPos)      ���������
    print(scite.SendEditor(SCI_INDICATOREND, mffrk, editor.TextLength-20), editor.TextLength)]]
    local count,lCount,line = 0,0,-1
    local s,e = 0,-1

    local iPos,nextStart = 0,0
    local lineErrors = ""
    local out = ""
    while iPos < editor.TextLength do
        iPos = scite.SendEditor(SCI_INDICATOREND, mark, nextStart)
        if iPos >= editor.TextLength or iPos == nextStart then break end

        nextStart = scite.SendEditor(SCI_INDICATOREND, mark, iPos)
        local word = editor:textrange(editor:WordStartPosition(iPos, true), nextStart)

        count = count + 1
        local l = editor:LineFromPosition(iPos)
        if l == line then
            lineErrors = lineErrors..':'..word
        else
            if lineErrors ~= "" then
                out = out..lineErrors..':'..editor:GetLine(line)
            end
            lineErrors = '.\\'..props['FileNameExt']..':'..(l + 1)..':'..word
            line = l
            lCount = lCount + 1
        end
    end
    if lineErrors ~= "" then
        out = out..lineErrors..':'..editor:GetLine(line)
    end
    out = out..'>!!    Errors: '..count..' in '..lCount..' lines\n'

    for line = 0, editor.LineCount do
        local level = scite.SendFindRez(SCI_GETFOLDLEVEL, line)
        if (shell.bit_and(level,SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE == shell.bit_and(level,SC_FOLDLEVELNUMBERMASK))then
            scite.SendFindRez(SCI_SETFOLDEXPANDED, line)
            local lineMaxSubord = scite.SendFindRez(SCI_GETLASTCHILD, line,-1)
            if line < lineMaxSubord then scite.SendFindRez(SCI_HIDELINES, line + 1, lineMaxSubord) end
        end
    end

    scite.SendFindRez(SCI_SETSEL,0,0)
    scite.SendFindRez(SCI_REPLACESEL, out)
    if scite.SendFindRez(SCI_LINESONSCREEN) == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end
    scite.SendFindRez(SCI_SETSEL,0,0)
    scite.SendFindRez(SCI_REPLACESEL, '>??Spell in "'..props["FileNameExt"]..'"\n')
end

local function OnContextMenu_local(lp, wp, source)       --������ eror  ��������
    if source ~= "EDITOR" then return end
	if scite.SendEditor(SCI_INDICATORVALUEAT, mark, editor.CurrentPos) == 1 then
        local word = editor:textrange(scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos), scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos))
        local s
        if word:byte() >=192 then
            s = sRu
        else
            s = sEn
        end
        local t = s:suggest(word)
        local found = false
        local str = ''
        local cmd = constFirstSpell
        tblVariants = {}
        for _,v in ipairs(t) do
            table.insert(tblVariants, cmd, v)
            if s == sRu then v = shell.to_utf8(v) end
            str = str..v..'|'..cmd..'|'
            cmd = cmd + 1
        end
        if cmd > 0 then str = str..'||' end
        str = str..cADDYODIC..'|'..constAddToDic..'|'..cADDBYZXAMPLE..'|'..constWithExample..'|||'
        str = str..'Context Menu...|POPUPBEGIN|[MAIN]Context Menu...|POPUPEND|'
        current_poslst = editor.CurrentPos
        return str
    end
end
local function OnMenuCommand_local(msg, source)
    if msg < constFirstSpell then return end
    if msg == constAddToDic then str = cADDYODIC
    elseif msg == constWithExample then str = cADDBYZXAMPLE
    else str = tblVariants[msg] end
    OnUserListSelection_local(800,str)
end

AddEventHandler("OnClick",OnClick_Local)
AddEventHandler("OnUserListSelection", OnUserListSelection_local)
AddEventHandler("OnColorized", OnColorise_local)
AddEventHandler("OnOpen", OnSwitch_local)
AddEventHandler("OnSwitchFile", OnSwitch_local)
AddEventHandler("OnContextMenu", OnContextMenu_local)
AddEventHandler("OnMenuCommand", OnMenuCommand_local)

