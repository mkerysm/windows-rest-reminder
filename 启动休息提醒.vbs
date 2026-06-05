Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set folder = fileSystem.GetFolder(fileSystem.GetParentFolderName(WScript.ScriptFullName))

For Each file In folder.Files
    If LCase(fileSystem.GetExtensionName(file.Name)) = "ps1" Then
        shell.Run "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & file.Path & """", 0, False
        Exit For
    End If
Next
