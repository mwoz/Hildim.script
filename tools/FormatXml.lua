require("LuaXml")
-- local ttt = xml.eval(editor:GetText())
-- local yy = ttt:find('Choice_Id').ttt
-- print(yy, 123)
xml.setIndent(editor.Indent)
editor:SetText(xml.eval(editor:GetText()):str():gsub('>%s+</Field>', '></Field>'))
editor:SetSel(0, editor.Length)
SortFormXML()
