-- �������������� ����� ��������� ������ ����������� ������
-----------------------------------------------
--� ������� ����� ����� � ��� �������, � ������� �� ����� �� ������ ������ ����
local alltags = {
'code',
'name',
'caption',
'caption_ru',
'position',
'captionwidth',
'padleft',
'padleftctrl',
'padleftpx',
'padright',
'padrightctrl',
'padrightpx',
'padtop',
'padtopctrl',
'padtoppx',
'padbottom',
'padbottomctrl',
'padbottompx',
'fixedheight',
'fixedwidth',
'type',
'template',
'autowidth',
'contentheight',
'contentheightpx',
'contentname',
'contenttag',
'contentwidth',
'contentwidthpx',
'droppedsize',
'visible',
'enabled',
'locked',
'lockedmode',
'alignment',
'font',
'case',
'wordwrap',
'forecolor',
'backcolor',
'bordercolor',
'outercolor',
'hforecolor',
'datastyle',
'decimals',
'default',
'editenabled',
'autoprecision',
'format',
'formatting',
'groups',
'groupstyle',
'largenumber',
'maxlength',
'maxvalue',
'minvalue',
'mode',
'multiline',
'positiveonly',
'rootstyle',
'roundtype',
'showplus',
'showseconds',
'showtime',
'sorted',
'sorting',
'style',
'supportnulls',
'tabstop',
'text',
'title',
'tooltiptext',
'value',
'tag',
'$$$$'}

local alltagsmeta = {
-- TEMPLATE, TABLE, FIELD:
'code',
'name',
'type',
'sequence',
'asset',
'length',
'object',
'codeName',
'assetObjects',
'mandatory',
'default',
'permissionGet',
'permissionIUD',
-- TABLE only:
'movements',
-- TEMPLATE only:
'audit',
'realtimeNotify',
'importCallbacks',
'extensible',
'schemaVersion',
-- INDEX:
'nameSuffix',
'unique',
'key',
-- EXTERNALREF only:
'table',
'field',
-- DISPLAY only:
'caption',
'caption_ru',
'tooltip',
'tooltip_ru',
'$$$$'}

local tgControls={
'code',
'caption',
'caption_ru',
'type',
'source',
'position',
'positionPrevLine',
'choiceType',
'choiceMode',
'visible',
'locked',
'enabled',
'backColor',
'foreColor',
'format',
'font',
'alignment',
'padLeft',
'padRight',
'padTop',
'padBottom',
'autoWidth',
'fixedWidth',
'tooltip',
'rightButtonMode',
'showInfo',
'sizable',
'useCode',
'mandatory',
'paramType',
'valueColumn',
'displayColumns',
'$$$$'}

local tgColumns={
'code',
'caption',
'caption_ru',
'alignment',
'format',
'width',
'tooltip',
'tooltip_ru',
'sql',
'regexReplace',
'regexPattern',
'$$$$'}

require("LuaXml")

function SortXML(tags, fld, sText)
    local tblIndex = {} --������� � ��������� � �������� �������� � ������� � �������� ���� �����
	for i = 1, table.maxn(tags) do
		tblIndex[tags[i]] = i
	end
    local strtempl = '<('..fld..') ([^<]-)(%/?>)' --������ ��������� - ��������, ���� '/' �� ����������� ������ �� ������
    local wrdtempl = '([%w_]*)="([^"]*)"'
    local strout = sText:gsub(strtempl,function(s0,s1,s2)
        local tblTags = {}   --������ ���� ����� ����� � ��� �������, � ������� ��� ����� � ����
        local tblMaps = {}   --��������� �������� ����� � �������
        s1:gsub(wrdtempl,function(w1,w2)
                table.insert(tblTags,w1)
                tblMaps[w1] = w2
            end
        )
        table.sort(tblTags, function(e1,e2)  --����������� ������� �� �������
                local n1 = tblIndex[e1]
                local n2 = tblIndex[e2]
                if n1 == nil then n1 = 9999 end
                if n2 == nil then n2 = 9999 end
                if n1 == n2 then return e1<e2 end
                return n1 < n2
            end
        )
        local strOut = "<"..s0
        for j = 1,table.maxn(tblTags) do   --������� � ������ ��������������� ����
            local o1 = tblTags[j]
            local o2 = tblMaps[o1]
            strOut = strOut..' '..o1..'="'..o2..'"'
        end
        return strOut..s2
    end
    )
    return strout
end

function SortFormXML()
    local tbl
    local t_xml = xml.eval(editor:GetText())
    if t_xml then
        local strObjType = t_xml[0]
        if strObjType == "Template" then
            editor:ReplaceSel(SortXML(alltagsmeta, 'Display',SortXML(alltagsmeta, 'ExternalRef',(SortXML(alltagsmeta, 'Check',(SortXML(alltagsmeta, 'Index',(SortXML(alltagsmeta, 'Template',SortXML(alltagsmeta, 'Table', SortXML(alltagsmeta, 'Field', editor:GetSelText())))))))))))
        elseif strObjType == "template" then
            editor:ReplaceSel(SortXML(alltags, 'option', SortXML(alltags, 'control', editor:GetSelText())))
        elseif strObjType == "Form" then
            editor:ReplaceSel(SortXML(tgColumns, 'Column', SortXML(tgControls, 'Control', SortXML(tgControls, 'Container', editor:GetSelText()))))
        end
    end

end

function For2ThreeTabIndent()
    local sel_text = editor:GetSelText()
    if sel_text == '' then
        line_start = 0
        line_end = editor.LineCount-1
    else
        line_start = props["SelectionStartLine"] - 1
        line_end = props["SelectionEndLine"] - 2
    end
    local indent_char = nil
    editor:BeginUndoAction()
    for line_num = line_start, line_end do
        local line = editor:GetLine (line_num)
        if line ~= nil then
            local len = editor.LineIndentation[line_num]
            local newLen = math.floor(len/4)*3+len%4

            indent = string.rep (" ", newLen)
            editor.TargetStart = editor:PositionFromLine(line_num)
            editor.TargetEnd = editor.LineIndentPosition[line_num]
            editor:ReplaceTarget(indent)
        end
    end
    editor:EndUndoAction()
end
function NormaliseKeyWordsCase()
    local fCompVBS = function(i) return i==SCE_B_KEYWORD or i==SCE_B_CONSTANT end
    local fCaseVBS = function(str)
        str = str:lower()
        if str == 'elseif' then return 'ElseIf' end
        if str == 'executeglobal' then return 'ExecuteGlobal' end
        return string.upper(string.sub(str,1,1))..string.sub(str,2)
    end
    local fCompSQL = function(i) return i==SCE_MSSQL_STATEMENT or i==SCE_MSSQL_DATATYPE end
    local fCaseSQL = function(str) return string.lower(str) end
    local fCompVBS_FM = function(i) return i==SCE_FM_VB_KEYWORD or i==SCE_FM_VB_KEYWORD2 or i==SCE_FM_VB_OBJECTS end
    local fCompSQL_FM = function(i) return i==SCE_FM_SQL_STATEMENT or i==SCE_FM_SQL_DATATYPE end
    local fComp = nil
    local fCase
    if editor.Lexer  == SCLEX_FORMENJINE then
        local strSector = cmpobj_GetFMDefault()
        if strSector == SCE_FM_VB_DEFAULT then
            fComp = fCompVBS_FM
            fCase = fCaseVBS
        elseif strSector == SCE_FM_SQL_DEFAULT then
            fComp = fCompSQL_FM
            fCase = fCaseSQL
        end
    elseif editor.Lexer  == SCLEX_VB then
        fComp = fCompVBS
        fCase = fCaseVBS
    elseif  editor.Lexer  == SCLEX_MSSQL then
        fComp = fCompSQL
        fCase = fCaseSQL
    end
    if fComp==nil then
        print(editor.LexerLanguage..' not supported')
        return
    end
    local ss = editor.SelectionStart
    local es = editor.SelectionEnd
    local s0 = ss
    local strTemplate = '\\w+'
    local strFlag = SCFIND_WHOLEWORD+SCFIND_WORDSTART+SCFIND_REGEXP
    local wrdStart
    editor:BeginUndoAction()
    while ss < es do
        wrdStart, ss = editor:findtext(strTemplate,strFlag,ss,es)
        if wrdStart ~= nil then
            if fComp(editor.StyleAt[wrdStart + 1]) then
                editor:SetSel(wrdStart, ss)
                editor:ReplaceSel(fCase(editor:GetSelText()))
            end
        else
            ss=es
        end
    end
    editor:SetSel(s0,ss)
    editor:EndUndoAction()

end
require "menuhandler"
menuhandler:InsertItem('MainWindowMenu', 'Edit�Xml�l1',
    {'Sort Xml Tags In Node', ru='����������� ���� � ����', action=SortFormXML, key='Ctrl+Shift+S', image = 'tag__arrow_�',}
)
menuhandler:InsertItem('MainWindowMenu', 'Edit�l1',
    {'Set KeyWords To StandartCase', ru='�������� ����� � ����������� ����', action=NormaliseKeyWordsCase, key='Alt+Shift+L',}
)
