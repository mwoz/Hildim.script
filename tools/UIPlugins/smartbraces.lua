--[[--------------------------------------------------
SciTE Smart braces
Version: 1.3.1
Authors: Dmitry Maslov, Julgo, TymurGubayev
-------------------------------------------------
��������, ����:

 ��������� � ������������
 � ���������� ����������� braces.autoclose = 1
 � ���������� ����������� braces.open = ������������� ������
 � ���������� ����������� braces.close = ������������� ������
 ������������ ������ � ������� ������ ��-�� ����������� ������� OnKey

 �������� braces.multiline ���������� �������� ���� �������� (����� �������) ��� ������� �������� ������ ����������� � ��� ������ � �������� ����������. �� ��������� braces.multiline=cpp

-------------------------------------------------
����������:

 ������������ ������
 ������������ ����������� ������ � ������
 ������ ��������� { � } � cpp: ��������� ������ ������

-------------------------------------------------
������ ������:

 ������ ����������� ������ ���� braces.autoclose = 1

 ���� �� ������ ������ �� braces.open, �� ������������� �����������
 ��� ���� �� braces.close, ����� �������, ������ ����������� ����� ������

 ���� �� ������ ������������� ������ �� braces.close � ��������� ������
 ��� �� ������������� ������, �� ���� �������������� � ������ �������������
 ������ �� ����������

 ���� � ��� ������� ����� � �� ������ ������ �� braces.open,
 �� ����� ����������� ��������� braces.open - braces.close
 ���� �� ��� ��� �������� ���������, �� ��� ���������,
 ��� ���� ����������� ������ �������� ������, �.�. ���� ����������
 ����� ������������ ��������� ������, �� ������ ����������� �� ��������
 ������

 ���� �� ������ ������ { ��� �������������� ����� cpp, �� �������������
 ����������� ������� ������ ��� ����, � ����� } - ������ ��� ���� �����������
 � ��������, �.�. ����� ������� �������� ������, ��� ������� �����������

 ���� �� ��������� ������ } ��� �������������� ����� cpp, �� ������
 ������������� ����������� �� ����

 ���� �� ������ ��� �������� ������ ���������, �� ����� ����
 ��� �������� BACK_SPACE ��������� ����������� ������, �.�.
 ����������� ��� DEL, � �� ��� BACK_SPACE

 ���� ��������� ������ � ������� braces.open == braces.close,
 �� ����������� ���� ������ ���� ����� ������ ����� � ������

 ��������: � ������� ������������ �-��� string.pattern �� COMMON.lua
--]]--------------------------------------------------
local function Init()
    local prevBrClose = nil
    local prevFMDefault = 0
    local isformenjine = false

    local function FindCount( text, textToFind )
        local count = 0;
        for _ in string.gmatch( text, textToFind:pattern() ) do
            count = count + 1
        end
        return count
    end

    -- ������� ��� ������ ������ (�������� ������)
    local function IsLineStartPos( pos )
        return ( editor.LineIndentPosition[editor:LineFromPosition(pos)] == pos )
    end

    -- �������� ����� ������� ������
    local function GetCurrLineNumber()
        return editor:LineFromPosition( editor.CurrentPos )
    end

    -- �������� ������ � ������
    local function GetLineIndentation( num_line )
        if ( num_line < 0 ) then num_line = 0 end
        if ( num_line >= editor.LineCount ) then num_line = editor.LineCount - 1 end
        return ( editor.LineIndentation[num_line] / editor.Indent )
    end

    -- ��������� � ������ ?
    local function IsInLineEnd( num_line, text )
        local endpos = editor.LineEndPosition[num_line]
        if	( endpos >= string.len( text ) )
            and
            string.find( editor:textrange( editor:PositionBefore( endpos - string.len( text ) + 1 ), endpos ), text:pattern() )
        then
            return true
        end
        return false
    end

    -- ��������� ������ � ������ - ����� ������?
    local function IsEOLlast( text )
        -- � ��� ����� ������ ������ ���� ������
    --[[	if string.find( text, CORE.EOL(), string.len( text ) - 1 ) then
            return true
        end
        return false]]
        return (text:sub(-1) == CORE.EOL())
    end

    -- ��������� �� �������� ����� == text ?
    local function nextIs(pos, text)
        if text == nil then return false end
        if ( string.find( editor:textrange( pos, editor:PositionAfter( pos + string.len( text ) - 1 ) ), text:pattern() ) ) then
            return true
        end
        return false
    end

    -- ��������� ������ ������� ����� ������?
    local function nextIsEOL(pos)
        if	( pos == editor.Length )
            or
            ( nextIs( pos, '\r' ) or  nextIs( pos, '\n' ) )
        then
            return true
        end
        return false
    end

    -----------------------------------------------------------------
    -- ��������� ������, �������� bracebegin � braceend � ������ s ��
    -- ������������������: "(x)y(z)" -> true, "x)y(z" -> false
    local function BracesBalanced (s, bracebegin, braceend)
        if (#bracebegin + #braceend) > 2 then
            --@warn: ������ ������� �� ����� �������� �� "��������" ������ ������ �������.
            --@todo: ��� "�������" ������ ����� ���������� ��� ������� �� lpeg. �� ���� ��� ����?..
            return true
        end
        local b,e    = s:find("%b"..bracebegin..braceend)
        local b2 = s:find(bracebegin, 1, true)
        local e2 = s:find(braceend, 1, true)
        return (b == b2) and (e == e2)
    end -- BracesBalanced

    local function BlockBraces( bracebegin, braceend )
        local text = editor:GetSelText()
        local selbegin = editor.SelectionStart
        local selend = editor.SelectionEnd
        local b, e   = string.find( text, "^%s*"..bracebegin:pattern() )
        local b2, e2 = string.find( text, braceend:pattern().."%s*$" )
        local add = ( IsEOLlast( text ) and CORE.EOL() ) or ""

        editor:BeginUndoAction()
        if (b and b2) and BracesBalanced( text:sub( e+1, b2-1 ) , bracebegin, braceend ) then
            text = string.sub( text, e+1, b2-1 )
            editor:ReplaceSel( text..add )
            editor:SetSel( selbegin, selbegin + #( text..add ) )
        else
            editor:insert( selend - #add, braceend )
            editor:insert( selbegin, bracebegin )
            editor:SetSel( selbegin, selend + #( bracebegin..braceend ) )
        end
        editor:EndUndoAction()

        return true
    end

    local function GetIndexFindCharInProps( value, findchar )
        if findchar then
            local resIndex = string.find( props[value], findchar:pattern() , 1 )
            if	( resIndex ~= nil )
                and
                ( string.sub( props[value], resIndex,resIndex ) == findchar )
            then
                return resIndex
            end
        end
        return nil
    end

    local function GetCharInProps( value, index )
        return string.sub( props[value], index, index )
    end

    -- ���������� ������������� ������ � ������������� ������
    -- �� ��������� �������, �.�. ��������,
    -- ���� �� ����� ')' �� �� ������ '(' ')'
    -- ���� �� ����� '(' �� �� ������ '(' ')'
    local function GetBraces( char )
        local braceOpen = ''
        local braceClose = ''
        local symE = ''
        local brIdx = GetIndexFindCharInProps( 'braces.open.*', char )
        if ( brIdx ~= nil ) then
            symE = GetCharInProps( 'braces.close.*', brIdx )
            if ( symE ~= nil ) then
                braceOpen = char
                braceClose = symE
            end
        else
            brIdx = GetIndexFindCharInProps( 'braces.close.*', char )
            if ( brIdx ~= nil ) then
                symE = GetCharInProps( 'braces.open.*', brIdx )
                if ( symE ~= nil ) then
                    braceOpen = symE
                    braceClose = char
                end
            end
        end
        return braceOpen, braceClose
    end

    local g_isPastedBraceClose = false

    -- "����� ������/�������"
    -- ���������� true ����� ������������ ������ ������ �� �����
    local function SmartBraces( char )
        local multiline = props['braces.multiline']
        if multiline == '' then multiline = 'cpp' end
        local use_multiline = string.find(','..multiline..',', ','..props['Language']..',')

        if ( props['braces.autoclose'] == '1' ) then
            local isSelection = editor.SelectionStart ~= editor.SelectionEnd
            -- ������� ������ ������
            local braceOpen, braceClose = GetBraces(char)
            if ( braceOpen ~= '' and braceClose ~= '' ) then
                -- ��������� ������� �� � ��� ����� ���� �����
                if ( isSelection == true ) then
                    -- ������ ��������� �� ������������ ������ ��������
                    return BlockBraces( braceOpen, braceClose )
                else
                    -- ���� ��������� ������ ������������� ������
                    -- � �� �� ������, �� ���� ������������
                    local nextsymbol = string.format( "%c", editor.CharAt[editor.CurrentPos] )
                    if	( GetIndexFindCharInProps( 'braces.close.*', nextsymbol ) ~= nil)
                        and
                        ( nextsymbol == char )
                    then
                        editor:CharRight()
                        return true
                    end
                    -- ���� �� ������ ������������� ������ �
                    -- ��������� ������ ����� ������ ��� ��� ������ ������������� ������ ������� �� ������� � ������� ��� - ��� ������
                    -- �� ����� ��������� ������������� ������
                    if	( char == braceOpen )
                        and
                    ( nextIsEOL( editor.CurrentPos ) or --nextIs( editor.CurrentPos, braceClose ) or
                      nextIs( editor.CurrentPos, prevBrClose ) or nextIs( editor.CurrentPos, ' ' ) or
                      nextIs( editor.CurrentPos, '\t' ) or (string.find('}])', nextsymbol, 1, true) and editor:BraceMatch(editor.CurrentPos) > 0))
                    then
                        local virtSpace = scite.SendEditor(SCI_GETSELECTIONNANCHORVIRTUALSPACE, 0)
                        local isUndo = false
                        if ( char == braceOpen ) and  virtSpace > 0 then
                            editor:BeginUndoAction()
                            isUndo = true
                            editor:LineEnd()
                            editor.TargetStart = editor.CurrentPos
                            editor.TargetEnd = editor.CurrentPos
                            editor:ReplaceTarget(string.rep(' ', virtSpace))
                            editor:LineEnd()
                        end
                        -- �� ���������� ������������ ������ { � cpp()
                        if	( char == '{' ) and
                            ( use_multiline )
                        then
                            if not isUndo then editor:BeginUndoAction() end
                            local ln = GetCurrLineNumber()
                            if	( ln > 0 and GetLineIndentation( ln ) > GetLineIndentation( ln - 1 ) )
                                and
                                ( IsLineStartPos( editor.CurrentPos ) )
                                and
                                ( not IsInLineEnd( ln-1, '{' ) )
                            then
                                editor:BackTab()
                            end
                            editor:AddText( '{' )
                            editor:NewLine()
                            if ( GetLineIndentation( ln ) == GetLineIndentation( ln + 1 ) ) then
                                editor:Tab()
                            end
                            local pos = editor.CurrentPos
                            editor:NewLine()
                            if ( GetLineIndentation( ln + 2 ) == GetLineIndentation( ln + 1 ) ) then
                                editor:BackTab()
                            end
                            editor:AddText( '}' )
                            editor:GotoPos( pos )
                            editor:EndUndoAction()
                            return true
                        end
                        -- ���� ��������� ������ � ����������� ������ � �����, �� ������� ���� �� ��� �������� � ������
                        if	( braceOpen == braceClose )
                            and
                            ( math.fmod( FindCount( editor:GetCurLine(), braceOpen ), 2 ) == 1 )
                        then
                            return false
                        end
                        -- ��������� ������������� ������
                        if not isUndo then editor:BeginUndoAction() end
                        editor:InsertText( editor.CurrentPos, braceClose )
                        editor:EndUndoAction()
                        g_isPastedBraceClose = editor.CurrentPos
                    end
                    prevBrClose = braceClose --� ��������, ����� � ��� ����� ����������� ������ ������� ���� ���� ��������� ������
                    -- ���� �� ������ ������������� ������
                    if ( char == braceClose ) then
                        -- "�� ����������" ������������ ������ } � cpp
                        if ( char == '}' ) and
                            ( use_multiline )
                        then
                            editor:BeginUndoAction()
                            if (IsLineStartPos( editor.CurrentPos ) )
                            then
                                editor:BackTab()
                            end
                            editor:AddText( '}' )
                            editor:EndUndoAction()
                            return true
                        end
                    end
                end
            else
                prevBrClose = nil  --����� �� ������.������� - ������� ��������� � ������� ���
            end
        end
        return false
    end


    local function OnSwitchLocal()
        isformenjine = false
        if editor.Lexer ~= SCLEX_FORMENJINE then
            props['braces.open.*'] = props['braces.open']
            props['braces.close.*'] = props['braces.close']
        else
            isformenjine = true
        end
    end

    AddEventHandler("OnSwitchFile", OnSwitchLocal)
    AddEventHandler("OnOpen", OnSwitchLocal)
    AddEventHandler("OnUpdateUI", function()
        if isformenjine then
            if cmpobj_GetFMDefault() ~= prevFMDefault then
                local sector =  cmpobj_GetFMDefault()
                if sector == SCE_FM_VB_DEFAULT then
                    props['braces.open.*'] = props['braces.open.fm.vb']
                    props['braces.close.*'] = props['braces.close.fm.vb']
                elseif sector == SCE_FM_SQL_DEFAULT then
                    props['braces.open.*'] = props['braces.open.fm.sql']
                    props['braces.close.*'] = props['braces.close.fm.sql']
                elseif sector == SCE_FM_X_DEFAULT then
                    props['braces.open.*'] = props['braces.open.fm.x']
                    props['braces.close.*'] = props['braces.close.fm.x']
                else
                    if props['braces.open.'..editor.LexerLanguage] ~= nil then
                        props['braces.open.*'] = props['braces.open.'..editor.LexerLanguage]
                        props['braces.close.*'] = props['braces.close.'..editor.LexerLanguage]
                    else
                        props['braces.open.*'] = props['braces.open.def']
                        props['braces.close.*'] = props['braces.close.def']
                    end
                end
            end
        else
            if props['braces.open.'..editor.LexerLanguage] ~= "" then
                props['braces.open.*'] = props['braces.open.'..editor.LexerLanguage]
                props['braces.close.*'] = props['braces.close.'..editor.LexerLanguage]
            else
                props['braces.open.*'] = props['braces.open.def']
                props['braces.close.*'] = props['braces.close.def']
            end
        end
    end)

    -- ������������� ������� ��������� OnKey
    AddEventHandler("OnKey", function(key, shift, ctrl, alt, char)
        if ( editor.Focus and scite.SendEditor(SCI_GETSELECTIONS) == 1) then
            if ( key == 8 and g_isPastedBraceClose == editor.CurrentPos - 1 ) then -- VK_BACK (08)
                g_isPastedBraceClose = false
                editor:BeginUndoAction()
                editor:CharRight()
                editor:DeleteBack()
                editor:EndUndoAction()
                return true
            end

            g_isPastedBraceClose = false

            if ( char ~= '' ) then
                return SmartBraces( char )
            end
        end
    end)
end

return {
    title = '������������ ������/������������ ����������� ������ � ������',
    hidden = Init,
description = [[������������ ������
������������ ����������� ������ � ������]]
}
