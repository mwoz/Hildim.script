Const ForReading = 1, ForWriting = 2, ForAppending = 8
Const TristateUseDefault = -2, TristateTrue = -1, TristateFalse = 0

'Скрипт для открытие файлов череез скайт'
Set objArgs = WScript.Arguments       ' Create object.
Set SciTE = CreateObject("SciTE.Helper")
While Scite.WindowId = 0 And i < 20
    If i=0 Then
        Set WshShell = CreateObject("WScript.Shell")
        WshShell.Exec( "f:\Program Files (x86)\Scite\SciTE.exe")
    End If
    WScript.Sleep 300
    i = i + 1
    Set SciTE = Nothing
    Set SciTE = CreateObject("SciTE.Helper")
Wend
Set fso = CreateObject("Scripting.FileSystemObject")
Set file = FSO.GetFile(objArgs(0))

Set ts = file.OpenAsTextStream(ForReading, TristateUseDefault)


Do While ts.AtEndOfStream <> True
    strSrc = ts.ReadLine
    str = Replace(strSrc,"\","\\")
    ind = InStrRev(str,":")
    If ind > 0 Then
        str = Mid(str, ind-1)
        SciTE.LUA("scite.Open(""" & str & """)")

    ElseIf InStr(strSrc, "\\\Virtual Panel\") = 1 Then
        strSrc = Mid(strSrc,17)
        Set file2 = FSO.GetFile("c:\totalcmd\Plugins\wfx\VirtualPanel\VirtualPanel.lst")
        Set ts2 = file2.OpenAsTextStream(ForReading, TristateUseDefault)
        Do While ts2.AtEndOfStream <> True
        st1= Trim(Mid(ts2.ReadLine,28))
            If InStr(st1,strSrc ) = 1 Then
                st1 = Replace(Trim(Mid(st1,Len(strSrc)+2)),"\","\\")
                SciTE.LUA("scite.Open(""" & st1 & """)")
                'msgbox st1
            End If
        Loop
    End If
Loop

' for i=0 To  objArgs.Count -1        ' Loop through all arguments.
    ' str = Replace(objArgs(i),"\","\\")
    ' ind = InStrRev(str,":")
    ' If ind > 0 Then
        ' str = Mid(str, ind-1)
    ' Else
        ' msgbox str
    ' End If
    ' SciTE.LUA("scite.Open(""" & str & """)")
' Next
Scite.Focus
Set SciTE = Nothing
Set WshShell = Nothing
