' Rename
' Version: 1.1
' Author: mozersЩ (иде€ codewarlock1101)
' ------------------------------------------------
' ѕереименовывает текущий файл
' ƒл€ подключени€ добавьте в свой файл .properties следующие строки: 
'     command.name.82.*=Rename current file
'     command.82.*=wscript "$(SciteDefaultHome)\tools\rename.vbs"
'     command.mode.82.*=subsystem:windows,replaceselection:no,savebefore:no,quiet:yes
'     command.shortcut.82.*=Shift+F6 
' ------------------------------------------------
Option Explicit
Dim FSO, SciTE
Dim dir, filename, filename_new
Set FSO = CreateObject("Scripting.FileSystemObject")
On Error Resume Next
Set SciTE = CreateObject("SciTE.Helper")
If Err.Number <> 0 Then
	MsgBox "Please install SciTE Helper before!", vbCritical, "Script Error"
	WScript.Quit 1
End If
On Error GoTo 0

dir = SciTE.Props("FileDir")
filename = SciTE.Props("FileNameExt")

filename_new = InputBox("Enter new filename:", "Rename file", filename)

If filename_new <> "" And filename_new <> filename Then
	filename = dir & "\" & filename
	filename_new = dir & "\" & filename_new
	SciTE.Send ("open:" & filename)
	SciTE.Send ("saveas:" & filename_new)
	If FSO.FileExists(filename_new) Then FSO.DeleteFile(filename)
End If

Set SciTE = Nothing
Set FSO = Nothing
WScript.Quit
