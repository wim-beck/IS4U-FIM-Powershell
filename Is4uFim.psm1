<#
Copyright (C) 2015 by IS4U (info@is4u.be)

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

Function Start-Is4uFimSchedule
{
<#
	.SYNOPSIS
	Starts the on demand schedule of the IS4U FIM Scheduler.

	.DESCRIPTION
	Starts the on demand schedule of the IS4U FIM Scheduler.

	.EXAMPLE
	Start-Is4uFimSchedule
#>
	[System.Reflection.Assembly]::Load("System.ServiceProcess, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null
	$is4uScheduler = New-Object System.ServiceProcess.ServiceController
	$is4uScheduler.Name = "IS4UFIMScheduler"
	if($is4uScheduler.Status -eq "Running"){
		$is4uScheduler.ExecuteCommand(234)
	} else {
		Write-Host $is4uScheduler.DisplayName "is not running"
	}
}

Function Get-FimStatus
{
<#
	.SYNOPSIS
	Get the status of the FIM Windows Services

	.DESCRIPTION
	Displays the status of the different FIM and BHold Windows Services

	.EXAMPLE
	Get-FimStatus
#>
	$services = @("FIMSynchronizationService", "FIMService", "SPTimerV4", "W3SVC", "B1Service", "AttestationService")
	$oricolor = $Host.UI.RawUI.ForegroundColor
	foreach($service in $services) {
		$s = Get-Service -Name $service -ErrorAction SilentlyContinue
		if(!$s){
			Write-Warning "Service $service not present on this host"
		} else {
			$s | Format-Table -Property @{label = 'Status'; Expression = { if( $_.Status -ne "Running") `
			{$Host.UI.RawUI.ForegroundColor = "red"; $_.Status } else `
			{$Host.UI.RawUI.ForegroundColor = $oricolor; $_.Status }} ; Width = 8}, `
			@{label = 'Name'; Width = 26; Expression = {$_.Name}}, DisplayName
		}
	}
	$Host.UI.RawUI.ForegroundColor = $oricolor
}
