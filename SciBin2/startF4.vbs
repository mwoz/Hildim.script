Const ForReading = 1, ForWriting = 2, ForAppending = 8
Const TristateUseDefault = -2, TristateTrue = -1, TristateFalse = 0

'Скрипт для открытие файлов череез скайт'
Set objArgs = WScript.Arguments       ' Create object.
Set SciTE = CreateObject("SciTE.Helper")
While Scite.WindowId = 0 And i < 20
    If i=0 Then
        Set WshShell = CreateObject("WScript.Shell")
        WshShell.Exec( "c:\Program Files\Scite\SciTE.exe")
    End If
    WScript.Sleep 300
    i = i + 1
    Set SciTE = Nothing
    Set SciTE = CreateObject("SciTE.Helper")
Wend

for i=0 To  objArgs.Count -1        ' Loop through all arguments.
    str = Replace(objArgs(i),"\","\\")
    ind = InStrRev(str,":")
    If ind > 0 Then
        str = Mid(str, ind-1)
    Else
        msgbox str
    End If
    SciTE.LUA("scite.Open(""" & str & """)")
Next
Scite.Focus
Set SciTE = Nothing
Set WshShell = Nothing
