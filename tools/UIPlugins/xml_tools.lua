--[[--------------------------------------------------
Paired Tags (логическое продолжение скриптов highlighting_paired_tags.lua и HTMLFormatPainter.lua)
Version: 2.5.0
Author: mozers™, VladVRO, TymurGubayev, nail333
------------------------------
Подсветка парных и непарных тегов в HTML и XML
В файле настроек задается цвет подсветки парных и непарных тегов

Скрипт позволяет копировать и удалять (текущие подсвеченные) теги, а также
вставлять в нужное место ранее скопированные (обрамляя тегами выделенный текст)

Внимание:
В скрипте используются функции из COMMON.lua (EditorMarkText, EditorClearMarks)

--]]----------------------------------------------------
local function Init()
    XMLTOOLS = {}
    local t = {}
    local pathXSLT, pathXSD, firstTag
    local oXSLProc, oXSD
    local mBScipExt = false
    -- t.tag_start, t.tag_end, t.paired_start, t.paired_end  -- positions
    -- t.begin, t.finish  -- contents of tags (when copying)
    local old_current_pos
    local blue_indic = CORE.InidcFactory('XmlTools.ok', _T'XML - Paired Tags - Found', INDIC_BOX, 4834854, 0) -- номера используемых маркеров
    local red_indic = CORE.InidcFactory('XmlTools.Error', _T'XML - Paired Tags - Error', INDIC_STRIKE, 13311, 0)
    local xpath_indic = CORE.InidcFactory('XmlTools.XPath', 'Xml - Xpath', INDIC_ROUNDBOX, 14538301, 50)

    local bEnable, styleSpace, styleBracket, styleBracketClose = false, 0, 1, 11

    local function CopyTags()
        if not t.tag_start then
            print("Error : "..scite.GetTranslation("Move the cursor on a tag to copy it!"))
            return
        end
        local tag = editor:textrange(t.tag_start, t.tag_end + 1)
        if t.paired_start then
            local paired = editor:textrange(t.paired_start, t.paired_end + 1)
            if t.tag_start < t.paired_start then
                t.begin = tag
                t.finish = paired
            else
                t.begin = paired
                t.finish = tag
            end
        else
            t.begin = tag
            t.finish = nil
        end
    end

    local function PasteTags()
        if t.begin then
            if t.finish then
                local sel_text = editor:GetSelText()
                editor:ReplaceSel(t.begin..sel_text..t.finish)
                if sel_text == '' then
                    editor:GotoPos(editor.CurrentPos - #t.finish)
                end
            else
                editor:ReplaceSel(t.begin)
            end
        end
    end

    local function DeleteTags()
        if t.tag_start then
            editor:BeginUndoAction()
            if t.paired_start~= nil then
                if t.tag_start < t.paired_start then
                    editor:SetSel(t.paired_start, t.paired_end + 1)
                    editor:DeleteBack()
                    editor:SetSel(t.tag_start, t.tag_end + 1)
                    editor:DeleteBack()
                else
                    editor:SetSel(t.tag_start, t.tag_end + 1)
                    editor:DeleteBack()
                    editor:SetSel(t.paired_start, t.paired_end + 1)
                    editor:DeleteBack()
                end
            else
                editor:SetSel(t.tag_start, t.tag_end + 1)
                editor:DeleteBack()
            end
            editor:EndUndoAction()
        else
            print("Error : "..scite.GetTranslation("Move the cursor on a tag to delete it!"))
        end
    end

    local function GotoPairedTag()
        if t.paired_start then -- the paired tag found
            editor:GotoPos(t.paired_start + 1)
        end
    end

    local function SelectWithTags()
        if t.tag_start and t.paired_start then -- the paired tag found
            if t.tag_start < t.paired_start then
                editor:SetSel(t.paired_end + 1, t.tag_start)
            else
                editor:SetSel(t.tag_end + 1, t.paired_start)
            end
        end
    end

    local function GetLineMap(ltst)
        local isTag = false
        local tagStart
        local delta = 0
        for i = 0, editor.Length - 1 do
            if isTag then
                if editor.CharAt[i] == 62 and (editor.StyleAt[i] == 1 or editor.StyleAt[i] == 11) then -->
                    delta = delta + (editor:LineFromPosition(i) - tagStart)
                    isTag = false
                end
            else
                if editor.CharAt[i] == 60 and editor.StyleAt[i] == 1 then --<
                    tagStart = editor:LineFromPosition(i)
                    isTag = true
                elseif editor:LineFromPosition(i) + delta >= ltst then
                    return ltst + delta
                end
            end
        end
        return ltst+ delta
    end

    local function highlighting_paired_tags_switch()
        local prop_name = 'hypertext.highlighting.paired.tags'
        props[prop_name] = 1 - tonumber(props[prop_name])
        EditorClearMarks(blue_indic)
        EditorClearMarks(red_indic)
    end

    local function FindPairedTag(tag)
        local count = 1
        local find_start, find_end, dec

        if editor.CharAt[t.tag_start + 1] ~= 47 then -- [/]
            -- поиск вперед (закрывающего тега)
            find_start = t.tag_start + 1
            find_end = editor.Length
            dec = -1
        else
            -- поиск назад (открывающего тега)
            find_start = t.tag_start
            find_end = 0
            dec = 1
        end
        repeat
            local paired_start, paired_end = editor:findtext("</?"..tag.."[ >]", SCFIND_REGEXP, find_start, find_end)
            if paired_end and editor.CharAt[paired_end - 1] ~= 62 then
                if dec == -1 then
                    _, paired_end = editor:findtext(".*?>", SCFIND_REGEXP, paired_end, find_end)
                else
                    _, paired_end = editor:findtext(".*?>", SCFIND_REGEXP, paired_end, find_start)
                end
            end
            if not paired_end or not paired_end then return end
            if paired_end and editor.CharAt[paired_end - 2] ~= 47 then
                if not paired_start then break end
                if editor.CharAt[paired_start + 1] == 47 then -- [/]
                    count = count + dec
                else
                    count = count - dec
                end
                if count == 0 then
                    t.paired_start = paired_start
                    t.paired_end = paired_end - 1
                    break
                end
            end
            find_start = (dec == 1) and paired_start or paired_end
        until false
    end

    local function PairedTagsFinder()
        if styleSpace == 49 and cmpobj_GetFMDefault() ~= SCE_FM_X_DEFAULT then return end
        local current_pos = editor.CurrentPos
        if current_pos == old_current_pos then return end
        old_current_pos = current_pos
        local tag_start = editor:findtext("[<>]", SCFIND_REGEXP, current_pos, 0)

        if tag_start == nil
            or editor.CharAt[tag_start] ~= 60 -- [<]
            or editor.CharAt[tag_start + 1] == 63 --[?]
            or (editor.StyleAt[tag_start] ~= styleBracket and editor.StyleAt[tag_start] ~= styleBracket )
            then
            t.tag_start = nil
            t.tag_end = nil
            EditorClearMarks(blue_indic)
            EditorClearMarks(red_indic)
            return
        end
        if tag_start == t.tag_start then return end
        t.tag_start = tag_start

        local tag_end = editor:findtext("[<>]", SCFIND_REGEXP, current_pos, editor.Length)
        if tag_end == nil
            or editor.CharAt[tag_end] ~= 62 -- [>]
            or editor.CharAt[tag_end - 1] == 47 -- [/]
            then
            if editor.CharAt[tag_end - 1] then EditorClearMarks(red_indic); EditorClearMarks(blue_indic) end
            return
        end

        t.tag_end = tag_end

        t.paired_start = nil
        t.paired_end = nil
        if editor.CharAt[t.tag_end - 1] ~= 47 then -- не ищем парные теги для закрытых тегов, типа <BR >
            local tag = editor:textrange(editor:findtext("[\\w\\.:]+", SCFIND_REGEXP, t.tag_start, t.tag_end))
            FindPairedTag(tag)
        end

        EditorClearMarks(blue_indic)
        EditorClearMarks(red_indic)

        if t.paired_start then
            -- paint in Blue
            EditorMarkText(t.tag_start + 1, t.tag_end - t.tag_start - 1, blue_indic)
            EditorMarkText(t.paired_start + 1, t.paired_end - t.paired_start - 1, blue_indic)
        else
            if props["indic.style."..red_indic] ~= '' then
                -- paint in Red
                EditorMarkText(t.tag_start + 1, t.tag_end - t.tag_start - 1, red_indic)
            end
        end
    end

    local function fillPositionTree(tPos)
        local p = tPos.TagStart

        while (editor.CharAt[p] ~= 32 and editor.CharAt[p] ~= 62  and editor.CharAt[p] ~= 47 ) and p <= editor.Length do p = p + 1 end -- [ ][>][/]
        if p == tPos.TagStart then return end
        --tPos.T = editor:textrange(tPos.TagStart, p)  --for debug
        tPos.nameEnd = p
        while (editor.CharAt[p] ~= 62 or (editor.StyleAt[p] ~= styleBracket and editor.StyleAt[p] ~= styleBracketClose)) --[[and p <= editor.Length]]  do p = p + 1 end -- [>]

        if editor.CharAt[p - 1] == 47 then -- [/]
            tPos.TagEnd = p + 1
            return
        end

        while p and p <= editor.Length do
            while (editor.CharAt[p] ~= 60 or editor.StyleAt[p] ~= styleBracket or  -- [<]
                editor.CharAt[p + 1] == 63) and p <= editor.Length do p = p + 1 end --[?]
            if editor.CharAt[p + 1] == 47 then -- [/]
                while (editor.CharAt[p] ~= 62) and p <= editor.Length do p = p + 1 end -- [>]
                tPos.TagEnd = p + 1
                return
            end
            local tChild = {TagStart = p}
            fillPositionTree(tChild)
            if tChild.nameEnd then
                table.insert(tPos, tChild)
                p = tChild.TagEnd
            else
                p = nil
            end
        end
    end

    local function getPositionXML()
        local ss, se, fl = editor.SelectionStart, editor.SelectionEnd, editor.FirstVisibleLine
        editor:DocumentEnd()
        editor.SelectionStart, editor.SelectionEnd, editor.FirstVisibleLine = ss, se, fl
        local tPos = {}
        local p = 0
        while (editor.CharAt[p] ~= 60 or editor.StyleAt[p] ~= styleBracket or
            editor.CharAt[p + 1] == 63) and p <= editor.Length do p = p + 1 end
        tPos.TagStart = p
        fillPositionTree(tPos)
        local tOut = {}

        local function readWithPos(tP, pos)
            table.insert(tOut, (editor:textrange(pos, tP.nameEnd) or '!!!')..' __start="'..(tP.TagStart or'?')..'" __end="'..(tP.TagEnd or '???')..'" ')
            pos = tP.nameEnd
            for i = 1,  #tP do
                pos = readWithPos(tP[i], pos)
            end
            table.insert(tOut, (editor:textrange(pos, tP.TagEnd) or '!!!'))
            return tP.TagEnd
        end

        readWithPos(tPos, 0)
        return table.concat(tOut, '')
    end

    local function XPath()
        local dlg = _G.dialogs["xpathfind"]
        if dlg == nil then
            local txt_search = iup.text{size = '350x0'}

            local btn_ok = iup.button{title = "Test"}
            local radio_single = iup.radio{iup.hbox{iup.toggle{title = 'SelectSingleNode', name = 'Single'}, iup.toggle{title = 'SelectNodes', name = 'All'}, } }
            local chk_higl = iup.toggle{title = _T'Highlight', value = 'ON'}

            iup.SetHandle("XPATH_BTN_OK", btn_ok)
            local btn_esc = iup.button  {title = "Cancel"}
            iup.SetHandle("XPATH_BTN_ESC", btn_esc)

            local vbox = iup.vbox{ iup.hbox{
                iup.label{title = "XPath:", gap = 3}, txt_search, iup.fill{}, alignment = 'ACENTER'},
                iup.hbox{radio_single, iup.fill{}, chk_higl},
                iup.hbox{btn_ok, iup.button{title = "Clear", action = function()EditorClearMarks(xpath_indic) end }, iup.fill{}, btn_esc},
            gap = 2, margin = "4x4" }

            local result = false
            dlg = iup.scitedialog{vbox; title = "XPath", defaultenter = "XPATH_BTN_OK", defaultesc = "XPATH_BTN_ESC", maxbox = "NO", minbox = "NO", resize = "NO", sciteparent = "SCITE", sciteid = "xpathfind" }

            function dlg:show_cb(h, state)
                if state == 0 then
                    txt_search.value = ''
                end
            end

            function btn_ok:action()
                EditorClearMarks(xpath_indic)
                local function selectInText(xml)
                    if xml.nodeType == 2 then print(_T'Can not highlight attribute'); return end

                    while xml and xml.nodeType ~= 1 do xml = xml.parentNode end
                    local s, e = (math.tointeger(xml:getAttribute('__start')) or 0), (math.tointeger(xml:getAttribute('__end')) or 0 )
                    EditorMarkText(s, e - s, xpath_indic)
                end

                local xml = luacom.CreateObject("MSXML.DOMDocument")
                local strXml = editor:GetText()
                if not xml:loadXml(strXml) then
                    local xmlErr = xml.parseError
                    print(xmlErr.line, xmlErr.linepos, xmlErr.reason)
                    return
                end
                if chk_higl.value == 'ON' then
                    xml = luacom.CreateObject("MSXML.DOMDocument")
                    xml:setProperty('SelectionLanguage', 'XPath')
                    strXml = getPositionXML()
                    if not xml:loadXml(strXml) then
                        local xmlErr = xml.parseError
                        print(xmlErr.line, xmlErr.linepos, xmlErr.reason)
                        return
                    end
                    if radio_single.value.name == 'All' then
                        local bOk, msg = pcall(function() return xml:selectNodes(txt_search.value) end)
                        if not bOk then
                            print(msg)
                            return
                        end
                        for i = 0, msg.length - 1 do
                            selectInText(msg:item(i))
                        end

                    else
                        local bOk, msg = pcall(function() return xml:selectSingleNode(txt_search.value) end)
                        if not bOk then
                            print(msg)
                            return
                        end
                        if msg == nil then
                            print('Not Found')
                        else
                            selectInText(msg)
                        end
                    end
                else
                    if radio_single.value.name == 'All' then
                        local bOk, msg = pcall(function() return xml:selectNodes(txt_search.value) end)
                        if not bOk then
                            print(msg)
                            return
                        end
                        for i = 0, msg.length - 1 do
                            print(msg:item(i).xml)
                        end

                    else
                        local bOk, msg = pcall(function() return xml:selectSingleNode(txt_search.value) end)
                        if not bOk then
                            print(msg)
                            return
                        end
                        if msg == nil then
                            print('Not Found')
                        else
                            print(msg.xml)
                        end
                    end
                end

            end

            function btn_esc:action()
                print(radio_single.value.name)
                dlg:hide()
            end
        else
            dlg:show()
        end
    end

    local srcXsd, pathXsd = 0, ''
    local function Xsd()
        local ret, src1, path1 = iup.GetParam("Test Xsd",
            function(h, id)
                local bSE = scite.buffers.SecondEditorActive() == 1
                if not bSE then iup.GetParamParam(h, 0).control.value = 'ON'; iup.GetParamParam(h, 0).value = '0' end
                local bact = Iif(iup.GetParamParam(h, 0).value == '0', 'YES', 'NO')
                iup.GetParamParam(h, 1).control.active = bact
                iup.GetParamParam(h, 1).auxcontrol.active = bact
                if id == iup.GETPARAM_BUTTON1 and iup.GetParamParam(h, 0).value == '0' and iup.GetParamParam(h, 1).value == '' then
                    print('File not selected')
                    return 0
                end
                return 1
            end,
            _T'Sourse%o|File|Anoter View|'..'\n'..
            _T'Source File'..'%f\n'
            ,
            srcXsd,
            pathXsd
        )
        if ret then
            srcXsd, pathXsd = src1, path1

            scite.MenuCommand(IDM_SAVE)
            local xmlSrc = luacom.CreateObject("MSXML.DOMDocument")
            if not xmlSrc:loadXml(editor:GetText()) then
                local xmlErr = xmlSrc.parseError
                print(GetLineMap(xmlErr.line), xmlErr.linepos, xmlErr.reason)
                return
            end

            local xmldoc = luacom.CreateObject("Msxml2.FreeThreadedDOMDocument.6.0")
            local SchemaCache = luacom.CreateObject("Msxml2.XMLSchemaCache.6.0")

            bOk, msg = pcall(function() SchemaCache:add("", props['FilePath']) end)
            if not bOk then
                print(msg)
                return
            end
            xmldoc.schemas = SchemaCache;

            local txt

            if srcXsd == 1 then
                txt = coeditor:GetText()
            else
                local f = io.open(pathXsd)
                if f then
                    txt = f:read()
                    f:close()
                else
                    print("Can't open file "..pathXsd)
                end
            end

            if not xmldoc:loadXml(txt) then
                local path = pathXsd
                if srcXsd == 1 then
                    local tabR = iup.GetDialogChild(iup.GetLayout(), 'TabCtrlRight')
                    path = scite.buffers.NameAt(math.tointeger(iup.GetAttribute(tabR, "TABBUFFERID"..iup.GetAttribute(tabR, "VALUEPOS"))) or 0)
                end
                print(path..':'..GetLineMap(xmldoc.parseError.line)..':'..xmldoc.parseError.linepos, xmldoc.parseError.reason)
            else
                print('OK')
            end
        end
    end

    local src, path, out = 0, '', 0

    local function processXsd(txtXml, pathXsd)

        if not oXSD then
            local txtXsd
            local f = io.open(pathXsd)
            if f then
                txtXsd = f:read('*a')
                f:close()
            else
                print("Can't open file "..pathXsd)
                return
            end
            XMLTOOLS.SetObjects(txtXsd, nil)
        end

        -- local xmlSrc = luacom.CreateObject("MSXML.DOMDocument")
        -- if not xmlSrc:loadXml(txtXml) then
        --     local xmlErr = xmlSrc.parseError
        --     print(xmlErr.line, xmlErr.linepos, xmlErr.reason)
        --     return
        -- end

        local xmldoc = luacom.CreateObject("Msxml2.FreeThreadedDOMDocument.6.0")
        local SchemaCache = luacom.CreateObject("Msxml2.XMLSchemaCache.6.0")

        bOk, msg = pcall(function() SchemaCache:add("", oXSD) end)
        -- bOk, msg = pcall(function() SchemaCache:add("", pathXsd) end)
        if not bOk then
            print(msg)
            return
        end
        xmldoc.schemas = SchemaCache;
        if not xmldoc:loadXml(txtXml) then
            local p = 0
            for i = 1, xmldoc.parseError.line do
                p = txtXml:find('\n', p + 1)
            end
            --p = p + xmldoc.parseError.linepos
   -- print(txtXml:sub(1, p))
            p = txtXml:sub(1, p):gsub('[^<]', ''):len()
            local pf = 0
            local i = 1

            while true do
                if i == p then break end
                i = i + 1
                _, pf = editor:findtext("<", 0, pf, editor.Length)
                -- print(pf, editor:textrange(pf, pf + 7))
                if pf == editor:findtext("![CDATA[", 0, pf, editor.Length) then
                    i = i - 1
                    _, pf = editor:findtext("]]>", 0, pf, editor.Length)
                end
            end

            local errTxt = xmldoc.parseError.reason
            if errTxt:find('"__ERROR_XSL"') then
                _, _, errTxt = xmldoc.parseError.srcText:find('__ERROR_XSL="([^"]*)"')
            end
            -- return GetLineMap(xmldoc.parseError.line - 1), xmldoc.parseError.linepos, errTxt;
            return editor:LineFromPosition(pf) + 1, xmldoc.parseError.linepos, errTxt;
        else
            return nil
        end
    end

    local function processXslt(txtXml)

        local xmlSrc = luacom.CreateObject("MSXML.DOMDocument")

        if not xmlSrc:loadXml(txtXml) then
            local xmlErr = xmlSrc.parseError
            print(props['FilePath']..':'..xmlErr.line..':'..xmlErr.linepos, xmlErr.reason)
            return
        end

        oXSLProc.input = xmlSrc
        oXSLProc:transform()
        return oXSLProc.output
    end

    local function Xslt()
        local ret, src1, path1, out1 = iup.GetParam("Test Xslt",
            function(h, id)
                local bSE = scite.buffers.SecondEditorActive() == 1
                if not bSE then iup.GetParamParam(h, 0).control.value = 'ON'; iup.GetParamParam(h, 0).value = '0' end
                local bact = Iif(iup.GetParamParam(h, 0).value == '0', 'YES', 'NO')
                iup.GetParamParam(h, 1).control.active = bact
                iup.GetParamParam(h, 1).auxcontrol.active = bact
                if id == iup.GETPARAM_BUTTON1 and iup.GetParamParam(h, 0).value == '0' and iup.GetParamParam(h, 1).value == '' then
                    print('File not selected')
                    return 0
                end
                return 1
            end,
            _T'Source%o|File|Another View|'..'\n'..
            _T'Source File'..'%f\n'..
            _T'Output%o|Log|New Window|'..'\n'
            ,
            src,
            path,
            out
        )
        if ret then
            src, path, out = src1, path1, out1
            local xslt = luacom.CreateObject("Msxml2.FreeThreadedDOMDocument")
            xslt.async = false
            if not xslt:loadXml(editor:GetText()) then
                local xmlErr = xslt.parseError
                print(xmlErr.line, xmlErr.linepos, xmlErr.reason)
                return
            end
            local xsl = luacom.CreateObject("Msxml2.XSLTemplate")
            xsl.styleSheet = xslt
            local xslProc = xsl:createProcessor()
            local txt

            if src == 1 then
                txt = coeditor:GetText()
            else
                local f = io.open(path)
                if f then
                    txt = f:read()
                    f:close()
                else
                    print("Can't open file "..path)
                end
            end
            local xmlSrc = luacom.CreateObject("MSXML.DOMDocument")

            if not xmlSrc:loadXml(txt) then
                local xmlErr = xmlSrc.parseError
                print(xmlErr.line, xmlErr.linepos, xmlErr.reason)
                return
            end

            xslProc.input = xmlSrc
            xslProc:transform()
            if out == 0 then
                print(xslProc.output)
            else
                local strOut = '^Output.xml'
                if src == 0 then
                    _, _, strOut = path:find('([^\\]*)$')
                    strOut = '^'..(strOut or 'Output.xml')
                else
                end
                props['scite.new.file'] = strOut --..msgReplay:GetPathValue("FileName")
                scite.MenuCommand(IDM_NEW)
                CORE.SetText(xslProc.output)
            end
        end

    end

    local function CloseTag(nUnbodyScipped, bFromGlobal)
        local pos = editor.CurrentPos
        if (editor.StyleAt[pos] == styleSpace or editor.StyleAt[pos - 1] == styleSpace) or bFromGlobal or
            (editor.StyleAt[pos] == styleBracket and editor.CharAt[pos - 1] == 62 and editor.CharAt[pos] == 60)
            then
            local tg_end, find_start = nil, pos
            repeat
                find_start = editor:findtext("<[\\w\\.:]+", SCFIND_REGEXP, find_start, 0)
                if not find_start then break end

                local tag_end = editor:findtext("[<>]", SCFIND_REGEXP, find_start + 1, editor.Length)

                if not(tag_end == nil or editor.CharAt[tag_end] ~= 62) then -- [>]
                    t.tag_start = find_start
                    t.tag_end = tag_end
                    t.paired_start = nil
                    t.paired_end = nil
                    local tag = editor:textrange(editor:findtext("[\\w\\.:]+", SCFIND_REGEXP, t.tag_start, t.tag_end))
                    if not tag then break end
                    if editor.CharAt[tag_end - 1] == 47 then -- [/]
                        nUnbodyScipped = nUnbodyScipped - 1
                        if nUnbodyScipped == 0 then
                            editor:BeginUndoAction()
                            editor:ReplaceSel('</'..tag..'>')
                            editor:SetSel(tag_end - 1, tag_end)
                            editor:ReplaceSel('')
                            editor:SetSel(pos - 1, pos - 1)
                            editor:EndUndoAction()
                            break
                        end
                    else
                        FindPairedTag(tag)
                        if not t.paired_start then
                            editor:ReplaceSel('</'..tag..'>')
                            scite.RunAsync(Format_Block)
                            return
                        end
                        if t.paired_start > pos then
                            if iup.Alarm(_T"Xml Tools", _FMT(_T"Tag '%1' (line %2)  is already closed\non the line %3. Close anyway?",
                                tag, editor:LineFromPosition(find_start) + 1, editor:LineFromPosition(t.paired_start) + 1), _TH'Yes', _TH'No') == 1 then
                                editor:ReplaceSel('</'..tag..'>')
                                scite.RunAsync(Format_Block)
                            elseif bFromGlobal then
                                editor:ReplaceSel('</')
                            end
                            break
                        end
                    end
                end
            until false
        end
    end

    local function OnSwitchFile_local()
        if editor.Lexer == SCLEX_FORMENJINE then
            bEnable, styleSpace, styleBracket, styleBracketClose = true, 49, 50, 50
        elseif editor.Lexer == SCLEX_XML then
            bEnable, styleSpace, styleBracket, styleBracketClose = true, 0, 1, 11
        else
            bEnable = false
        end
    end

    local function CloseIncompleteTag()
        CloseTag(0)
    end

    local function CloseUnbodyTag()
        -- iup.GetParam("sdfsd",(function(h, ind) print((iup.GetParamParam(h,0)).value); return 1 end), "Tag%i[1,100,1]{}\n", 1)
        CloseTag(1)
    end

    function XMLTOOLS.CloseTag()
        CloseTag(0, true)
    end

    local function CheckInternal(txtXml)
        local bCheck = true
        if firstTag then
            local s, e = editor:findtext("<\\w+", SCFIND_REGEXP)
            bCheck = editor:textrange(s, e) == '<'..firstTag
        end
        if not bCheck or XMLTOOLS.blockXsdTest then return comhelper.CheckXml(txtXml) end

        if not txtXml then txtXml = editor:GetText() end

        if pathXSLT then
            if not oXSLProc then
                local txtXslt
                local f = io.open(pathXSLT)
                if f then
                    txtXslt = f:read('*a')
                    f:close()
                else
                    print("Can't open file "..pathXSLT)
                    return
                end
                XMLTOOLS.SetObjects(nil, txtXslt)
            end

            txtXml = processXslt(txtXml)
            if not txtXml then return -2 end
        end
        -- txtXml = (txtXml or ''):gsub('>%s+</Field_', '></Field_')

        return processXsd(txtXml, pathXSD)
    end

    local function CheckCurrent()
        local line, linepos, reason = CheckInternal()
        if line then
            if line > 0 then print(props['FilePath']..':'..line..':'..linepos, reason) end
        else
            print(props['FilePath']..': OK')
        end
    end

    function XMLTOOLS.SetPathes(xsd, xsl, tag)
        local rez = (pathXSD ~= xsd) or (pathXSLT ~= xsl)
        pathXSD = xsd
        pathXSLT = xsl
        firstTag = tag
        if rez then
            oXSD = nil
            oXSLProc = nil
        end
        return rez
    end

    function XMLTOOLS.SetObjects(xsd, xsl, bExt)
        if bExt and mBScipExt then return end

        if xsd then
            oXSD = luacom.CreateObject("MSXML2.DOMDocument.6.0")
            if not oXSD:loadXml(xsd) then
                local xmlErr = oXSD.parseError
                print('Error when load xsd', xmlErr.line, xmlErr.linepos, xmlErr.reason)
                return
            end
        end
        if xsl then
            local oXSL = luacom.CreateObject("Msxml2.FreeThreadedDOMDocument")
            oXSL.async = false
            if not oXSL:loadXml(xsl) then
                local xmlErr = oXSL.parseError
                print('Error when load xsl', xmlErr.line, xmlErr.linepos, xmlErr.reason)
                return
            end
            local xsl = luacom.CreateObject("Msxml2.XSLTemplate")
            xsl.styleSheet = oXSL
            oXSLProc = xsl:createProcessor()

        end
    end

    function XMLTOOLS.CheckXml(strXml)
        if pathXSD then return CheckInternal(strXml) end
        return comhelper.CheckXml(strXml)
    end

    AddEventHandler("OnUpdateUI", function()
        if bEnable and (tonumber(_G.iuprops['pariedtag.on']) == 1) then PairedTagsFinder() end
    end)
    AddEventHandler("OnSwitchFile", OnSwitchFile_local)
    AddEventHandler("OnOpen", OnSwitchFile_local)

    require "menuhandler"
    menuhandler:InsertItem('MainWindowMenu', 'Edit|Xml|l1',{'Xml', plane = 1,{
            {'Close Incomplete Tag', action = CloseIncompleteTag, key = 'Ctrl+>', image = 'node_insert_µ',},
            {'Convert Single Tag into Double', action = CloseUnbodyTag, key = 'Ctrl+Shift+>', image = 'node_insert_next_µ',},
        }}, nil, _T
    )

    local function isXsd()
        local fs = seacher{
            wholeWord = false
            , matchCase = false
            , wrapFind = true
            , backslash = false
            , regExp = true
            , style = nil
            , searchUp = false
            , replaceWhat = ''
            , findWhat = "xmlns.*=.*http://www\\.w3\\.org/2001/XMLSchema"
        }
        return fs:Count() > 0
    end
    local function isXslt()
        local fs = seacher{
            wholeWord = false
            , matchCase = false
            , wrapFind = true
            , backslash = false
            , regExp = true
            , style = nil
            , searchUp = false
            , replaceWhat = ''
            , findWhat = "xmlns.*=.*http://www\\.w3\\.org/1999/XSL/Transform"
        }
        return fs:Count() > 0
    end
    menuhandler:InsertItem('MainWindowMenu', 'Tools|s2',{'Xml',
        visible = function() return editor.LexerLanguage == 'xml' or editor.LexerLanguage == 'formenjine' end, {
            {'Tags Highlighting', check_iuprops = 'pariedtag.on'},
            {'Block XSD Scheme Validation', action = function() XMLTOOLS.blockXsdTest = not XMLTOOLS.blockXsdTest end, check = function() return XMLTOOLS.blockXsdTest end },
            {'s1', separator = 1},
            {'Test XPATH expression', action = XPath, },
            {'Test XSLT Template', action = Xslt, active = isXslt},
            {'Test XSD Scheme', action = Xsd, active = isXsd },
            {'XSD Scheme Validation', action = CheckCurrent, },
            {'s1', separator = 1},
            {'Use Local Schemes', check = function() return mBScipExt end, action = function()
                oXSD = nil
                oXSLProc = nil
                mBScipExt = not mBScipExt
                OnSwitchFile()
            end, },
        }}, nil, _T
    )


end

return {
    title = 'Инструменты XML',
    hidden = Init,
}
