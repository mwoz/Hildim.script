require("LuaXml")
-- local ttt = xml.eval(editor:GetText())
-- local yy = ttt:find('Choice_Id').ttt
-- print(yy, 123)

editor:SetText(xml.eval(editor:GetText()):str())
