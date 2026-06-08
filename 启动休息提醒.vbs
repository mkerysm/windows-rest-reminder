Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set folder = fileSystem.GetFolder(fileSystem.GetParentFolderName(WScript.ScriptFullName))
powerShellPath = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")

For Each file In folder.Files
    If LCase(fileSystem.GetExtensionName(file.Name)) = "ps1" Then
        command = """" & powerShellPath & """ -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & file.Path & """"
        shell.Run command, 0, False
        Exit For
    End If
Next
