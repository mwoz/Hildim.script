--[[local chSep = "'"
local rightSide = "(','['{'If'For'Select'Case"
local leftSide = ")']'}'Then"
local twoSide = "[<>/=+-&%*]"
local get_api = false]]
local mark = nil
local cGroupContinued = 999999
local iChangedLine = -1

local nextIndent=''
--[[local tRight
local tLeft
local tTwo]]
-- local chLeftSide = '([%%),%{<>%/%=%+%-&%%%*])%s*([%w%d%"])'
local chLeftSide = '([%%),<>%/%=%+%-%%%*])%s*([%w%d%"])'
local chRightSide = '([%w%d%"])%s*([<>%/%=%+%-%%%*])'
-- local chRightSide = '([%w%d%"])%s*([%}<>%/%=%+%-&%%%*])'
local goodmark = props["autoformat.good.mark"]
local errmark = props["autoformat.err.mark"]
--local chTwoSide = '(%w)%s*([<>%/%=%+%-&%%%*])%s*(%w)'

-- 3 таблицы wrdBeginIndent wrdEndIndent wrdMidleInent -  в каждой строке - таблица
-- в первой колонке которой шаблон конструкции, а во второй - индекс, по которому они связаны друг с другом

local wrdBeginIndent = {
                        {"^(%s*)If%s.+%sThen%W%s*(%'?)(.*)$",1},
                        {"^(%s*)For%s.+%sTo%W",2},
                        {"^(%s*)For Each%s.+%sIn%W",2},
                        {"^(%s*)Select Case%W",3},
                        {"^(%s*)Sub%W",4},{"^(%s*)Private Sub%W",4},
                        {"^(%s*)Function%W",5},{"^(%s*)Private Function%W",5},
                        {"^(%s*)Do%W%s*(%'?)(.*)$",6},
                        {"^(%s*)Do While%W",7}, {"^(%s*)Do Until%W",7},
                        {"^(%s*)With%W",8},
                        {"^(%s*)While%W",9},
                        {"^(%s*)Class%W",10},
                        {"^(%s*)Property%W",11},{"^(%s*)Private Property%W",11}}
local wrdEndIndent   = {
                        {"^(%s*)End If%W%s*(%'?)(.*)$",1},
                        {"^(%s*)Next%W%s*(%'?)(.*)$",2},
                        {"^(%s*)End Select%W%s*(%'?)(.*)$",3},
                        {"^(%s*)End Sub%W%s*(%'?)(.*)$",4},{"^(%s*)End Function%W%s*(%'?)(.*)$",5},
                        {"^(%s*)Loop%W%s*(%'?)(.*)$",7}, {"^(%s*)Loop While%W",6}, {"^(%s*)Loop Until%W",6},
                        {"^(%s*)End With%W%s*(%'?)(.*)$",8},
                        {"^(%s*)Wend%W%s*(%'?)(.*)$",9},
                        {"^(%s*)End Class%W%s*(%'?)(.*)$",10},
                        {"^(%s*)End Property%W%s*(%'?)(.*)$",11}}
local wrdMidleInent =  {
                        {"^(%s*)Else%W%s*(%'?)(.*)$",1},{"^(%s*)ElseIf%s.+%sThen%W%s*(%'?)(.*)$",1},
                        {"^(%s*)Case%W",3}}
local strTab = string.rep(' ',props['tabsize'])

local keywords = {"If","Then","For","To","Each","In","Select","Case","Sub","Function","Do","While","Until","With","Set",  "Let", "Get", "Default", "Private", "Public", "Property", "Class",
                  "End","Next","Loop","Else","ElseIf","Or ","And ","Not ","True","False","IsNull","Is","Nothing","Exit","Wend","ExecuteGlobal"}
local keywordsUp = {}
local lk = table.maxn(keywords)
for i=1,lk do
    table.insert(keywordsUp,"(%W)("..string.gsub(keywords[i],'.',function(s)
        local r = ''
        if s~=' ' then r='['..string.upper(s)..string.lower(s)..']' end
        return r
    end
    )..")(%W)")
end

local function prnTable(name)
	print('> ________________')
	for i = 1, table.maxn(name) do
		print(name[i])
	end
	print('> ^^^^^^^^^^^^^^^')
end
local function prnTable2(name)
	for i = 1, table.maxn(name) do
		prnTable(name[i])
	end
end

local function CheckPattern(str,pattern)
    local _s,_e,s,c,cc = string.find(str,pattern)
    --зачитали: начало, конец, отступ, комментарий, что-то(не комментарий) за конструкцией
    if c ~= nil  then
        if c == '' and cc ~= '' then s = nil end   --если что-то - не комментарий-есть за Ifом, например, то эта строка нам не нужна
    end
    return s,_e  --вернули отступ и позицию конца строки
end

local function GetFullLine(nLine)
--возвращает полную строку-оператор
    local result = ""
    local n= 0
    local _s,_e,c,p = 0,0,'','_'
    while (c ~= "'" and p ==  '_') do
    --читаем строки, пока не нашли строки коммента и строка является продолжением
        local l = editor:GetLine(nLine+n)
        if l == nil then break end
        result = result..l
        _s,_e,c,p = string.find(result,"^%s*('?).-(_?)%s*$")
        --зачитали: начало, конец, коммент(если есть), символ продолжения строки(если есть)
        n = n+1
    end
    return result..' ',n,c=="'"
end

local function FindUp(stek,nLine,poses)
    local bPrevComment = false
    while true do
        local strUpLine,nContinued,bIsComment = GetFullLine(nLine) --прочли "продолженную" строку, поняли, коммент ли это или сколько раз онп рподолжена
        local bIsFound = false
        if nContinued > 1 and table.maxn(poses) > 0  then
            poses[table.maxn(poses)][4] = cGroupContinued  --пометили, что строка является продолжением
        end
        local s,_e
        if not bIsComment then
            for j=1,table.maxn(wrdEndIndent) do
                s,_e = CheckPattern(strUpLine,wrdEndIndent[j][1])
                if s ~=nil then  --нашли строку уменьшающую отступ
                    table.insert(poses,{string.len(s), _e, nLine,table.maxn(stek) })
                    table.insert(stek,wrdEndIndent[j][2])
                    bIsFound = true
                    break
                end
            end

            if not bIsFound then
                for j=1,table.maxn(wrdMidleInent) do
                    s,_e = CheckPattern(strUpLine,wrdMidleInent[j][1])
                    if s ~=nil then
                        if bPrevComment and table.maxn(poses) > 0  and poses[table.maxn(poses)][4] == 0 then
                            poses[table.maxn(poses)][4] = cGroupContinued + 1
                            --poses[table.maxn(poses)][1] = string.len(s) + 1
                        end
                        if stek[table.maxn(stek)] ~= wrdMidleInent[j][2] then
                            table.insert(poses,{string.len(s), _e, nLine, 0 })
                            return true,s
                        end
                        table.insert(poses,{string.len(s), _e, nLine,table.maxn(stek)-1 })
                        bIsFound = true
                        break
                    end
                end
            end
            if not bIsFound then
                for j=1,table.maxn(wrdBeginIndent) do
                    s,_e = CheckPattern(strUpLine,wrdBeginIndent[j][1])
                    if s ~=nil then
                        if bPrevComment and table.maxn(poses) > 0 and poses[table.maxn(poses)][4] == 0 then
                            poses[table.maxn(poses)][4] = cGroupContinued + 1
                            --poses[table.maxn(poses)][1] = string.len(s) + 1
                        end
                        if stek[table.maxn(stek)] ~= wrdBeginIndent[j][2] then
                            table.insert(poses,{string.len(s), _e, nLine ,0})
                            return true,s
                        else
                            table.remove(stek)
                            table.insert(poses,{string.len(s), _e, nLine, table.maxn(stek) })
                            if table.maxn(stek) == 0 then
                                return false,s
                            end
                            bIsFound = true
                            break
                        end
                    end
                end
            end
        end
        if not bIsFound then
            local _s1,_e1,intnt = string.find(strUpLine,"^(%s*)%S")
            local level = table.maxn(stek)
            if bIsComment and level == 1 and string.len(intnt) < 4 then level = level - 1 end
            if _s1 ~= nil then table.insert(poses,{string.len(intnt), 0, nLine, level }) end
        end
        nLine = nLine-1
        bPrevComment = bIsComment
        if nLine==0 then
            return true,''
        end
    end
end

local function FormatString(strLine, startPos)
--форматирование строки - добавление пробелов между операторами, ключевые слова с большой буквы
    local i = 0
    local _s,_e,strSep,strBody = string.find(strLine,"(%s*)(.*)")
    strSep = string.gsub(string.gsub(strSep,"\t",strTab),"\r","")
    local lk = table.maxn(keywords)

    local strOut = ''
    if string.sub(strBody,1,1) == "<" then return strSep,strOut end

    local strOutComm = ''
    local commPos = 0
    while true do     --отрежем комментарий, чтоб потом его снова приклеить. но при этом смотрим, коммент ли жто - иожет быть внутренность строки
        _s,_e, strOutComm, commPos = strBody:find("(%s*()'[^\n\r]*)", commPos+1)
        if _s then
            if editor.StyleAt[startPos + commPos - 1 + strSep:len()] == SCE_FM_VB_COMMENT then
                strBody = strBody:sub(1,_s-1)
                break
            end
        else
            break
        end
    end
    if not strOutComm then strOutComm = ''  end

    for substr2 in string.gmatch(strBody,'[^"]*"?') do
        if i%2 == 0 and not isComment then --обрабатываем только вне строк и комментов
            local j = 0
            local ss1 = ""
            for substr in string.gmatch(substr2,'[^#]*#?') do --внутри операторов пропускаем текст между # -  дата или инклюд
                if j%2 == 0 then

                    local _d

                    if i>1 then substr='"'..substr end
                    substr = string.gsub(substr,chLeftSide,"%1 %2")
                    substr = string.gsub(substr,chRightSide,"%1 %2")
                    substr = string.gsub(substr,"%)([<>%/%=%+%-&%%%*])",") %1")
                    substr = string.gsub(substr,"([<>%/%=%+%-&%%%*])%)","%1 )")
                    substr = string.gsub(substr,"([=,<>%/%*%(] ?)%- ([%w%(])","%1-%2") --обрабатываем унарный минус
                    if i>1 then substr=string.sub(substr,2) end
                    substr = " "..substr.." "

                    for k=1,lk do
                        substr = string.gsub(substr,keywordsUp[k],function(s1,s2,s3) return s1..keywords[k]..s3 end)
                    end
                    substr = string.sub(substr,2,-2)
                    substr = string.gsub(substr,"%s+"," ")
                end
                ss1 = ss1..substr
                j=j+1
            end
            substr2 = ss1
        end
        i=i+1

        strOut = strOut..substr2
    end
    return strSep, strOut..strOutComm
end

function FormatSelectedStrings()
    local lEnd = editor:LineFromPosition(editor.SelectionEnd)
    local lStart = editor:LineFromPosition(editor.SelectionStart)
    editor:BeginUndoAction()
    for i=lStart,lEnd do
        local strUpLine = editor:GetLine(i)
        local strSep,strOut = FormatString(strUpLine,editor:PositionFromLine(i))
        if strOut ~= "" then
            editor:SetSel(editor:PositionFromLine(i),editor:PositionBefore(editor:PositionFromLine(i+1)))
            editor:ReplaceSel(strSep..strOut)
        end
    end
    editor:EndUndoAction()
    local sp = scite.SendEditor(SCI_GETLINEENDPOSITION, lEnd)
    editor:SetSel(sp,sp)
end

local function ParseStructure(strSep,strOut,current_pos,current_line)

    local bIsError = false
    local bIsFound = false
    local strOutTest=strOut..' '
    local stek = {}  --в стек будем класть индексы открывающих, закрывающих и переходящих конструкций
    local poses={}   --каждая запись - таблица: величина текущего отступа, позиция окончания строки, номер строки, соответствующая позиция стека
    local s,_e
    for i=1,table.maxn(wrdBeginIndent) do
        s,_e = CheckPattern(strOut,wrdBeginIndent[i][1])
        if s ~=nil then  --нашли увеличивающую отступ конструкцию
            nextIndent = strSep..strTab  --вернем новую строку индента
            bIsFound = true
            break
        end
    end
    if not bIsFound then
        for i=1,table.maxn(wrdEndIndent) do
            s,_e = CheckPattern(strOut,wrdEndIndent[i][1])  --ищем конструкцию, уменьшающую отступ
            if s ~=nil then
                stek={wrdEndIndent[i][2]} --положили в стек индекс этой конструкции
                local  nLine = current_line - 1
                local l = string.len(strSep)
                bIsError,strSep = FindUp(stek,nLine,poses)
                table.insert(poses ,1,{l,_e+l,current_line,0})
                bIsFound = true
                break
            end
        end
        if bIsFound then
            nextIndent = strSep
        else
            for i=1,table.maxn(wrdMidleInent) do
                s,_e = CheckPattern(strOut,wrdMidleInent[i][1])
                if s ~=nil then
                    stek={wrdMidleInent[i][2]}
                    local  nLine = current_line - 1
                    local l = string.len(strSep)
                    bIsError,strSep = FindUp(stek,nLine,poses)
                    table.insert(poses ,1,{l,_e+l,current_line,0})
                    bIsFound = true
                    break
                end
            end
            if bIsFound then
                nextIndent = strSep..strTab
                bIsFound = true
            end
            if not bIsFound then
                nextIndent = strSep
                local s = string.find(strOut,"%_%s*$")
                if s == nil then
                    local n = current_line - 1
                    if n >= 0 then
                        local _s,_e,ni,_b,p = string.find(editor:GetLine(n),"(%s*)(.-)(%_?)%s*$")
                        while p == '_' and n>0 do
                            nextIndent = ni
                            n = n-1
                            _s,_e,ni,_b,p = string.find(editor:GetLine(n),"(%s*)(.-)(%_?)%s*$")
                        end
                    end
                end
            end
        end
    end
    return bIsError,strSep,poses
end


local function doAutoformat(current_pos)
    if current_pos < 0 then return true end
    local current_line = editor:LineFromPosition(current_pos)
    local startLine = editor:PositionFromLine(current_line)
    --Проверим стили - форматировать нужно только в Бэйсике
    if cmpobj_GetFMDefault() ~= SCE_FM_VB_DEFAULT then return end
    local strLine =  editor:textrange(startLine,current_pos)
    local strSep,strOut = FormatString(strLine, startLine)
    if strOut == ''  then
        nextIndent = strSep
        return true
    end
    local bIsError,poses
    bIsError,strSep,poses = ParseStructure(strSep,strOut,current_pos,current_line)

    local strNew = strSep..strOut
    if strLine:gsub('%s*$','')~=strNew:gsub('%s*$','') then
        editor:SetSel(startLine,current_pos)

        editor:ReplaceSel(strNew)

        -- current_pos = current_pos + 1 + editor.SelectionEnd -editor.SelectionStart - (current_pos - startLine)
        current_pos = current_pos + 1 + #strNew - #strLine
        editor:SetSel(current_pos, current_pos)
    end

    if poses ~=nil then
        if bIsError then mark = errmark else mark = goodmark end
        for i=1,table.maxn(poses) do
            local lStart = editor:PositionFromLine(poses[i][3])
            if poses[i][4] == 0 then EditorMarkText(lStart + poses[i][1], poses[i][2] - poses[i][1] - 1, mark) end
        end
    end
end

local function OnChar_local(char)
    if not editor.Focus then return end
    if string.byte(char) == 13 then
        if props["autoformat.line"]=="1" then doAutoformat(editor.CurrentPos - 1) end
        editor:ReplaceSel(nextIndent)
        return
    end
    nextIndent = ''
    if mark ~= nil then
        EditorClearMarks(goodmark)
        EditorClearMarks(errmark)
        mark = nil
    end

    if cmpobj_GetFMDefault()  ~= SCE_FM_VB_DEFAULT then return end

    if string.byte(char) ~= 13 then
        iChangedLine = editor:LineFromPosition(editor.SelectionStart)
        return
    end
    iChangedLine = -1

    -- local current_pos = editor.CurrentPos - 1
    -- if props["autoformat.line"]=="1" then doAutoformat(current_pos) end

    return true
end

local function OnUpdateUI_local()
    if not editor.Focus then return end
    local s = editor.SelectionStart
    local e = editor.SelectionEnd
    if iChangedLine > -1 and s == e and props["autoformat.line"]=="1" then
        local l = editor:LineFromPosition(s)
        if l ~= iChangedLine then
            local iline = editor.FirstVisibleLine
            doAutoformat(editor:PositionFromLine(iChangedLine+1)-1)
            editor.FirstVisibleLine = iline
            editor:SetSel(s,e)
            iChangedLine = -1
        end
    elseif iChangedLine > -1 then
        if editor:LineFromPosition(s) ~= editor:LineFromPosition(e) then
            iChangedLine = -1
        end
    end
end

local function IndentBlockUp()
    local current_pos = editor.CurrentPos
    local cur_line = editor:LineFromPosition(current_pos)
    local current_line_real = cur_line
    local startLine = editor:PositionFromLine(cur_line)
    local pos_in_line = current_pos - startLine
    local strLine =  editor:textrange(startLine,editor.LineEndPosition[cur_line])
    local checked = false
    local curLevel = 0
    repeat
        for j=1,table.maxn(wrdEndIndent) do
            if CheckPattern(strLine..'    ',wrdEndIndent[j][1]) then --нашли какой-то конец блока
                curLevel = curLevel - 1
                if curLevel < 0 then
                    checked = true
                end
                break
            end
        end
        if not checked then         --сдвигаемся на строку вниз
            for j=1,table.maxn(wrdBeginIndent) do
                if CheckPattern(strLine..'    ',wrdBeginIndent[j][1]) then --начало блока - увеличиваем счетчик блоков
                    curLevel = curLevel + 1
                    break
                end
            end
            cur_line = cur_line + 1
            if editor.LineCount <= cur_line then break end
            startLine = editor:PositionFromLine(cur_line)
            current_pos = editor.LineEndPosition[cur_line]
            strLine = editor:textrange(startLine,current_pos)
        end
    until checked
    nextIndent = nil
    local _,_,strSep,strOut = string.find(strLine,"^(%s*)(%S.*)")
    if strOut == nil or not checked  then
        nextIndent = strSep
        return
    end

    local bIsError,poses
    bIsError,strSep,poses = ParseStructure(strSep,strOut..' ',current_pos,cur_line)
    if poses ~=nil then
        if bIsError then mark = errmark else mark = goodmark end
        if bIsError then
            for i=1,table.maxn(poses) do
                local lStart = editor:PositionFromLine(poses[i][3])
                if poses[i][4] == 0 then EditorMarkText(lStart + poses[i][1], poses[i][2] - poses[i][1] - 1, mark) end
            end
        else
            editor:BeginUndoAction()
            local startIndent = -1
            local newIndent,oldLine,newLine,prevIndent,prevIndentPreset
            for i=table.maxn(poses),1,-1 do
                local lStart = editor:PositionFromLine(poses[i][3])
                if startIndent == -1 then
                --первая строка  - отмечаем-подсвечиваем
                    startIndent = poses[i][1]
                    EditorMarkText(lStart + startIndent, poses[i][2] - poses[i][1] - 1, mark)
                    prevIndent = startIndent
                    prevIndentPreset = startIndent
                else
                    oldLine = editor:GetLine(poses[i][3])
                    local  sepLen
                    if poses[i][4] >= cGroupContinued then
                        if poses[i][4] == cGroupContinued then
                            newIndent = prevIndent + poses[i][1] - prevIndentPreset
                            -- print(poses[i][1],oldLine)
                        else
                            newIndent = prevIndent
                        end
                        sepLen = poses[i][1]
                        if sepLen > 0  then sepLen = sepLen + 1 end
                    else
                        newIndent = startIndent + poses[i][4]*props['tabsize']
                        prevIndent = newIndent
                        prevIndentPreset = poses[i][1]
                        sepLen = poses[i][1]
                        if sepLen > 0 then sepLen = sepLen + 1 end
                    end
                    scite.SendEditor(SCI_SETLINEINDENTATION,poses[i][3],newIndent)
                    if poses[i][4] == 0 then EditorMarkText(lStart + newIndent, poses[i][2] - poses[i][1] - 1, mark) end
                end
            end
            editor:EndUndoAction()
        end
    --end
    else
        print('No Strcture', strSep,strOut,current_pos,cur_line)
    end
    current_pos = editor:PositionFromLine(current_line_real) + pos_in_line
    editor:SetSel(current_pos,current_pos)
    --editor:LineEnd()
end

------------------------------------------------------


AddEventHandler("OnChar", function(char)
	if props['macro-recording'] ~= '1' and cmpobj_GetFMDefault()  == SCE_FM_VB_DEFAULT then
        if OnChar_local(char) then return true end
    end
end)
AddEventHandler("OnUpdateUI", function()
    if props['macro-recording'] ~= '1' and cmpobj_GetFMDefault()  == SCE_FM_VB_DEFAULT then
        OnUpdateUI_local()
    end
end)
AddEventHandler("OnSwitchFile", function() iChangedLine = -1 end)
AddEventHandler("OnOpen", function() iChangedLine = -1 end)
AddEventHandler("OnSave", function() iChangedLine = -1 end)

menuhandler:InsertItem('MainWindowMenu', 'Edit¦s1',
    {'Vbs/VbScript',  visible_ext='form,rform,cform,incl,vbs,wsf,bas,frm,cls,ctl,pag,dsr,dob',{
        {'Format Block',  ru = 'Форматировать блок', action=IndentBlockUp, key = 'Ctrl+]'},
        {'Format Line',  ru = 'Форматировать строку', action=FormatSelectedStrings, key = 'Ctrl+['},
        {'Autformating Lines',  ru = 'Автоформатирование строк', check_iuprops='autoformat.line', key = 'Ctrl+Shift+['},

    }})
