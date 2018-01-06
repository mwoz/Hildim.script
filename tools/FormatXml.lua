require("comhelper")

--:from_utf8():from_utf8()
local patt = '^(<%?[^\n]-%?>.-\n)'
--xml.setIndent(editor.Indent)
-- debug_prnTb(xml.eval(editor:GetText()),1)
local strFrm = editor:GetText()
local _, _, h = strFrm:find(patt)
strFrm = strFrm:gsub(patt, '')
--if h then strFrm = strFrm:gsub(patt, '') end
if props['FileExt'] == 'form' then
    local function clb(node, indent, prevIndent)
        if node.nodeTypeString == 'element' and node.nodeName == 'value' and not node.firstChild then
            return prevIndent..'    '
        elseif node.nodeTypeString == 'element' and node.previousSibling then
            if node.nodeName == 'frame' and node.previousSibling.nodeTypeString == 'element' and node.previousSibling.nodeName == 'frame' then
                return '\r\n'..indent
            elseif node.nodeName == 'string' and node.previousSibling.nodeTypeString == 'element' and node.previousSibling.nodeName == 'string' then
                return '\r\n'..indent
            elseif node.nodeName == 'control' and node.previousSibling.nodeTypeString == 'element' and node.previousSibling.nodeName == 'control' then
                local _, _, p1 = (node:getAttribute('position') or (';;;')):find('%d*;(%d*)')
                local _, _, p2 = (node.previousSibling:getAttribute('position') or (';;;')):find('%d*;(%d*)')
                p1 = tonumber(p1 or -10) or -10
                p2 = tonumber(p2 or - 10) or - 10
                if p1 - p2 > 10 or p2 - p1 > 10 then return '\r\n'..indent end
            elseif node.nodeName == 'option' then
                local p = node.previousSibling
                while p do
                    if p.nodeTypeString == 'text' and p.text:find('#INCLUDE(', 1, true) then
                        return indent..'    '
                    end
                    p = p.previousSibling
                end
            end
        end
        return indent
    end
    strFrm = comhelper.FormatXml(strFrm, 4,
    'string,stringtable,script,form,template,value',
    ',,,', 'form', clb)

    strFrm = strFrm:gsub('>%s+</form>', '></form>')

    strFrm = strFrm:gsub('%]%]>%s+</', ']]></')
    strFrm = strFrm:gsub('>%s+<value><!%[CDATA%[', '><value><![CDATA[')
    strFrm = strFrm:gsub('%]%]></value>%s+<', ']]></value><')


elseif props['FileExt'] == 'cform' or props['FileExt'] == 'rform' or props['FileExt'] == 'wform' then
    local function clb(node, indent, prevIndent)
        if node.nodeTypeString == 'element' and node.parentNode and node.nodeName == 'Script' and node.parentNode.nodeName ~= 'Form' then
           return prevIndent..'    '
        end
        return indent
    end
    strFrm = comhelper.FormatXml(strFrm, 4, 'StringTable,Script,Commands,Design,Columns,Styles,Blotters,ObjectBinds', ',,,', ',,,', clb)
    strFrm = strFrm:gsub('%]%]>%s+</', ']]></')
    strFrm = strFrm:gsub('>%s+<!%[CDATA%[', '><![CDATA[')

else
    strFrm = comhelper.FormatXml(strFrm, 3, ',,,', ',,,', ',,,', nil)
    strFrm = strFrm:gsub('>%s+</Field>', '></Field>')
end

editor:SetSel(0, editor.Length)
if h then strFrm = h..strFrm end
--editor:SetText(strFrm)
editor:ReplaceSel(strFrm)
editor:SetSel(0, editor.Length)

editor:SetSel(0, 0)
