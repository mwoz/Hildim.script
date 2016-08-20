require("LuaXml")

local _,_, h = editor:GetText():find('^(<%?[^\n]*%?>)')
xml.setIndent(editor.Indent)
-- debug_prnTb(xml.eval(editor:GetText()),1)
local strFrm = xml.eval(editor:GetText()):str()
if props['FileExt'] == 'form' then
    strFrm = strFrm:gsub('>%s+</form>', '></form>')
    strFrm = strFrm:gsub(' +<script', '<script')
    strFrm = strFrm:gsub(' +(</?string)', '%1')
    strFrm = strFrm:gsub(' +(</?value)', '    %1')
    strFrm = strFrm:gsub('>%s+<value><!%[CDATA%[', '><value><![CDATA[')
    strFrm = strFrm:gsub('%]%]></value>%s+<', ']]></value><')
elseif props['FileExt'] == 'cform' or props['FileExt'] == 'rform' then
    strFrm = strFrm:gsub(' +<Script', '<Script')
    strFrm = strFrm:gsub(' +<ConditionScript', '<ConditionScript')
    strFrm = strFrm:gsub(' +<Query', '<Query')
    strFrm = strFrm:gsub(' +(</?String)', '%1')
else
    strFrm = strFrm:gsub('>%s+</Field>', '></Field>')
end
editor:SetText(strFrm)
editor:SetSel(0, editor.Length)
if SORTFORMXML then SORTFORMXML.SortFormXML() end
editor:SetSel(0, 0)
if h then editor:ReplaceSel(h..'\r\n') end
