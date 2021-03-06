
local s = {}

function s.CheckScript(strScript, bVbs)
    local reason, desc, line, pos = mblua.CheckVbScript(strScript)
    if not reason then return end
    return line or 0 , pos or 0 , reason..': '..(desc or '')
end

function s.CheckXml(strXml)
    local xml = luacom.CreateObject("MSXML.DOMDocument")
    if not strXml then strXml = editor:GetText() end
    strXml = strXml:to_utf8()
    if not xml:loadXml(strXml) then
        local xmlErr = xml.parseError
        return xmlErr.line, xmlErr.linepos, xmlErr.reason
    end
end

function s.GetNodeText(strXml, strPath)
    local xml = luacom.CreateObject("MSXML.DOMDocument")
    if not strXml then strXml = editor:GetText() end
    strXml = strXml:to_utf8()
    if not xml:loadXml(strXml) then
        local xmlErr = xml.parseError
        return xmlErr.line, xmlErr.linepos, xmlErr.reason
    end
    local bOk, msg = pcall(function() return xml:selectSingleNode(strPath) end)
    if not bOk then
        print(msg)
        return
    end
    if msg == nil then
        print('Not Found')
    else
        return msg.text
    end
end

function s.FormatXml(strXml, lenInd, strInd0, strNoNewLineBgn, strNoNewLineEnd, clbExt, encoding)
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
                local chTxt = oChild.text:to_utf8()
                if not oChild.nextSibling then
                    if string.find(strNoNewLineEnd, ','..oNode.nodeName..',') then
                        oChild.text = chTxt:gsub('[\r\n\t ]*$', '')
                    elseif string.find(strInd0, ','..oNode.nodeName..',') then
                        oChild.text = chTxt:gsub('\r\n%s*$', '\r\n')
                    else
                        oChild.text = chTxt:gsub('\r\n%s*$', indent)
                    end
                elseif oChild.nextSibling.nodeTypeString  == 'element' then
                    if string.find(strInd0, ','..oChild.nextSibling.nodeName..',') then
                        oChild.text = chTxt:gsub('\r\n%s*$', clb(oChild.nextSibling, '\r\n', indent))
                    else
                        oChild.text = chTxt:gsub('\r\n[\t ]*$', clb(oChild.nextSibling, newindent, indent))
                    end
                elseif oChild.nextSibling.nodeTypeString == 'cdatasection' then
                    oChild.text = chTxt:gsub('[\r\n\t ]*$', '')
                end
                bPrevTxt = true
            elseif oChild.nodeTypeString == 'cdatasection' then
                local lMin
                if string.find(strInd0, ','..oChild.parentNode.nodeName..',') then
                    local ni = clb(oChild.parentNode, '\n', newindent:gsub('\r', ''))
                    oChild.text = oChild.text:to_utf8():gsub('\n[\t ]*$', ni)
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
            --����� ���� ��� ����� ���� ����� ���������� ��� �������
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
    if( (encoding or tonumber(props['editor.unicode.mode'])) == IDM_ENCODING_DEFAULT) then
        strXml = strXml:to_utf8()
    end
    xml.preserveWhiteSpace = true
    if not xml:loadXml(strXml) then
        local xmlErr = xml.parseError
        print(':'..xmlErr.line..':'..xmlErr.linepos, xmlErr.reason)
        return strXml, true
    end

    FormatNode(xml, xml.firstChild, '\r\n', lenInd)
    if((encoding or tonumber(props['editor.unicode.mode'])) == IDM_ENCODING_DEFAULT) then
        return xml.xml
    else
        return xml.xml:to_utf8()
    end
end

_G.comhelper = s

