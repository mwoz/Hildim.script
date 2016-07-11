local function Init()
    local spell = require "luahunspell"
    require "shell"

    local sRu = spell(props["SciteDefaultHome"]..'\\dics\\ru_RU.aff', props["SciteDefaultHome"]..'\\dics\\ru_RU.dic')
    local sEn = spell(props["SciteDefaultHome"]..'\\dics\\en_US.aff', props["SciteDefaultHome"]..'\\dics\\en_US.dic')
    local pUserRu = props["SciteDefaultHome"]..'\\dics\\user_RU.dic'
    local pUserEn = props["SciteDefaultHome"]..'\\dics\\user_EN.dic'

    sRu:add_dic(pUserRu)
    sEn:add_dic(pUserEn)
    assert(sRu, 'dict Ru not loaded')
    assert(sEn, 'dict En not loaded')
    local tblVariants = {}

    local mark = tonumber(props["spell.mark"])
    local cHeck, cSpell, cSkip = 0, 1,2
    local commentsStyles
    local cADDYODIC, cADDBYZXAMPLE = '<Add-to-Dic>', '<Add-with-Example>'
    local constFirstSpell = 65000     --65535 - максимально возможная комманда      coow
    local constAddToDic = 65500
    local constWithExample = 65501
    local SpellRange
    local bReset = false
    local bNeedList = false

    local fmSpellTag ={caption = true, caption_ru = true, tooltiptext = true, tooltiptext_ru = true, text =true}

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
        xml = {[9] = true, [29] = true, [0] = true, [6] = true},
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

    local function CheckNeedSpellFM(iStyle, p)
        --SCE_FM_VB_COMMENT,SCE_FM_VB_STRING,SCE_FM_X_COMMENT,SCE_FM_SQL_COMMENT,SCE_FM_SQL_LINE_COMMENT
        --print("          "..iStyle)
        if iStyle == 11 or iStyle == 14 or iStyle == 49 or iStyle == 54 or iStyle == 81 or iStyle == 82 then return cSpell
        elseif iStyle == 52 then --SCE_FM_X_STRING
            if fmSpellTag[editor:textrange(editor:WordStartPosition(p - 2), p - 1)] then return cSpell end
            return cSkip
        end
        return cHeck
    end

    local function CheckNeedSpellAll(iStyle, p)
        if commentsStyles[iStyle] then return cSpell end
        return cHeck
    end

    local function SpellRange1251(posStart, posEnd)
        if posStart == 0 then posStart = 1 end
        local e, s = posStart, 0
        local bSpell
        local str = editor:textrange(posStart - 1, posEnd + 1)
        for s, word, e in str:gmatch('[ \t\n\r!-/:-?\[-^{-§]()([A-Za-zА-яЁё]+)()') do
            if string.find(str:sub(e, e), '[ \t\n\r!-/:-?\[-^{-»]') then
                if word:byte() >= 160 then
                    bSpell = sRu:spell(word)
                else
                    if(word:sub(2) == word:sub(2):lower()) then
                        bSpell = sEn:spell(word)
                    else bSpell = true end
                end
                if not bSpell then
                    EditorMarkText(posStart + s - 2, e - s, mark)
                end
            end
        end
    end

    local function ProbabblyFromUT(str)
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then return str end
        return str:from_utf8(1251)
    end

    local function SpellRangeUTF8(posStart, posEnd)
        if posStart == 0 then posStart = 1 end
        local e, s = posStart, 0
        local bSpell
        local str = editor:textrange(posStart - 1, posEnd + 1):from_utf8(1251)
        local iUt = 2
        local t = nil
        --local str2 = editor:textrange(posStart-1, posEnd+1)
        for s, word, e in str:gmatch('[ \t\n\r!-/:-?\[-^{-§]()([A-Za-zА-яЁё]+)()') do
            if string.find(str:sub(e, e), '[ \t\n\r!-/:-?\[-^{-»]') then
                if word:byte() >= 160 then
                    bSpell = sRu:spell(word)
                else
                    if(word:sub(2) == word:sub(2):lower()) then
                        bSpell = sEn:spell(word)
                    else bSpell = true end
                end
                if not bSpell then
                    if t == nil then
                        t = {}
                        t[0] = 0
                        for i = 1, #str do
                            if (iUt == 2) ~= (str:byte(i) > 127) then if iUt == 2 then iUt = 1 else iUt = 2 end end
                            t[i] = t[i - 1] + iUt
                        end
                    end
                    local sb = editor:WordStartPosition(posStart + t[s - 2], t[e - s] + 1, true)
                    local se = editor:WordEndPosition(posStart + t[s - 2], t[e - s] + 1, true) - sb
                    -- print(editor:WordStartPosition(posStart+t[s-2],t[e-s]+ 1,true), editor:WordEndPosition(posStart+t[s-2],t[e-s]+ 1,true) - editor:WordStartPosition(posStart+t[s-2],t[e-s]+ 1,true),posStart+t[s-2],t[e-s]+ 1)
                    -- EditorMarkText(posStart+t[s-2],t[e-s]+ 1, mark)
                    EditorMarkText(sb, se, mark)
                    --EditorMarkText(editor:WordStartPosition(posStart+t[s-2],t[e-s]+ 1,true), editor:WordEndPosition(posStart+t[s-2],t[e-s]+ 1,true))
                end
            end
        end
    end

    local function OnSwitch_local()
        bReset = false
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then SpellRange = SpellRange1251 else SpellRange = SpellRangeUTF8 end
        if(editor.Lexer == SCLEX_FORMENJINE) then
            CheckNeedSpell = CheckNeedSpellFM
        else
            CheckNeedSpell = CheckNeedSpellAll
            commentsStyles = comment[props['Language']]
            if commentsStyles == nil then commentsStyles = {[1] = true} end
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
        EditorClearMarks(mark, posStart, posEnd - posStart)
        local iStyle
        local bNedSpell, iSpellingStyle, posStartSpell = cHeck,- 1, posEnd
        for i = posStart, posEnd do
            iStyle = editor.StyleAt[i]
            if bNedSpell == cSpell and (iStyle ~= iSpellingStyle or i == posEnd) then
                SpellRange(posStartSpell, i)
                bNedSpell, iSpellingStyle, posStartSpell = cHeck,- 1, posEnd
            elseif bNedSpell == cSkip and iStyle ~= iSpellingStyle then
                bNedSpell = cHeck
            elseif bNedSpell == cHeck then

                bNedSpell = CheckNeedSpell(iStyle, i)
                if bNedSpell~= cHeck then
                    iSpellingStyle, posStartSpell = iStyle, i
                end
            end
        end
    end


    local sPel, pUser, curLine
    local function ApplyVariant(str)
        if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8(1251) end
        local function saveDic(newWord, pUser)
            local text = ''
            local tbl = {}
            local file
            if shell.fileexists(pUser) then
                file = io.input(pUser)
                text = file:read('*a')
                text = text:gsub('^.-\n', '')
                text = text..'\n'
                file:close()
            end
            text = text..newWord
            for w in string.gmatch(text, "[^\n\r]+") do
                table.insert(tbl, w)
            end
            table.sort(tbl)
            text = #tbl..'\n'..table.concat(tbl, '\n')
            file = io.output(pUser)
            file:write(text)

            file:flush()
            file:close()
        end
        local s = scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos)
        local e = scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos)
        if str == cADDBYZXAMPLE then
            local dlg = _G.dialogs["spell"]
            if dlg == nil then
                local txt_sorse = iup.text{size = '70x0'}
                local txt_example = iup.text{value = "", size = "70x0"}
                local btn_ok = iup.button  {title = "OK"}
                iup.SetHandle("BTN_OK", btn_ok)

                local btn_esc = iup.button  {title = "Cancel"}
                iup.SetHandle("BTN_ESC", btn_esc)

                local vbox = iup.vbox{ iup.hbox{iup.label{title = "Вставить:", gap = 3}, txt_sorse, iup.label{title = "Образец:"}, txt_example}, iup.hbox{btn_ok, btn_esc, gap = 200}, gap =2,margin="4x4" }
                local result = false

                local dlg = iup.scitedialog{vbox; title = "Добавление по образцу", defaultenter = "BTN_OK", defaultesc = "BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid="spell",
                    show_cb =(function(h, state)
                        if state == 0 then
                            local s = scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos)
                            local e = scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos)

                            local word = ProbabblyFromUT(editor:textrange(s, e))
                            txt_sorse.value = word

                            txt_example.value = ''
                            if word:byte() >= 160 then
                                sPel = sRu
                                pUser = pUserRu
                            else
                                sPel = sEn
                                pUser = pUserEn
                            end
                            curLine = editor:LineFromPosition(s)
                        end
            end) }

            function btn_ok:action()                        -- о вазможная комманда      coow
                local bOk = false
                local ex = txt_example.value
                if #ex > 0 then
                    if(sPel:spell(ex)) then
                        local t = sPel:stem(ex)
                        for _, v in ipairs(t) do
                            if(ex == v) then bOk = true; break end
                        end
                        if bOk then
                            local word = txt_sorse.value
                            local strFlag = sPel:add_with_affix(word, ex)
                            saveDic(word..'/'..strFlag, pUser)
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

            function btn_esc:action() --фрейм
                dlg:hide()
                txt_sorse.value = 'sdsdsds'
                --[[iup.Destroy(dlg)]];
            end
            else
                dlg:show();
            end
        elseif str == cADDYODIC then
            local word = ProbabblyFromUT(editor:textrange(s, e))
            --EditorClearMarks(mark,s,e-s)
            local sPel, pUser
            if word:byte() >= 160 then
                sPel = sRu
                pUser = pUserRu
            else
                sPel = sEn
                pUser = pUserEn
            end
            sPel:add_word(word)
            saveDic(word, pUser)
            curLine = editor:LineFromPosition(s)
            SpellLexer(editor:PositionFromLine(curLine), editor.LineEndPosition[curLine])

        else
            editor.TargetStart = s
            editor.TargetEnd = e
            editor:ReplaceTarget(str)
        end
        return true

    end --fghgfhgtgh

    local spellStart, spellEnd
    local function OnColorise_local(s, e)
        if tonumber(_G.iuprops["spell.autospell"]) == 1 and editor.Lexer ~= SCLEX_ERRORLIST then
            if spellEnd and spellStart then
                spellStart = math.min(spellStart, s)
                spellEnd = math.max(spellEnd, e)
            else spellStart, spellEnd = s, e end
            --SpellLexer(s, e)
        end
    end

    function spell_ErrorList()
        local prLine = editor:LineFromPosition(editor.CurrentPos)
        local fLine = editor.FirstVisibleLine
        editor:DocumentEnd()
        editor:LineScroll(1, fLine)
        editor:GotoLine(prLine)
        bNeedList = true
    end

    local function ListErrors()
        local count, lCount, line = 0, 0,-1
        local s, e = 0,- 1

        local iPos, nextStart = 0, 0
        local lineErrors = ""
        local out = ""
        while iPos < editor.TextLength do
            iPos = scite.SendEditor(SCI_INDICATOREND, mark, nextStart)
            if iPos >= editor.TextLength or iPos == nextStart then break end

            nextStart = scite.SendEditor(SCI_INDICATOREND, mark, iPos)
            local word = ProbabblyFromUT(editor:textrange(editor:WordStartPosition(iPos, true), nextStart))

            count = count + 1
            local l = editor:LineFromPosition(iPos)
            if l == line then
                lineErrors = lineErrors..':'..word
            else
                if lineErrors ~= "" then
                    out = out..lineErrors..': '..ProbabblyFromUT(editor:GetLine(line):gsub('^ *', ''))
                end
                lineErrors = '\t'..(l + 1)..':'..word
                line = l
                lCount = lCount + 1
            end
        end
        if lineErrors ~= "" then
            out = out..lineErrors..': '..ProbabblyFromUT(editor:GetLine(line))
        end
        out = out..'<\r\n'

        for line = 0, editor.LineCount do
            local level = scite.SendFindRes(SCI_GETFOLDLEVEL, line)
            if (shell.bit_and(level, SC_FOLDLEVELHEADERFLAG)~= 0 and SC_FOLDLEVELBASE == shell.bit_and(level, SC_FOLDLEVELNUMBERMASK)) then
                scite.SendFindRes(SCI_SETFOLDEXPANDED, line)
                local lineMaxSubord = scite.SendFindRes(SCI_GETLASTCHILD, line,- 1)
                if line < lineMaxSubord then scite.SendFindRes(SCI_HIDELINES, line + 1, lineMaxSubord) end
            end
        end

        scite.SendFindRes(SCI_SETSEL, 0, 0)
        scite.SendFindRes(SCI_REPLACESEL, out)
        if scite.SendFindRes(SCI_LINESONSCREEN) == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end
        scite.SendFindRes(SCI_SETSEL, 0, 0)
        scite.SendFindRes(SCI_REPLACESEL, '>Spell        Errors: '..count..' in '..lCount..' lines\n '..props["FilePath"]..'\n')
    end

    local function OnIdle_local()
        if spellEnd then
            if not bReset then
                if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then SpellRange = SpellRange1251 else SpellRange = SpellRangeUTF8 end
                bReset = true
            end
            SpellLexer(spellStart, spellEnd)
            spellStart, spellEnd = nil, nil
        end
        if bNeedList then bNeedList = false; ListErrors() end
    end

    function spell_Selected()
        local posStart, posEnd = editor.SelectionStart, editor.SelectionEnd
        EditorClearMarks(mark, posStart, posEnd - posStart)
        SpellRange(editor.SelectionStart, editor.SelectionEnd)
    end

    function spell_ByLex()
        local s, e = editor.SelectionStart, editor.SelectionEnd
        if s == e then s, e = 0, editor.TextLength end
        _G.iuprops["spell.autospell"] = 0
        editor:Colourise(s, e)
        _G.iuprops["spell.autospell"] = 1
        SpellLexer(s, e)
    end

    local function FillVariantsMenu()
        local lst = {}

        local word = ProbabblyFromUT(editor:textrange(scite.SendEditor(SCI_INDICATORSTART, mark, editor.CurrentPos), scite.SendEditor(SCI_INDICATOREND, mark, editor.CurrentPos)))

        local s
        if word:byte() >= 192 then --eror
            s = sRu
        else
            s = sEn
        end
        local t = s:suggest(word)
        tblVariants = {}
        for _, v in ipairs(t) do
            --if s == sRu then v = shell.to_utf8(v) end
            table.insert(lst, {v, action = function() ApplyVariant(v) end})
        end
        if #t > 0 then end table.insert(lst,{'sSpell1', separator = 1})
        current_poslst = editor.CurrentPos
        return lst
    end

    local function OnMenuCommand_local(msg, source)
        if msg < constFirstSpell then return end
        if msg == constAddToDic then str = cADDYODIC
        elseif msg == constWithExample then str = cADDBYZXAMPLE
            else str = tblVariants[msg] end
            OnUserListSelection_local(str)
        end

        AddEventHandler("OnColorized", OnColorise_local)
        AddEventHandler("OnOpen", OnSwitch_local)
        AddEventHandler("OnSwitchFile", OnSwitch_local)
        AddEventHandler("OnIdle", OnIdle_local)
        table.insert(onDestroy_event, function() sRu:destroy(); sEn:destroy(); end)

        local function ResetAutoSpell()
            CheckChange('spell.autospell', true)
            local h = iup.GetDialogChild(iup.GetLayout(), "Spelling_zbox")
            if h then
                h.valuepos = Iif(_G.iuprops["spell.autospell"]..'' == "1", 1, 0)
                iup.Redraw(h, 1)
                iup.Update(h)
            end
        end

        menuhandler:InsertItem('EDITOR', 's0',
            {'Spelling Variants', plane = 1,
                visible = function() return scite.SendEditor(SCI_INDICATORVALUEAT, mark, editor.CurrentPos) == 1 end,
                bottom ={"Context Menu", ru = "Контекстное меню"}, {
                    {'list', plane = 1, FillVariantsMenu},
                    {cADDYODIC, action = function() ApplyVariant(cADDYODIC) end,},
                    {cADDBYZXAMPLE, action = function() ApplyVariant(cADDBYZXAMPLE) end,},
                    {'sSpell2', separator = 1},
            }}
        )
        menuhandler:InsertItem('MainWindowMenu', 'Tools¦s1',
            {'Spelling', ru = 'Орфография',{
                {'Auto Spell Check', ru = 'Проверять автоматически', action = ResetAutoSpell, check = "tonumber(_G.iuprops['spell.autospell']) == 1", key = 'Ctrl+Alt+F12',},
                {'s1', separator = 1,},
                {'Check Selection', ru = 'Проверить выделенный фрагмент', action = spell_Selected, key = 'Ctrl+F12', image = 'IMAGE_CheckSpelling',},
                {'Check Selection, By Highlighting', ru = 'Проверить фрагмент с учетом подсветки', action=spell_ByLex,},
                {'List Errors', ru = 'Показать список ошибок', action = spell_ErrorList, key = 'Ctrl+Shift+F12', image = 'report__exclamation_µ'},
        }}
    )
    _G.g_session["spell.runned"] = true
end

return {
    title = 'Проверка орфографии',
    hidden = Init,
}
