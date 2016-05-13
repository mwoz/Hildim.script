'Скрипт компиляции m4 файлов
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
            WScript.Echo "!Файл недоступен"
            WScript.Quit
        End If

        outBody = outBody & "include(" & incPath & ")" & vbCrLf
    Next
    AfterInclude outBody

    If Not oFso.FileExists(m_SourceFilePath) Then
        WScript.Echo m_SourceFilePath
        WScript.Echo "!Файл недоступен"
        WScript.Quit
    End If
    Set incFile = oFso.OpenTextFile(m_SourceFilePath, 1)
    str = incFile.ReadAll
    incFile.Close
    outBody = outBody & str & vbCrLf & "go" & vbCrLf
    If dDebug = True Then
        WScript.Echo "!Файл: " & m_SourceFilePath & " -> tmp.m"
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
        WScript.Echo "Ошибка при запуске M4.exe. Файл не найден"
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
            WScript.Echo "M4 завершился с кодом: " & oExec.ExitCode
            If oExec.ExitCode <> 0 Then
                WScript.Echo "!Выполнение прервано из-за ошибки M4"
                WScript.Quit
            End If
            Exit Do  'Завершение независшего процесса
        End If
        iCount = iCount + 1    'Всего получается 5 секунд на ожидание...
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
            WScript.Echo "Ошибка при запуске SQL. Файл не найден"
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
                WScript.Echo "SQL завершился с кодом: " & oExec.ExitCode
                If oExec.ExitCode <> 0 Then
                    WScript.Echo "!Выполнение прервано из-за ошибки"
                    WScript.Quit
                End If
                Exit Do  'Завершение независшего процесса
            End If
            iCount = iCount + 1    'Всего получается 30 секунд на ожидание после последнего вывода программы
            WScript.Sleep 200
        Loop
    End If
End Sub

Sub AfterInclude(outBody)
    outBody = outBody & "use __KUSTOM_BASE__" & vbCrLf
    outBody = outBody & "go" & vbCrLf
End Sub

'Служебные функции
Function DOS2Win(DOSstr)
    ' Перекодировка строки вывода программ
    WINstr=""
    For i = 1 To Len(DOSstr)
        dkod = ASC(Mid(DOSstr, i, 1))
        If dkod < 128 Then 'цифры, знаки, английские буквы
            wkod = dkod
        ElseIf dkod < 224 Then 'А..п
            wkod = dkod + 64
        ElseIf dkod < 240 Then 'р..я
            wkod = dkod + 16
        ElseIf dkod = 240 Then 'Ё
            wkod = 168
        ElseIf dkod = 241 Then 'ё
            wkod = 184
        Else ' всё остальное
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
'''''''''''Начало скрипта'''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''
Set objArgs = WScript.Arguments
Dim dDebug
dDebug = False

If dDebug = True Then
    WScript.Echo "!Параметры запуска:"
    For I = 0 To objArgs.Count - 1
       WScript.Echo objArgs(I)
    Next
End If
'Задание и инициализация глобальных переменных
Dim m_SourceFilePath, m_SciteDataDir, m_ProjectRootDir, m_DefHFile, m_mode, m_base, m_user, m_pwd, m_mbaseTempl, m_strIncSql, m_strFromM4RootPath, m_bEncode
m_bEncode = False 'не используем перекодировку
'Файл для Обработки. Передается параметром из SciTe
m_SourceFilePath = objArgs(0)
' Корневая директория проектов Систематики. Передается параметром из SciTe(со слешом на конце)
m_ProjectRootDir = objArgs(1)
'Имя клиентского h-файла. Должно быть инициализировано в кастомном файле
m_DefHFile = ""
'Строка с именами файлов, которые должны быть проинклюжены. Может переопределяться кастомным файлом
m_strIncSql = "Radius\Modules\common_macros.h,Radius\Modules\radius_modules.h"
'Директория, в которой будет размещена папка FromM4 с результатами компиляции. Может переопределяться кастомным файлом
m_strFromM4RootPath = objArgs(3)
If m_strFromM4RootPath = "" Then
    m_strFromM4RootPath = "%USERPROFILE%\Desktop"
End If

' Мода - (compile,build) - может переопределяться в кастомном файле
m_mode = "compile"
'База данных. Должна переопределяться в кастомном файле для m_mode = "compile"
m_base = ""
'Имя пользователя. Может переопределяться в кастомном файле для m_mode = "compile"
m_user = "kplus"
'Пароль. Должен переопределяться в кастомном файле для m_mode = "compile"
m_pwd = ""
'Шаблон командной строки для запуска утилиты базы. местодержатели в фигурных скобках будут заменены на
'значения соответствующих переменных. Для MSSQL должна быть переопределена из кастомного файла
' Должна переопределяться в кастомном файле для m_mode = "compile"
m_mbaseTempl = "%SYBASE%\%SYBASE_OCS%\bin\isql.exe -S{base} -U{user} -P{pwd} -i""{source}"""
'Читаем кастомный файл
Dim oFso, vbInc, strInc
Set oFso = CreateObject("Scripting.FileSystemObject")
Set vbInc = oFso.OpenTextFile(objArgs(2), 1)
strInc = vbInc.ReadAll
vbInc.Close
'Выполняем содержимое кастомного файла, в котором он определяет(переопределяет) соответствующие переменные
ExecuteGlobal strInc
'Приступаем к обработке
Main




