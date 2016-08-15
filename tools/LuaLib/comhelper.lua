
local s = {}

require "luacom"

function s.CheckScript(strScript, bVbs)
    local oScr = luacom.CreateObject('MSScriptControl.ScriptControl')
    oScr.Language = Iif(bVbs, 'VBScript', 'JScript')
    oScr.AllowUI = true
    luacom.SkipCheckError(oScr)
    oScr:AddCode(strScript)
    if oScr.Error.Number == 0 then return end
    return oScr.Error.Line , oScr.Error.Column , oScr.Error.Description:from_utf8(1251)
end

function s.CheckXml(strXml)
    local xml = luacom.CreateObject("MSXML.DOMDocument")
    if not strXml then strXml = editor:GetText() end
    strXml = strXml:to_utf8(1251)
    if not xml:loadXml(strXml) then
        local xmlErr = xml.parseError
        return xmlErr.line, xmlErr.linepos, xmlErr.reason:from_utf8(1251)
    end
end

_G.comhelper = s

