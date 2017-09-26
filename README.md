# elite_beepbeep.ps1

## Description

Glorified mirror of contacts history tab to put on second monitor with audible alert

## Instructions

Download .ps1 file and run with Powershell

----

Previous version pulled connection info from network logs and correlated manually stored address-name pairs to semi-reliably guess whose instance you're connecting to.  Turns out the game stores all this info with zero guesswork involved in the cmdrHistory file introduced in 2.3. New version polls that data and spits out CMDR names in your instance based on that history data.
