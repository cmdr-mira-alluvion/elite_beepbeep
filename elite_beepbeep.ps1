$scriptVersion = "20180728_203218"

#Seeing a warning message that says "Security Warning Run only scripts that you trust."?
#Try this to fix it:
#http://stackoverflow.com/a/18883250

########## CONFIGURATION ##########

#sound alert configuration -- set $sound = $false to disable, $cooldown for lowest duration (seconds) between beeps
$sound = $true
$cooldown = 7

#TextToSpeech toggle
$readNames = $false

#Custom "beep" sound toggle
$customSound = $false

#custom "beep" sound path
$customSoundPath = ".\seatbelt.wav"

#how often to check the cmdrHistory file (in seconds), file watcher eventing seems to be squicky and inconsistent
#may benefit from a higher value since cmdrHistory isn't as immediately-responsive as netlog
$pollInterval = 1

#whether to run once and bail or keep polling
$pollForever = $true

#how often to re-fetch defs (in seconds)
$updateInterval = 60

#these should never change, but just in case, it's in the config section
$folder = (Get-ChildItem Env:LOCALAPPDATA).Value + "\Frontier Developments\Elite Dangerous\CommanderHistory"
$filter = "*.cmdrHistory"
#TODO: handle potential multi-user scenarios here

#whether or not to log to file into journal log directory
$logToFile = $true

#url to fetch cmdr ID -> name from
$definitions = "https://kncg.pw/hg4f3QL.txt"

########## CONFIGURATION ##########

########## FUNCTIONS ##########

#returns int for unix timestamp
Function Get-UnixTime() {
    Return [int][double]::Parse((Get-Date -UFormat %s))
}

#returns Interactions array from cmdrHistory file
Function Get-CmdrHistory() {
    Try {
        Return (Get-Content (Join-Path -Path $folder -ChildPath (Get-ChildItem -Path $folder -Filter $filter | Select -Last 1).Name) | ConvertFrom-Json)."Interactions"
    } Catch {
        Return $null
    }
}

#returns cmdr ID from journal log if they aren't in the defs
Function Get-JournalName() {
    $journaldir = (Get-ChildItem Env:USERPROFILE).Value + "\Saved Games\Frontier Developments\Elite Dangerous"
    #try to fetch name from journal for 5 seconds before returning a default value
    $i = 0
    Do {
        $lastlog = Get-Content (Join-Path -Path $journaldir -ChildPath (Get-ChildItem -Path $journaldir -Filter "Journal.*.log" | Select -Last 1).name) | ConvertFrom-Json
        foreach ($event in $lastlog) {
            if ($event.event -eq "Commander") {
                Return $event.name
                Break
            }
        }
        Start-Sleep -s 1
        $i++
    } While ($i -lt 5)
    Return "#unknown"
}

#grab ID->name defs from URI defined above
Function Get-IDToNames {
    #fetch definitions from internet if configured
    $cmdrs = $null
    If ($definitions -ne "") {
        Try {
            #grab latest defs from this url and convert into psobject from json
            $progressPreference = "silentlyContinue"
            $cmdrs = Invoke-WebRequest -Uri $definitions -Method Get -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json
            
            #exit if it's the same version
            If ($lastDefs -eq $cmdrs.'__LastUpdated') {
                Return $null
                Break
            }
            $lastDefs = $cmdrs.'__LastUpdated'
            
            #nag user if update available according to datasource
            If ($scriptVersion -lt $cmdrs.'__ScriptVersion') {
                " _   _           _       _`n" +
                "| | | |_ __   __| | __ _| |_ ___`n" +
                "| | | | '_ \ / _`` |/ _`` | __/ _ \`n" +
                "| |_| | |_) | (_| | (_| | ||  __/`n" +
                " \___/| .__/ \__,_|\__,_|\__\___|`n" +
                "    _ |_|         _ _       _     _`n" +
                "   / \__   ____ _(_) | __ _| |__ | | ___`n" +
                "  / _ \ \ / / _`` | | |/ _`` | '_ \| |/ _ \`n" +
                " / ___ \ V / (_| | | | (_| | |_) | |  __/`n" +
                "/_/   \_\_/ \__,_|_|_|\__,_|_.__/|_|\___|`n`n" +
                "https://github.com/cmdr-mira-alluvion/elite_beepbeep`n" | Write-Host -ForegroundColor Yellow
            }
            
            #grab number of knowns minus metadata/placeholder
            $count = ($cmdrs | Get-Member -MemberType NoteProperty).count - 2
            
            #emit info to console
            #"Loaded $count ID->CMDR definitions -- last updated $lastDefs" | Write-Host -ForegroundColor Green
        } Catch {
            #something went wrong -- exit and try again later
            "Could not fetch load ID->CMDR definitions. Please try again later." | Write-Host -ForegroundColor Red
            Break
            $cmdrs = $null
        }
    }
    Return $cmdrs
}

#two audible beep alert
Function Out-AlertBeep($last, $newNameInput) {
    #enforced minimum cooldown between beeps
    $now = (Get-UnixTime)
    $type = "double"
    
    If (($sound -eq $true) -and (($now - $last) -gt $cooldown)) {
        $last = $now
        
        If ($type -eq "double") {
            #TODO: Move readnames into $type, fully change to param, pass 'read' in mainloop bead on $readNames value
            If ($readNames -eq $false) {
                #TODO: Add file existence check here for custom sound
                If ($customSound -eq $false) {
                    #double C7 beeps
                    [Console]::Beep(2093.004522,200)
                    [Console]::Beep(2093.004522,200) 
                } Else {
                    (New-Object Media.SoundPlayer $customSoundPath).Play();
                }
            } Else {
                #Read Commander Name
                $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
                $speak.SelectVoiceByHints("Female")
                $speak.SpeakAsync($newNameInput) | Out-Null
            }
        } ElseIf ($type -eq "ascend") {
            #ascending A6-E7 beeps
            [Console]::Beep(1760.000000,200)
            [Console]::Beep(2637.020455,200)
        } ElseIf ($type -eq "descend") {
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
$firstRun = $true

#init last seen epoch time
$lastEpoch = (Get-CmdrHistory)[0].Epoch

#offset in update window to actually fetch
$updateOffset = Get-Random -Maximum $updateInterval

#last fetched defs version
$lastDefs = 0

#arraylist to hold people in current instance so _leaving_ the instance doesn't pop a beepbeep
$instance = New-Object System.Collections.ArrayList

#initialize speech synthesizer
If ($readNames -eq $true) {
    Add-Type -AssemblyName System.Speech
}

########## INIT ##########

#clear window
Get-Variable true | Out-Default
Clear-Host

#logfile init
$logFile = (Get-ChildItem Env:USERPROFILE).Value + "\Saved Games\Frontier Developments\Elite Dangerous\Beepbeep." + (Get-UnixTime) + ".log"
$logBuffer = ""

#initial defs fetch
$cmdrs = Get-IDToNames

#spit out current user's name entry if found, ID number otherwise
$currentID = ((Get-ChildItem -Path $folder -Filter $filter | Select -Last 1).Name) -Replace "Commander(\d+)\.cmdrHistory", '$1'
$currentName = $currentID + " '" + (Get-JournalName) + "'"
If ($definitions -ne "") { $definitions += "?s=" + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($currentName)) }
"ID: $currentName`n" | Tee-Object -Variable logBuffer | Write-Host -ForegroundColor Green

#exit instructions
"Press Ctrl+C to exit...`n" | Write-Host -ForegroundColor Red

#slurp up cmdrHistory file every polling interval, see which entries are new and spit them out
While ($pollForever) {
    #flush log buffer if it's enabled
    if (($logFile) -and ($logBuffer -ne "")) {
        Out-File -InputObject $logBuffer -FilePath $logFile -Encoding UTF8 -Append -NoNewline
        $logBuffer = ""
    }
    
    #scoop up history file as JSON, extract top-level Interactions array, parse through cmdrHistory for new entries
    Get-CmdrHistory | ForEach-Object {
        $epoch = $_."Epoch"
        $id = $_."CommanderID"
        $name = If ($cmdrs.$id) { $cmdrs.$id } Else { $id }
        
        #only emit a beep and a text line for new entries
        If ($epoch -gt $lastEpoch) {
            If ($firstRun -eq $false) { $lastEpoch = $epoch }
            $date = Get-Date -Date $origin.AddSeconds($epoch) -UFormat %T
            $direction = @()
            
            #if cmdr exists in the instance already, this beep is actually outbound rather than inbound
            If ($instance.BinarySearch($id) -lt 0) {
                $null = $instance.Add($id)
                $direction = @("Red", "  --->")
                
                #threshold-gated beep because this is an _incoming_ contact
                $lastBeep = Out-AlertBeep $lastBeep $name
            } Else {
                While ($instance.BinarySearch($id) -ge 0) { $instance.Remove($id) }
                $direction = @("Green", "<---  ")
                
                #no beep for outbound
            }
            
            ("[{0}] {1} {2}" -f $date, $direction[1], $name) | Tee-Object -Variable lineBuffer | Write-Host -ForegroundColor $direction[0]
            $logBuffer += $lineBuffer + "`n"
        }
        $firstRun = $false
    }
    
    #update cmdr defs if the timer says we need to
    If (((Get-UnixTime) % $updateInterval) -eq $updateOffset) {
        $cmdrs2 = (Get-IDToNames)
        If ($cmdrs2) { $cmdrs = $cmdrs2 }
    }
    
    #sleep before grabbing cmdrHistory file again
    Start-Sleep -s $pollInterval
}
