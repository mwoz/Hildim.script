--[[--------------------------------------------------
FindText v7.3.1
������: mozers�, mimir, �������, codewarlock1101, VladVRO

* ���� ����� ������� - ������ ���������� ���������
* ���� ����� �� ������� - ������ ������� �����
* ����� �������� ��� � ���� ��������������, ��� � � ���� �������
* ������, ���������� ���������� ������, ��������� � �������
* ����������� �� ���������� - F3 (������), Shift+F3 (�����)
* ������ ����� ����� ��������� ������� ������ �����
* ������� �� �������� ������ - Ctrl+Alt+C

��������:
� ������� ������������ ������� �� COMMON.lua (EditorMarkText, EditorClearMarks)
-----------------------------------------------
��� ����������� �������� � ���� ���� .properties ��������� ������:
	command.name.130.*=Find String/Word
	command.130.*=dofile $(SciteDefaultHome)\tools\FindText.lua
	command.mode.130.*=subsystem:lua,savebefore:no
	command.shortcut.130.*=Ctrl+Alt+F

	command.name.131.*=Clear All Marks
	command.131.*=dostring EditorClearMarks() scite.SendEditor(SCI_SETINDICATORCURRENT, ifnil(tonumber(props['findtext.first.mark']),31))
	command.mode.131.*=subsystem:lua,savebefore:no
	command.shortcut.131.*=Ctrl+Alt+C

������������� ���������� ������ � ����� �������� ����� ������������ �������� � ����� ������� �� ������������ ������:
	findtext.first.mark=27
	indic.style.27=#CC00FF
	indic.style.28=#0000FF
	indic.style.29=#00CC66
	indic.style.30=#CCCC00
	indic.style.31=#336600

������������� ����� ������ �������������� ��������� ������:
	# ����� � ������ ��������
	findtext.matchcase=1
	# �������� ���������� ��������� ������
	findtext.bookmarks=1
	# �������� ��� ��������� ������ � �������
	findtext.output=1
	# ���������� ��������� �� ������� ��������
	findtext.tutorial=1
--]]----------------------------------------------------

local firstNum = ifnil(tonumber(props['findtext.first.mark']),31)
if firstNum < 1 or firstNum > 31 then firstNum = 31 end

local sText = props['CurrentSelection']
if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then
	sText = shell.from_utf8(sText)
end
local flag0 = 0
if (sText == '') then
	sText = props['CurrentWord']
	flag0 = SCFIND_WHOLEWORD
end
local flag1 = 0
if props['findtext.matchcase'] == '1' then flag1 = SCFIND_MATCHCASE end
local bookmark = props['findtext.bookmarks'] == '1'
local isOutput = props['findtext.output'] == '1'
local isTutorial = props['findtext.tutorial'] == '1'

local current_mark_number = scite.SendEditor(SCI_GETINDICATORCURRENT)
if current_mark_number < firstNum then current_mark_number = firstNum end
if string.len(sText) > 0 then
	if bookmark then editor:MarkerDeleteAll(1) end
	local msg
	if isOutput then
		if flag0 == SCFIND_WHOLEWORD then
			msg = '> '..scite.GetTranslation('Search for current word')..': "'
		else
			msg = '> '..scite.GetTranslation('Search for selected text')..': "'
		end
		props['lexer.errorlist.findtitle.begin'] = msg
		scite.SendOutput(SCI_SETPROPERTY, 'lexer.errorlist.findtitle.begin', msg)
		props['lexer.errorlist.findtitle.end'] = '"'
		scite.SendOutput(SCI_SETPROPERTY, 'lexer.errorlist.findtitle.end', '"')
		if tonumber(props["editor.unicode.mode"]) == IDM_ENCODING_DEFAULT then
			print(msg..sText..'"')
		else
			print(msg..shell.from_utf8(sText)..'"')
		end
	end
	local s,e = editor:findtext(sText, flag0 + flag1, 0)
	local count = 0
	if(s~=nil)then
		local m = editor:LineFromPosition(s) - 1
		while s do
			local l = editor:LineFromPosition(s)
			EditorMarkText(s, e-s, current_mark_number)
			count = count + 1
			if l ~= m then
				if bookmark then editor:MarkerAdd(l,1) end
				local str = string.gsub(' '..editor:GetLine(l),'%s+',' ')
				if tonumber(props["editor.unicode.mode"]) ~= IDM_ENCODING_DEFAULT then
					str = shell.from_utf8(str)
				end
				if isOutput then
					print('./'..props['FileNameExt']..':'..(l + 1)..':\t'..str)
				end
				m = l
			end
			s,e = editor:findtext(sText, flag0 + flag1, e+1)
		end
		if isOutput then
			print('> '..string.gsub(scite.GetTranslation('Found: @ results'), '@', count))
			if isTutorial then
				print('F3 (Shift+F3) - '..scite.GetTranslation('Jump by markers')..
					'\nF4 (Shift+F4) - '..scite.GetTranslation('Jump by lines')..
					'\nCtrl+Alt+C - '..scite.GetTranslation('Erase all markers'))
			end
		end
	else
		print('> '..string.gsub(scite.GetTranslation("Can't find [@]!"), '@', sText))
	end
	current_mark_number = current_mark_number + 1
	if current_mark_number > 31 then current_mark_number = firstNum end
	scite.SendEditor(SCI_SETINDICATORCURRENT, current_mark_number)
		-- ������������ ����������� �������� �� ���������� � ������� F3 (Shift+F3)
		if flag0 == SCFIND_WHOLEWORD then
			editor:GotoPos(editor:WordStartPosition(editor.CurrentPos))
		else
			editor:GotoPos(editor.SelectionStart)
		end
		scite.Perform('find:'..sText)
else
	EditorClearMarks()
	if bookmark then editor:MarkerDeleteAll(1) end
	scite.SendEditor(SCI_SETINDICATORCURRENT, firstNum)
	print('> '..scite.GetTranslation('Select text for search! (search for selection)'))
	print('> '..scite.GetTranslation('Or put cursor on the word for search. (search for word)'))
	print('> '..scite.GetTranslation('You can also select text in console.'))
end
--~ editor:CharRight() editor:CharLeft() --������� ��������� � ��������� ������
