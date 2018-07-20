# elite_beepbeep.ps1

## Description

Glorified mirror of contacts history tab to put on second monitor with audible alert

Previous version pulled connection info from network logs and correlated manually stored address-name pairs to semi-reliably guess whose instance you're connecting to.  Turns out the game stores all this info with zero guesswork involved in the cmdrHistory file introduced in 2.3. New version polls that data and spits out CMDR names in your instance based on that history data.

3.0 release of E:D removed names from cmdrHistory and replaced them with numeric IDs that correspond to friendslist cmdrID column that was previously spammed in the netlogs prior to Apr 18, 2017 and the script now needs an external ID->Name data source to translate ID numbers to names, but will otherwise happily spit out the numeric if all you care about is the audible alert.

## Instructions

Download .ps1 file and run with Powershell

## Known Issues

* Should probably convert to IO.FileSystemWatcher event handler instead to not have to poll the whole JSON file every second
* Still need to drink bleach over FD using 1601 epoch instead of 1970
