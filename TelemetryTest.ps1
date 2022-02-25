# Telemetry test 
function Test-Administrator {
    [OutputType([bool])]
    param()
    process {
        [Security.Principal.WindowsPrincipal]$user = [Security.Principal.WindowsIdentity]::GetCurrent();
        return $user.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator);
    }
}

function Create-Folder {
    param($Folder)
    if ( -not (Test-Path -path $Folder )) {
        Write-Host $Folder "directory does not exist, let's create it"
        New-Item -Path $Folder -ItemType directory
        Write-Host "Create mandatory folder" $Folder
    } else {
        Write-Host $Folder "exist, we are fine"
    }
    Start-Sleep -s 2

}

function KillProc { 
    param($processName2Kill)
    $p = Get-Process | Where-Object {$_.ProcessName -match $processName2Kill} 
    if ($p) {
        Write-Host 'Process killed: ' $p.Name
        Stop-Process -Name $p.Name -Force
    } 
    else {Write-host "Process does not exist" $processName2Kill}
}

if (-not (Test-Administrator)) {
    Write-Error "This script must be executed as Administrator."
    break
}

# create mandatory folder 
$telemetry= "c:\telemetrydownload"
Create-Folder $telemetry

$baseUrl = "https://raw.githubusercontent.com/girdav01/filesfortest/main"
Write-Host "Download file list"
$fileUrl=  $baseUrl + "/filelist.txt"
$targetFullPath = join-path $telemetry "filelist.txt"
Invoke-WebRequest -Uri $fileUrl -OutFile $targetFullPath

#Download the files from filelist.txt (file names) 
foreach($line in Get-Content $targetFullPath) {
    Write-Host $line
    $fileUrl=  $baseUrl + "/" + $line
    $targetPath = join-path $telemetry $line
    Invoke-WebRequest -Uri $fileUrl -OutFile $targetPath
}
Start-Sleep 5
# Open Files test
foreach($line in Get-Content $targetFullPath) {
    Write-Host "Open files $line"  
    $targetPath = join-path $telemetry $line
    Invoke-Expression $targetPath
}
Start-Sleep 5

# Process to kill
Write-Host "Kill processes we created by opening files"
KillProc "Word"
KillProc "Notepad"
KillProc "Photos"
Start-Sleep 10

# create folder for copy test
$telemetrycopy= "c:\telemetrycopy"
Create-Folder $telemetrycopy
foreach($line in Get-Content $targetFullPath) {
    Write-Host "Copy file $line to $telemetrycopy"  
    $sourcetPath = join-path $telemetry $line
    #copy files from sourcetPath to destination : telemetrycopy
    Copy-Item -Path $sourcetPath -Destination $telemetrycopy
}
Start-Sleep 5
Write-Host "Add Local user to test ACL modifications"
# Add a local account to demo ACL, need 64 bits for New-LocalUser command
New-LocalUser -Name "User02" -Description "Description of this account." -NoPassword
# Set ACL test, reuse copy test folder
$path = "c:\telemetrycopy" 
$user = "User02" #User account to grant permisions too.
$Rights = "Read, ReadAndExecute, ListDirectory" #Comma seperated list.
$InheritSettings = "Containerinherit, ObjectInherit" #Controls how permissions are inherited by children
$PropogationSettings = "None" #Usually set to none but can setup rules that only apply to children.
$RuleType = "Allow" #Allow or Deny.

$acl = Get-Acl $path
$perm = $user, $Rights, $InheritSettings, $PropogationSettings, $RuleType
$rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $perm
$acl.SetAccessRule($rule)
$acl | Set-Acl -Path $path

Start-Sleep 5

# create folder for move test
$telemetrymove= "c:\telemetrymove"
Create-Folder $telemetrymove
foreach($line in Get-Content $targetFullPath) {
    Write-Host "Move file $line to $telemetrymove"  
    $sourcetPath = join-path $telemetry $line
    #Move files from sourcetPath to destination : $telemetrymove
    Move-Item -Path $sourcetPath -Destination $telemetrymove
}

Start-Sleep 5
# Delete test
foreach($line in Get-Content $targetFullPath) {
    Write-Host "Delete file $line from $telemetrycopy"  
    $sourcetPath = join-path $telemetrycopy $line
    Remove-Item $sourcetPath -Force    
}

Write-Host "Deleting folders"
Remove-Item $telemetrycopy -Recurse -Force 
Remove-Item $telemetrymove -Recurse -Force
Remove-Item $telemetry -Recurse -Force
Write-Host "Deleting user02"
Remove-LocalUser -Name "User02"
