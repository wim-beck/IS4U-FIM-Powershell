<#
Copyright (C) 2016 by IS4U (info@is4u.be)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation version 3.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

A full copy of the GNU General Public License can be found 
here: http://opensource.org/licenses/gpl-3.0.
#>
Set-StrictMode -Version Latest

$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$admin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if($admin -eq $false) {
	Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition)) -WindowStyle Hidden
} else {
	$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
	Copy-Item (Join-Path $dir ".\FimPowerShellModule") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U.Fim") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U.FimPortal") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U.FimPortal.Rcdc") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U.FimPortal.Schema") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
	Copy-Item (Join-Path $dir ".\IS4U.FimPortal.Sspr") "$Env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force
}
Write-Host "Modules successfully deployed."