$scriptVersion = "20170927_174728"

#version 2.5 - adding custom sound and Text To Speech support

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

#TextToSpeech toggle
$readNames=$false

#Custom "beep" sound toggle
$customSound=$false

#custom "beep" sound path
$customSoundPath="C:\WINDOWS\Media\notify.wav"

#how often to check the cmdrHistory file (in seconds), file watcher eventing seems to be squicky and inconsistent
#may benefit from a higher value since cmdrHistory isn't as immediately-responsive as netlog
$pollInterval = 1

#these should never change, but just in case, it's in the config section
$folder = (Get-ChildItem Env:LOCALAPPDATA).Value + '\Frontier Developments\Elite Dangerous\CommanderHistory'
$filter = '*.cmdrHistory'

########## CONFIGURATION ##########

########## FUNCTIONS ##########

#returns int for unix timestamp
Function Get-UnixTime() {
    Return [int][double]::Parse((Get-Date -UFormat %s))
}

#returns Interactions array from cmdrHistory file
Function Get-CmdrHistory() {
    Return (Get-Content (Join-Path -Path $folder -ChildPath (Get-ChildItem -Path $folder -Filter $filter | Select -Last 1).Name) | ConvertFrom-Json).'Interactions'
}

#two audible beep alert
Function Out-AlertBeep($last, $newNameInput) {
    #enforced minimum cooldown between beeps
    $now = (Get-UnixTime)
    $type = 'double'
    
    If (($sound -eq $true) -and (($now - $last) -gt $cooldown)) {
        $last = $now
        
        If ($type -eq 'double') {
            If($readNames -eq $false) {
                If($customSound -eq $false) {
                    #double C7 beeps
                    [Console]::Beep(2093.004522,200)
                    [Console]::Beep(2093.004522,200) 
                } Else {
                    (New-Object Media.SoundPlayer $customSoundPath).Play();
                }
            } Else {
                #Read Commander Name
                $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speak.Speak($newNameInput)
            }
        } ElseIf ($type -eq 'ascend') {
            #ascending A6-E7 beeps
            [Console]::Beep(1760.000000,200)
            [Console]::Beep(2637.020455,200)
        } ElseIf ($type -eq 'descend') {
            #descending E7-A6 beeps
            [Console]::Beep(2637.020455,200)
            [Console]::Beep(1760.000000,200)
        }
    }
    Return $last
}

########## FUNCTIONS ##########

########## INIT ##########

#WHY THE FUCK DOES FRONTIER USE THE WIN32 GREGORIAN EPOCH OF 1601-JAN-01 WHAT THE ACTUAL FLYING FUCK ON ROLLERBLADES
$origin = Get-Date -Year 1601 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0

#make sure beeps aren't too spammy
$lastBeep = (Get-UnixTime)

#init last seen epoch time
$lastEpoch = (Get-CmdrHistory)[0].Epoch

#arraylist to hold people in current instance so _leaving_ the instance doesn't pop a beepbeep
$instance = New-Object System.Collections.ArrayList

########## INIT ##########

#exit instructions
Write-Host -ForegroundColor Red "Press Ctrl+C to exit..."

#slurp up cmdrHistory file every polling interval, see which entries are new and spit them out

Add-Type -AssemblyName System.speech
While ($true) {
    #scoop up history file as JSON, extract top-level Interactions array
    $history = (Get-CmdrHistory)
    
    #parse through cmdrHistory for new entries
    $history | ForEach-Object {
        $epoch = $_.'Epoch'
        $name = $_.'Name'
        
        #only emit a beep and a text line for new entries
        If ($epoch -gt $lastEpoch) {
            $lastEpoch = $epoch
            $date = Get-Date -Date $origin.AddSeconds($epoch) -UFormat %T
            $direction = @()
            
            #if cmdr exists in the instance already, this beep is actually outbound rather than inbound
            If ($instance.BinarySearch($name) -lt 0) {
                $null = $instance.Add($name)
                $direction = @('Red', '  --->')
                
                #threshold-gated beep because this is an _incoming_ contact
                $lastBeep = Out-AlertBeep $lastBeep $name
            } Else {
                While ($instance.BinarySearch($name) -ge 0) { $instance.Remove($name) }
                $direction = @('Green', '<---  ')
                
                #no beep for outbound
            }
            
            Write-Host -ForegroundColor $direction[0] ("[{0}] {1} {2}" -f $date, $direction[1], $name)
        }
    }
    
    Start-Sleep -s $pollInterval
}
