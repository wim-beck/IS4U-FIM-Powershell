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

Function Add-TypeAccelerators {
<#
	.SYNOPSIS
	Add type accelerators for an assembly. Add a class name from this assembly to check
	if the accelerators already exist.

	.DESCRIPTION
	Add type accelerators for an assembly. Add a class name from this assembly to check
	if the accelerators already exist.

	.EXAMPLE
	Add-TypeAccelerators -AssemblyName System.Xml.Linq -Class XElement

	.PARAMETER AssemblyName
	Name of the assembly

	.PARAMETER Class
	Name of the class to check for existing accelerators
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AssemblyName,
		
		[Parameter(Mandatory=$True)]
		[String]
		$Class
	)
	$typeAccelerators = [psobject].Assembly.GetType("System.Management.Automation.TypeAccelerators")
	$existingAccelerators = $typeAccelerators::get
	if(! $existingAccelerators.ContainsKey($Class)) {
		$assembly = [Reflection.Assembly]::LoadWithPartialName($AssemblyName)
		$assembly.GetTypes() | ? { $_.IsPublic } | % {
			$typeAccelerators::Add( $_.Name, $_.FullName )
		}
	}
}

Function Install-DllInGac {
<#
	.SYNOPSIS
	Installs the given dll in the Global Assembly Cache (C:\Windows\Assembly).

	.DESCRIPTION
	Installs the given dll in the Global Assembly Cache (C:\Windows\Assembly).

	.EXAMPLE
	Install-DllInGac -Dll IS4U.ActivityLibrary.dll
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Dll
	)
	[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | Out-Null
	$publish = New-Object System.EnterpriseServices.Internal.Publish
	$publish.GacInstall((Join-Path $pwd $Dll))
}

Function Test-Port {
<#
	.SYNOPSIS
	Test if a given port is open for connections on a server.

	.DESCRIPTION
	Test if a given port is open for connections on a server.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Server,

		[Parameter(Mandatory=$True)]
		[String]
		$Port
	)
    $socket = New-Object Net.Sockets.TcpClient
    Try {
        $socket.Connect($Server, $Port)
        Write-Host -ForegroundColor Green "`tPort $Port is open on $Server."
	    $socket.Close()
    } Catch [System.Exception] {
        Write-Host -ForegroundColor Red "`tPort $Port is not open on $Server."
    }
}

Export-ModuleMember Add-TypeAccelerators
Export-ModuleMember Install-DllInGac
Export-ModuleMember Test-Port