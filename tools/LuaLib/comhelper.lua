
local s = {}

require "luacom"

function s.CheckScript(strScript, bVbs)
    local oScr = luacom.CreateObject('MSScriptControl.ScriptControl')
    oScr.Language = Iif(bVbs, 'VBScript', 'JScript')
    oScr.AllowUI = true
    luacom.TryCatch(oScr)
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

function s.FormatXml(strXml, lenInd, strInd0, strNoNewLineBgn, strNoNewLineEnd, clbExt)
    chNODE_TEXT = 3
    local clb = clbExt or function(n, i) return i end
    strInd0 = ','..(strInd0 or '')..','
    strNoNewLineEnd = ','..(strNoNewLineEnd or '')..','
    strNoNewLineBgn = ','..(strNoNewLineBgn or '')..','
    local function FormatNode(objXml, oNode, indent)
        if oNode.nodeTypeString  == 'processinginstruction' then oNode = oNode.nextSibling end
        local oChild = oNode.firstChild
        local newindent = indent.. string.rep(' ', lenInd)
        local strLastNode = ''
        local bPrevTxt = false
        local bHasChild = false
        local lastNode
        while oChild do
            lastNode = oChild
            bHasChild = true
            if oChild.nodeTypeString == 'text' then
                if not oChild.nextSibling then
                    if string.find(strNoNewLineEnd, ','..oNode.nodeName..',') then
                        oChild.text = oChild.xml:gsub('[\r\n\t ]*$', '')
                    elseif string.find(strInd0, ','..oNode.nodeName..',') then
                        oChild.text = oChild.xml:gsub('\r\n%s*$', '\r\n')
                    else
                        oChild.text = oChild.xml:gsub('\r\n%s*$', indent)
                    end
                elseif oChild.nextSibling.nodeTypeString  == 'element' then
                    if string.find(strInd0, ','..oChild.nextSibling.nodeName..',') then
                        oChild.text = oChild.xml:gsub('\r\n%s*$', clb(oChild.nextSibling, '\r\n', indent))
                    else
                        oChild.text = oChild.xml:gsub('\r\n[\t ]*$', clb(oChild.nextSibling, newindent, indent))
                    end
                elseif oChild.nextSibling.nodeTypeString == 'cdatasection' then
                    oChild.text = oChild.xml:gsub('[\r\n\t ]*$', '')
                end
                bPrevTxt = true
            elseif oChild.nodeTypeString == 'cdatasection' then
                local lMin
                if string.find(strInd0, ','..oChild.parentNode.nodeName..',') then
                    local ni = clb(oChild.parentNode, '\n', newindent:gsub('\r', ''))
                    oChild.text = oChild.text:gsub('\n[\t ]*$', ni)
                    if ni ~= '\n' then
                        for s in oChild.text:gmatch('\n([ ]*)[^\n\r\t ]') do
                            if (lMin or #s) >= #s then lMin = #s end
                            if lMin == 0 then break end
                        end
                        if false then
                            oChild.text = oChild.text:gsub('\n([ ]*)([^\n\r\t ])', function(p, s)
                                return '\n'..string.rep(' ',#p + #ni - 1 - lMin + lenInd )..s
                            end
                            )
                        end
                    end
                else
                    oChild.text = oChild.text:gsub('\n[\t ]*$', indent:gsub('\r', ''))
                    if indent ~= '\r\n' then
                        for s in oChild.text:gmatch('\n([ ]*)[^\n\r\t ]') do
                            if (lMin or #s) >= #s then lMin = #s end
                            if lMin == 0 then break end
                        end
                        if false then
                            oChild.text = oChild.text:gsub('\n([ ]*)([^\n\r\t ])', function(p, s)
                                return '\n'..string.rep(' ',#p + #indent - 2 - lMin + lenInd )..s
                            end
                            )
                        end
                    end
                end
            elseif oChild.nodeTypeString  == 'element' then
                local oIndent = objXml:createNode(chNODE_TEXT, '', '')
                strLastNode = oChild.nodeName
                local ni = newindent
                if string.find(strNoNewLineBgn, ','..strLastNode..',') then ni = nil end
                if string.find(strInd0, ','..strLastNode..',') then ni = '\r\n' end
                oIndent.text = clb(oChild, (ni or ''), indent)
                if not bPrevTxt then oNode:insertBefore(oIndent, oChild) end
                FormatNode(objXml, oChild, (ni or '\r\n'))
                bPrevTxt = false
            elseif oChild.nodeTypeString == 'comment' then
                bHasChild = true
                local oIndent = objXml:createNode(chNODE_TEXT, '', '')
                oIndent.text = newindent
                if not bPrevTxt then oNode:insertBefore(oIndent, oChild) end
                bPrevTxt = false
            else
                bPrevTxt = false
            end
            oChild = oChild.nextSibling
        end
        if bHasChild then
            local oIndent = objXml:createNode(chNODE_TEXT, '', '')
            --После этих нод новые ноды будем отображать без отступа
            if string.find(strNoNewLineEnd, ','..strLastNode..',') then
                oIndent.text = ''
            elseif oNode.nodeTypeString == 'element' and string.find(strInd0, ','..oNode.NodeName..',') then
                oIndent.text = '\r\n'
            elseif string.find(strInd0, ','..strLastNode..',') then
                oIndent.text = clb(lastNode, '\r\n', indent:gsub(string.rep(' ', lenInd)..'$', ''))
            else
                oIndent.text = indent
            end
            if not bPrevTxt then oNode:appendChild(oIndent) end
        end
    end

    local xml = luacom.CreateObject("MSXML.DOMDocument")
    if not strXml then strXml = editor:GetText() end
    strXml = strXml:to_utf8(1251)
    xml.preserveWhiteSpace = true
    if not xml:loadXml(strXml) then
        local xmlErr = xml.parseError
        print(xmlErr.line, xmlErr.linepos, xmlErr.reason:from_utf8(1251))
        return strXml, true
    end

    FormatNode(xml, xml.firstChild, '\r\n', lenInd)
    return xml.xml
end

_G.comhelper = s

