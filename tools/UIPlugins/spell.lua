local sRu, sEn, mark, linda

local function Init()
    if not luahunspell then luahunspell = require"luahunspell" end
    if not shell then shell = require"shell" end
    if not lanes then
        lanes = require("lanes").configure()
    end
    linda = lanes.linda()

    local tblVariants = {}

    mark = CORE.InidcFactory('Spell.Errors', _T'Spelling errors', INDIC_SQUIGGLE, 255, 0)
    local cHeck, cSpell, cSkip = 0, 1,2
    local commentsStyles
    local cADDYODIC, cADDBYZXAMPLE = '<'.._T'Add to Dictionary'..'>', '<'.._T'Add according to model'..'>'
    local constFirstSpell = 65000     --65535 - максимально вазможная кмманда
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
        hypertext = {[9] = true, [20] = true, [29] = true, [42] = true, [43] = true, [44] = true, [57] = true, [58] = true, [59] = true, [72] = true, [82] = true, [92] = true, [107] = true, [124] = true, [125] = true, [0] = true},
        xml = {[9] = true, [29] = true, [0] = true, [6] = true},
        inno = {[1] = true, [7] = true},
        latex = {[4] = true},
        lua = {[1] = true, [2] = true, [3] = true},
        script_lua = {[4] = true, [5] = true},
        script_wiki = {[0] = true, [1] = true,[2] = true, [3] = true,[4] = true, [5] = true,[6] = true, [7] = true, [8] = true, [9] = true, [10] = true,},
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
        local bSpell
        local str = editor:textrange(posStart - 1, posEnd)
        linda:send("_Spell", {cmd = "SPELL_WIN", posStart = posStart, posEnd = posEnd, str = str})
    end

    AddEventHandler("OnLindaNotify", function(key)
        if key == 'Spell' then
            local key, val = linda:receive( 1.0, "Spell")    -- timeout in seconds
            if val.cmd == 'SPELL_ERR_WIN' then
                EditorMarkText(val[1], val[2], mark)
            elseif val.cmd == 'SPELL_ERR_UTF' then
                -- local sb = editor:WordStartPosition(val[1], val[2], true)
                --local se = editor:WordEndPosition(val[1], val[2], true) - sb
                -- EditorMarkText(sb, se, mark)
                EditorMarkText(val[1], val[2], mark)
            end
        end
    end)

    local function ProbabblyFromUT(str)
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then return str end
        return str:from_utf8()
    end

    local function SpellRangeUTF8(posStart, posEnd)
        if posStart == 0 then posStart = 1 end
        local str = editor:textrange(posStart - 1, posEnd + 1):from_utf8()
        linda:send("_Spell", {cmd = "SPELL_UTF", posStart = posStart, posEnd = posEnd, str = str})

    end

    local function SpellLoop(defHome)
        shell = require"shell"
        luahunspell = require"luahunspell"

        local sRu, sEn
        sRu = luahunspell.Create(defHome..'\\dics\\ru_RU.aff', defHome..'\\dics\\ru_RU.dic')
        sEn = luahunspell.Create(defHome..'\\dics\\en_US.aff', defHome..'\\dics\\en_US.dic')
        local pUserRu = defHome..'\\dics\\user_RU.dic'
        local pUserEn = defHome..'\\dics\\user_EN.dic'
        sRu:add_dic(pUserRu)
        sEn:add_dic(pUserEn)
        assert(sRu, 'dict Ru not loaded')
        assert(sEn, 'dict En not loaded')

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

        local function spellRangeWin(posStart, posEnd, str)
            if posStart == 0 then posStart = 1 end
            local e, s = posStart, 0
            local bSpell

            for s, word, e in str:gmatch('[ \t\n\r!-/:-?\\[-^{-§]()([A-Za-zА-яЁё]+)()') do
                if string.find(str:sub(e, e), '[ \t\n\r!-/:-?\\[-^{-»]') then
                    if word:byte() >= 160 then
                        bSpell = sRu:spell(word)
                    else
                        if(word:sub(2) == word:sub(2):lower()) then
                            bSpell = sEn:spell(word)
                        else bSpell = true end
                    end
                    if not bSpell then
                        linda:send("Spell", {cmd = "SPELL_ERR_WIN", posStart + s - 2, e - s})
                        --EditorMarkText(posStart + s - 2, e - s, mark)
                    end
                end
            end
        end

        local function spellRangeUTF(posStart, posEnd, str)
            if posStart == 0 then posStart = 1 end
            local e, s = posStart, 0
            local bSpell
            local iUt = 2
            local t = nil
            --local str2 = editor:textrange(posStart-1, posEnd+1)
            for s, word, e in str:gmatch('[ \t\n\r!-/:-?\\[-^{-§]()([A-Za-zА-яЁё]+)()') do
                if string.find(str:sub(e, e), '[ \t\n\r!-/:-?\\[-^{-»]') then
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
                        linda:send("Spell", {cmd = "SPELL_ERR_UTF", posStart + t[s - 2], t[e - s] + 1})

                    end
                end
            end
        end

        local function fillVariantsMenu(word)
            if word == '' then return end
            local s
            if word:byte() >= 192 then --eror
                s = sRu
            else
                s = sEn
            end
            local t = s:suggest(word)
            tblVariants = {}

            linda:send("_Spell_Variants", t)
        end

        local function add(word)
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
            linda:send("_Spell_Add", true)
        end
        local function addWithExample(word, ex)
            local s
            if word:byte() >= 192 then --eror
                s = sRu
                pUser = pUserRu
            else
                s = sEn
                pUser = pUserRu
            end
            local bOk = false
            if(s:spell(ex)) then
                local t = s:stem(ex)
                for _, v in ipairs(t) do
                    if(ex == v) then bOk = true; break end
                end
                if bOk then
                    local strFlag = s:add_with_affix(word, ex)
                    saveDic(word..'/'..strFlag, pUser)
                end
            end
            linda:send("_Spell_AddWithExample", bOk)
        end

        while true do
            local key, val = linda:receive( 100, "_Spell")
            if val ~= nil then
                if val.cmd == "SPELL_WIN" then
                    spellRangeWin(val.posStart, val.posEnd, val.str)
                elseif val.cmd == "SPELL_UTF" then
                    spellRangeUTF(val.posStart, val.posEnd, val.str)
                elseif val.cmd == "VARIANTS" then
                    fillVariantsMenu(val.word)
                elseif val.cmd == "ADDWITHEXAMPLE" then
                    addWithExample(val.word, val.ex)
                elseif val.cmd == "ADD" then
                    add(val.word)
                elseif val.cmd == "EXIT" then
                    sRu:destroy(); sEn:destroy();
                    break;
                end
            end
        end
    end

    local a = lanes.gen( "package,string,table,io", {required = {"luahunspell", "shell"}}, SpellLoop)(props["SciteDefaultHome"])

    local function OnSwitch_local()
        bReset = false
        if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then SpellRange = SpellRange1251 else SpellRange = SpellRangeUTF8 end
        if(editor.Lexer == SCLEX_FORMENJINE) then
            CheckNeedSpell = CheckNeedSpellFM
        else
            CheckNeedSpell = CheckNeedSpellAll
            commentsStyles = comment[props['Language']]
            if commentsStyles == nil then commentsStyles = {[0] = true} end
        end
    end

    local function SpellLexer(posStart, posEnd)
        if posEnd < 0 then posEnd = editor.TextLength end
        if not CheckNeedSpell then OnSwitch_local() end
        if posStart > posEnd then
            print('SpellLexer error:', posStart, posEnd)
            return
        end
        EditorClearMarks(mark, posStart, posEnd - posStart)
        local iStyle
        local bNedSpell, iSpellingStyle, posStartSpell = cHeck,- 1, posEnd
        for i = posStart, posEnd do
            iStyle = editor:ustyle(i)
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

        local s = editor:IndicatorStart(mark, editor.CurrentPos)
        local e = editor:IndicatorEnd(mark, editor.CurrentPos)
        if str == cADDBYZXAMPLE then
            local dlg = _G.dialogs["spell"]
            if dlg == nil then
                local txt_sorse = iup.text{size = '70x0'}
                local txt_example = iup.text{value = "", size = "70x0"}
                local btn_ok = iup.button  {title = "OK"}
                iup.SetHandle("BTN_OK", btn_ok)

                local btn_esc = iup.button  {title = _TH"Cancel"}
                iup.SetHandle("BTN_ESC", btn_esc)

                local vbox = iup.vbox{ iup.hbox{iup.label{title = _T"Insert:", gap = 3}, txt_sorse, iup.label{title = _T"Model:"}, txt_example}, iup.hbox{btn_ok, btn_esc, gap = 200}, gap =2,margin="4x4" }
                local result = false

                local dlg = iup.scitedialog{vbox; title = _T"Add according to model", defaultenter = "BTN_OK", defaultesc = "BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid="spell",
                    show_cb =(function(h, state)
                        if state == 0 then
                            local s = editor:IndicatorStart(mark, editor.CurrentPos)
                            local e = editor:IndicatorEnd(mark, editor.CurrentPos)

                            local word = ProbabblyFromUT(editor:textrange(s, e))
                            txt_sorse.value = word:to_utf8()

                            txt_example.value = ''

                            curLine = editor:LineFromPosition(s)
                        end
            end) }

            function btn_ok:action()                        -- о вазможная комманда      coow
                local bOk = false
                local ex = txt_example.value:from_utf8()
                local word = txt_sorse.value:from_utf8()
                if #ex > 0 then

                    linda:send("_Spell", {cmd = "ADDWITHEXAMPLE", word = word, ex = ex})
                    local key
                    key, bOk = linda:receive(3.0, "_Spell_AddWithExample")

                end

                if bOk then
                    SpellLexer(editor:PositionFromLine(curLine), editor.LineEndPosition[curLine])
                    dlg:hide()
                else
                    txt_example.value = '<bAd>'
                end
            end

            function btn_esc:action() --фреймаа
                dlg:hide()
                txt_sorse.value = 'sdsdsds'
                --[[iup.Destroy(dlg)]];
            end
            else
                dlg:show();
            end
        elseif str == cADDYODIC then
            local word = ProbabblyFromUT(editor:textrange(s, e))

            linda:send("_Spell", {cmd = "ADD", word = word})
            local key, bOk = linda:receive(3.0, "_Spell_Add")

            curLine = editor:LineFromPosition(s)
            SpellLexer(editor:PositionFromLine(curLine), editor.LineEndPosition[curLine])

        else
            if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then str = str:to_utf8() end
            editor.TargetStart = s
            editor.TargetEnd = e
            editor:ReplaceTarget(str)
        end
        return true

    end --корова

    local spellStart, spellEnd
    local spellStartMin, spellEndMax
    local function OnColorise_local(s, e)
        local bEd, bLen = pcall(function() return not(editor.Length > 10 ^(_G.iuprops['spell.maxsize'] or 7)) end)
        if not bEd or not bLen then return end
        if tonumber(_G.iuprops["spell.autospell"]) == 1 and editor.Lexer ~= SCLEX_ERRORLIST then
            if spellEnd and spellStart then
                spellStart = math.min(spellStart, s)
                spellEnd = math.max(spellEnd, e)
            else spellStart, spellEnd = s, e end
        end
    end
    AddEventHandler("OnUpdateUI", function(bChange) if bChange ~= 0 then spellStartMin, spellEndMax = nil, nil end end)

    function spell_ErrorList()
        local prLine = editor:LineFromPosition(editor.CurrentPos)
        local fLine = editor.FirstVisibleLine
        editor:DocumentEnd()
        editor:LineScroll(1, fLine)
        editor:GotoLine(prLine)
        bNeedList = true
        if CORE.BottomBarHidden() then CORE.BottomBarSwitch('NO') end
    end

    local function ListErrors()
        local count, lCount, line = 0, 0,-1
        local s, e = 0,- 1

        local iPos, nextStart = 0, 0
        local lineErrors = ""
        local out = ""
        while iPos < editor.TextLength do
            iPos = editor:IndicatorEnd(mark, nextStart)
            if iPos >= editor.TextLength or iPos == nextStart then break end

            nextStart = editor:IndicatorEnd(mark, iPos)
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

        for line = 0, findres.LineCount do
            local level = findres.FoldLevel[line]
            if ((level & SC_FOLDLEVELHEADERFLAG)~=0 and SC_FOLDLEVELBASE + 1 == (level & SC_FOLDLEVELNUMBERMASK))then
                findres.FoldExpanded[line] = nil
                local lineMaxSubord = findres:GetLastChild(line,-1)
                if line < lineMaxSubord then findres:HideLines(line + 1, lineMaxSubord) end
            end
        end

        findres:SetSel(0, 0)
        findres:ReplaceSel(out)
        if findres.LinesOnScreen == 0 then scite.MenuCommand(IDM_TOGGLEOUTPUT) end
        findres:SetSel(0, 0)
        findres:ReplaceSel('>Spell        Errors: '..count..' in '..lCount..' lines\n '..props["FilePath"]:from_utf8()..'\n')
    end

    local function OnIdle_local()
        if spellEnd then
            local mL = math.min(editor:LineFromPosition(spellStart) + 500, editor.LineCount - 1)

            local dP = editor:PositionFromLine(mL)

            if dP < 0 or dP >= spellEnd then dP = spellEnd end
            if (spellStartMin or spellStart + 1) <= spellStart and (spellEndMax or dP - 1) >= dP then return end
            if not bReset then
                if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then SpellRange = SpellRange1251 else SpellRange = SpellRangeUTF8 end
                bReset = true
            end
            dP = dP or spellEnd
            spellStartMin = math.min(spellStartMin or 0, spellStart)
            spellEndMax = math.max(spellEndMax or dP, dP)
            SpellLexer(spellStart, dP)
            spellStart = dP
            if editor.Length - 1 <= spellEnd then spelEnd = nil end
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
        local lst = {}     --65535 - максимально возможная кмманда

        local word = ProbabblyFromUT(editor:textrange(editor:IndicatorStart(mark, editor.CurrentPos), editor:IndicatorEnd(mark, editor.CurrentPos)))
        linda:send("_Spell", {cmd = "VARIANTS", word = word})
        local key, val = linda:receive(3.0, "_Spell_Variants")
        if val then
            for i = 1,  #val do
                table.insert(lst, {(val[i]):to_utf8(), action = function() ApplyVariant(val[i]) end})
            end
            if #val > 0 then end table.insert(lst,{'sSpell1', separator = 1})
        end

        return lst
    end

    local function SetMaxSize()
        local ret, sz =
        iup.GetParam("Max Size for AutouSpell",
            nil,
            _T'Characters'..' * 10 ^ %r[5,10,0.2]\n'
            ,
            (_G.iuprops['spell.maxsize'] or 7)
        )
        if ret then
            _G.iuprops['spell.maxsize'] = sz
        end
    end

    local function OnMenuCommand_local(msg, source)
        if msg < constFirstSpell then return end
        if msg == constAddToDic then str = cADDYODIC
        elseif msg == constWithExample then str = cADDBYZXAMPLE
        else str = tblVariants[msg] end
        OnUserListSelection_local(str)
    end

        AddEventHandler("OnColorized", OnColorise_local)
        AddEventHandler("OnOpen", function() OnSwitch_local() end)
        AddEventHandler("OnSwitchFile", function() spellStart = nil; spellEnd = nil; OnSwitch_local() end)
        AddEventHandler("OnIdle", OnIdle_local)
        AddEventHandler("OnBeforeOpen", function() spellStart = nil; spellEnd = nil end)

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
            {'Spelling Variants', plane = 1, scipfind = 1,
                visible = function() return editor:IndicatorValueAt(mark, editor.CurrentPos) == 1 end,
                bottom ={"Context Menu", }, {
                    {'list', plane = 1, FillVariantsMenu},
                    {cADDYODIC, action = function() ApplyVariant(cADDYODIC) end,},
                    {cADDBYZXAMPLE, action = function() ApplyVariant(cADDBYZXAMPLE) end,},
                    {'sSpell2', separator = 1},
            }}
        )
        menuhandler:InsertItem('MainWindowMenu', 'Tools|s1',
            {'Spelling', image = 'IMAGE_CheckSpelling',{
                {'Spell Check Automatically', action = ResetAutoSpell,
                    check = "tonumber(_G.iuprops['spell.autospell']) == 1 and (editor.Length < 10 ^(_G.iuprops['spell.maxsize'] or 7))",
                    active = 'editor.Length < 10 ^(_G.iuprops["spell.maxsize"] or 7)', key = 'Ctrl+Alt+F12',
                },
                {'s1', separator = 1,},
                {'Check Selection', action = spell_Selected, key = 'Ctrl+F12', image = 'IMAGE_CheckSpelling',},
                {'Check Selection Considering Highlight', action=spell_ByLex,},
                {'Show error list', action = spell_ErrorList, key = 'Ctrl+Shift+F12', image = 'report__exclamation_µ'},
                {'s1', separator = 1,},
                {'Maximum file size for auto spell check', action = SetMaxSize},
        }}, "hildim/ui/spell.html", _T
    )
    _G.g_session["spell.runned"] = true
end

function Init_status(h)
    Init()
    local zbox_s
    local function onSpellContext(_, but, pressed, x, y, status)
        if but == 51 and pressed == 0 then --right
            menuhandler:PopUp('MainWindowMenu|Tools|Spelling')
        end
    end
    local sTip = _T'Automatic spell check\n mode(Ctrl+Alt+F12)'
    zbox_s = iup.zbox{name = "Spelling_zbox",
        iup.button{image = 'IMAGE_CheckSpelling2';impress = 'IMAGE_CheckSpelling'; tip = sTip;canfocus = "NO";
            map_cb =(function(_) if _G.iuprops["spell.autospell"] == "1" then zbox_s.valuepos = 1 else zbox_s.valuepos = 0 end end);
            action =(function(_) _G.iuprops["spell.autospell"] = "1"; zbox_s.valuepos = 1 end);
            button_cb = onSpellContext;
        };
        iup.button{image = 'IMAGE_CheckSpelling';impress = 'IMAGE_CheckSpelling2'; tip = sTip;canfocus = "NO";
            action =(function(_) _G.iuprops["spell.autospell"] = "0"; zbox_s.valuepos = 0 end);
            button_cb = onSpellContext;
        };
    }
    return {
        handle = zbox_s
    }
end

return {
    title = _T'Spell checking',
    hidden = Init,
    code = 'spell',
    statusbar = Init_status,
    destroy = function() linda:send("_Spell", {cmd = "EXIT"}) CORE.FreeIndic(mark) end,
}
