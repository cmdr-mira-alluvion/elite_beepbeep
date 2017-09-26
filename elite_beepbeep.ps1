$scriptVersion = "20170925_163220"

#version 2 - no more netlog needed (thanks 2.3)
#- no more manual correlation of ip addresses to cmdrs as FD directly supplies that information via commander history tab,
#  stored as cleartext unobfuscated JSON in your user profile directory
#  basically serves as a detached contact history window for a second monitor that also beepbeeps

#Seeing a warning message that says "Security Warning Run only scripts that you trust."?
#Try this to fix it:
#http://stackoverflow.com/a/18883250

########## CONFIGURATION ##########

#sound alert configuration -- set $sound = $false to disable, $cooldown for lowest duration (seconds) between beeps
$sound = $true
$cooldown = 7

#how often to check the cmdrHistory file (in seconds), file watcher eventing seems to be squicky and inconsistent
#may benefit from a higher value since cmdrHistory isn't as immediately-responsive as netlog
$frequency = 1

#these should never change, but just in case, it's in the config section
$folder = (Get-ChildItem Env:LOCALAPPDATA).Value + '\Frontier Developments\Elite Dangerous\CommanderHistory'
$filter = '*.cmdrHistory'

########## CONFIGURATION ##########

#returns int for unix timestamp
Function Get-UnixTime() {
    Return [int][double]::Parse((Get-Date -UFormat %s))
}

#two audible beep alert
Function Output-AlertBeep($last) {
    #enforced minimum cooldown between beeps
    $now = Get-UnixTime
    If (($sound -eq $true) -and (($now - $last) -gt $cooldown)) {
        $last = $now
        [Console]::Beep(2000,200)
        [Console]::Beep(2000,200)
    }
    Return $last
}

$file = Join-Path -Path $folder -ChildPath (Get-ChildItem -Path $folder -Filter $filter | Select -Last 1).Name

#exit instructions
Write-Host -ForegroundColor Red "Press Ctrl+C to exit..."

#register filesystem watcher
$watcher = New-Object IO.FileSystemWatcher $folder, $filter -Property @{IncludeSubdirectories = $false; NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'}

#WHY THE FUCK DOES FRONTIER USE THE WIN32 GREGORIAN EPOCH OF 1601-JAN-01 WHAT THE ACTUAL FLYING FUCK ON ROLLERBLADES
$origin = Get-Date -Year 1601 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0

#make sure beeps aren't too spammy
$lastbeep = Get-UnixTime

#init last seen epoch time
$lastepoch = ((Get-Content $file | ConvertFrom-Json).'Interactions')[0].Epoch

While($true) {
    #scoop up history file as JSON, extract top-level Interactions array
    $history = (Get-Content $file | ConvertFrom-Json).'Interactions'
    
    #we're interested primarily in Name and Epoch elements newer than $lastbeep
    $history | ForEach-Object {
        $date = Get-Date -Date $origin.AddSeconds($_.'Epoch') -UFormat %T
        $name = $_.'Name'
        If($_.'Epoch' -gt $lastepoch) {
            $lastepoch = $_.'Epoch'
            Write-Host "[$($date)] CONTACT: $($name)"
            
            #beepbeep
            $lastbeep = Output-AlertBeep($lastbeep)
        }
    }
    
    Start-Sleep -s $frequency
}
