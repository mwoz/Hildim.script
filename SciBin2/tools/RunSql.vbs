'������ ���������� m4 ������
Sub Main()
    Dim arInc
    m_strIncSql = m_DefHFile & "," & m_strIncSql
    arInc = Split(m_strIncSql, ",")

    Dim incFile
    m_SciteDataDir = oFso.GetAbsolutePathName(oFso.GetParentFolderName(WScript.ScriptFullName) & "\..\") & "\data\"

    Dim outBody, incPath

    For i = 0 To Ubound(arInc)
        incPath = m_ProjectRootDir & arInc(i)
        If Not oFso.FileExists(incPath) Then
            WScript.Echo incPath
            WScript.Echo "!���� ����������"
            WScript.Quit
        End If

        outBody = outBody & "include(" & incPath & ")" & vbCrLf
    Next
    AfterInclude outBody

    If Not oFso.FileExists(m_SourceFilePath) Then
        WScript.Echo m_SourceFilePath
        WScript.Echo "!���� ����������"
        WScript.Quit
    End If
    Set incFile = oFso.OpenTextFile(m_SourceFilePath, 1)
    str = incFile.ReadAll
    incFile.Close
    outBody = outBody & str & vbCrLf & "go" & vbCrLf
    If dDebug = True Then
        WScript.Echo "!����: " & m_SourceFilePath & " -> tmp.m"
        WScript.Echo Left(outBody, 300)
        WScript.Echo "........................."
    End If

    Dim out
    Set out = oFso.OpenTextFile(m_SciteDataDir & "tmp.m", 2, True)
    out.Write outBody
    out.Close

    Set WshShell = WScript.CreateObject("WScript.Shell")
      ' WScript.Echo     WshShell.ExpandEnvironmentStrings("%SYBASE%\%SYBASE_OCS%\bin\")



    Dim strOutPath, tryCount

    If m_mode = "compile" Then
        strFolder = WshShell.ExpandEnvironmentStrings(m_strFromM4RootPath) & "\FromM4"
        If Not oFso.FolderExists(strFolder) Then oFso.CreateFolder(strFolder)

        strFolder = strFolder & "\" & oFso.GetExtensionName(m_DefHFile)
        If Not oFso.FolderExists(strFolder) Then  oFso.CreateFolder(strFolder)

        strFolder = strFolder & "\" & Year(Now) & "." & Right("0" & Month(Now),2) & "." & Right("0" & Day(Now),2)
        If Not oFso.FolderExists(strFolder) Then  oFso.CreateFolder(strFolder)

        strOutPath = strFolder & "\" & oFso.GetBaseName(m_SourceFilePath) & ".sql"

    Else
        strOutPath = m_SciteDataDir & "tmp.sql"
    End If
    allInput = ""
    tryCount = 0

    Set out = oFso.OpenTextFile(strOutPath, 2, True)
    On Error Resume Next

    Set oExec = WshShell.Exec(m_SciteDataDir & "\..\m4.exe """ & m_SciteDataDir & "tmp.m""")
    On Error GoTo 0
    If Err.Number <> 0 Then
        WScript.Echo "Error: " & Err.Description
        WScript.Quit
    End If
    If Not IsObject(oExec) Then
        WScript.Echo "������ ��� ������� M4.exe. ���� �� ������"
        WScript.Quit
    End If

    Dim iCount
    iCount = 0
    Do While iCount < 50

        If Not oExec.StdOut.AtEndOfStream Then
            out.Write oExec.StdOut.ReadAll
            WScript.Echo strOutPath & ":1: compiled"
        End If

        If Not oExec.StdErr.AtEndOfStream Then
            WScript.Echo DOS2Win("M4 error: " + oExec.StdErr.ReadAll)
        End If
        If oExec.Status <> 0 Then
            WScript.Echo "M4 ���������� � �����: " & oExec.ExitCode
            If oExec.ExitCode <> 0 Then
                WScript.Echo "!���������� �������� ��-�� ������ M4"
                WScript.Quit
            End If
            Exit Do  '���������� ����������� ��������
        End If
        iCount = iCount + 1    '����� ���������� 5 ������ �� ��������...
        WScript.Sleep 100
    Loop
    out.Close
    If m_mode = "build" Then
        m_mbaseTempl = Replace(m_mbaseTempl, "{base}", m_base)
        m_mbaseTempl = Replace(m_mbaseTempl, "{user}", m_user)
        m_mbaseTempl = Replace(m_mbaseTempl, "{pwd}", m_pwd)
        m_mbaseTempl = Replace(m_mbaseTempl, "{source}", strOutPath)
        m_mbaseTempl = WshShell.ExpandEnvironmentStrings(m_mbaseTempl)
        If dDebug = True Then WScript.Echo m_mbaseTempl
        Set oExec = WshShell.Exec(m_mbaseTempl)
        On Error GoTo 0
        If Err.Number <> 0 Then
            WScript.Echo "Error: " & Err.Description
            WScript.Quit
        End If
        If Not IsObject(oExec) Then
            WScript.Echo "������ ��� ������� SQL. ���� �� ������"
            WScript.Quit
        End If
        Do While iCount < 300
            If Not oExec.StdOut.AtEndOfStream Then
                If m_bEncode Then
                    WScript.Echo DOS2Win(oExec.StdOut.ReadAll)
                Else
                    WScript.Echo oExec.StdOut.ReadAll
                End If
                iCount = 0
            End If
            If Not oExec.StdErr.AtEndOfStream Then
                If m_bEncode Then
                    WScript.Echo DOS2Win(oExec.StdOut.ReadAll)
                Else
                    WScript.Echo oExec.StdOut.ReadAll
                End If
                iCount = 0
            End If
            If oExec.Status <> 0 Then
                WScript.Echo "SQL ���������� � �����: " & oExec.ExitCode
                If oExec.ExitCode <> 0 Then
                    WScript.Echo "!���������� �������� ��-�� ������"
                    WScript.Quit
                End If
                Exit Do  '���������� ����������� ��������
            End If
            iCount = iCount + 1    '����� ���������� 30 ������ �� �������� ����� ���������� ������ ���������
            WScript.Sleep 200
        Loop
    End If
End Sub

Sub AfterInclude(outBody)
    outBody = outBody & "use __KUSTOM_BASE__" & vbCrLf
    outBody = outBody & "go" & vbCrLf
End Sub

'��������� �������
Function DOS2Win(DOSstr)
    ' ������������� ������ ������ ��������
    WINstr=""
    For i = 1 To Len(DOSstr)
        dkod = ASC(Mid(DOSstr, i, 1))
        If dkod < 128 Then '�����, �����, ���������� �����
            wkod = dkod
        ElseIf dkod < 224 Then '�..�
            wkod = dkod + 64
        ElseIf dkod < 240 Then '�..�
            wkod = dkod + 16
        ElseIf dkod = 240 Then '�
            wkod = 168
        ElseIf dkod = 241 Then '�
            wkod = 184
        Else ' �� ���������
            wkod = ASC("_")
        End If
        On Error Resume Next
        WINstr = WINstr & CHR(wkod)
        On Error Resume Next
    Next
    DOS2Win = WINstr
End Function


''''''''''''''''''''''''''''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''
'''''''''''������ �������'''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''
Set objArgs = WScript.Arguments
Dim dDebug
dDebug = False

If dDebug = True Then
    WScript.Echo "!��������� �������:"
    For I = 0 To objArgs.Count - 1
       WScript.Echo objArgs(I)
    Next
End If
'������� � ������������� ���������� ����������
Dim m_SourceFilePath, m_SciteDataDir, m_ProjectRootDir, m_DefHFile, m_mode, m_base, m_user, m_pwd, m_mbaseTempl, m_strIncSql, m_strFromM4RootPath, m_bEncode
m_bEncode = False '�� ���������� �������������
'���� ��� ���������. ���������� ���������� �� SciTe
m_SourceFilePath = objArgs(0)
' �������� ���������� �������� �����������. ���������� ���������� �� SciTe(�� ������ �� �����)
m_ProjectRootDir = objArgs(1)
'��� ����������� h-�����. ������ ���� ���������������� � ��������� �����
m_DefHFile = ""
'������ � ������� ������, ������� ������ ���� ������������. ����� ���������������� ��������� ������
m_strIncSql = "Radius\Modules\common_macros.h,Radius\Modules\radius_modules.h"
'����������, � ������� ����� ��������� ����� FromM4 � ������������ ����������. ����� ���������������� ��������� ������
m_strFromM4RootPath = objArgs(3)
If m_strFromM4RootPath = "" Then
    m_strFromM4RootPath = "%USERPROFILE%\Desktop"
End If

' ���� - (compile,build) - ����� ���������������� � ��������� �����
m_mode = "compile"
'���� ������. ������ ���������������� � ��������� ����� ��� m_mode = "compile"
m_base = ""
'��� ������������. ����� ���������������� � ��������� ����� ��� m_mode = "compile"
m_user = "kplus"
'������. ������ ���������������� � ��������� ����� ��� m_mode = "compile"
m_pwd = ""
'������ ��������� ������ ��� ������� ������� ����. �������������� � �������� ������� ����� �������� ��
'�������� ��������������� ����������. ��� MSSQL ������ ���� �������������� �� ���������� �����
' ������ ���������������� � ��������� ����� ��� m_mode = "compile"
m_mbaseTempl = "%SYBASE%\%SYBASE_OCS%\bin\isql.exe -S{base} -U{user} -P{pwd} -i""{source}"""
'������ ��������� ����
Dim oFso, vbInc, strInc
Set oFso = CreateObject("Scripting.FileSystemObject")
Set vbInc = oFso.OpenTextFile(objArgs(2), 1)
strInc = vbInc.ReadAll
vbInc.Close
'��������� ���������� ���������� �����, � ������� �� ����������(��������������) ��������������� ����������
ExecuteGlobal strInc
'���������� � ���������
Main




