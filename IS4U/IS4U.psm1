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
		try {
			$assembly = [Reflection.Assembly]::LoadWithPartialName($AssemblyName)
			$assembly.GetTypes() | ? { $_.IsPublic } | % {
				$typeAccelerators::Add( $_.Name, $_.FullName )
			}
		} catch {
			Write-Warning "Assembly $AssemblyName not found on this system."
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

Function Test-PropertyExists {
<#
	.SYNOPSIS
	Test if a given property exists on a PSObject.

	.DESCRIPTION
	Test if a given property exists on a PSObject. 
	This is an equivalent of the check if($object.property) { ... }
	But this check trhows errors when using strict mode, hence this method.
	[Source: https://powershell.org/forums/topic/testing-for-property-existance]
#>
	param(
		[Parameter(Mandatory=$True)]
		[PSObject]
		$Object,

		[Parameter(Mandatory=$True)]
		[String]
		$Property
	)
    return (Get-Member -InputObject $Object -Name $Property -MemberType Properties)
}

Function Get-EncryptedPwd {
<#
	.SYNOPSIS
	Get an encrypted password, convertable to secure string.

	.DESCRIPTION
	Get an encrypted password, convertable to secure string.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Pwd
	)
	$secureString = ConvertTo-SecureString -AsPlainText -Force -String $Pwd
	return ConvertFrom-SecureString $secureString
}

Function Publish-ModuleDocumentation {
<#
    .SYNOPSIS
    Generate github markdown style documentation for a given module.

    .DESCRIPTION
    Generate github markdown style documentation for a given module.

    .EXAMPLE
    Publish-ModuleDocumentation IS4U

    .PARAMETER Module
    Name of the module to be documented.
#>
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $Module
    )
    Import-Module $Module
    $modulePath = Join-Path $pwd $Module
    if(! (Test-Path $modulePath)) {
        mkdir $modulePath | Out-Null
    }
    $mod = Get-Module $Module
    foreach($function in $mod.ExportedCommands.Keys) {
		Write-Host "$function`n"
		$help = Get-Help $function -Full
        $syntax = "``{0}``" -f ($help.Syntax | Out-String).Trim()
		$description = ""
		if(Test-PropertyExists $help Description){
			$description = ($help.Description | Out-String).Trim()
		}
		$file = Join-Path $modulePath "$function.md"
        Write-Output "# Synopsis" | Out-File $file
        Write-Output $help.Synopsis | Out-File $file -Append
        Write-Output "`n# Syntax" | Out-File $file -Append
        Write-Output $syntax | Out-File $file -Append
        Write-Output "`n# Description" | Out-File $file -Append
        Write-Output $description | Out-File $file -Append
        Write-Output "`n# Parameters" | Out-File $file -Append
		if(Test-PropertyExists $help.parameters parameter){
			foreach($param in $help.parameters.parameter) {
				$name = $param.Name
				$description = ""
				if(Test-PropertyExists $param Description){
					$description = ($param.Description | Out-String).Trim()
				}
				$type = $param.Type.Name
				$required = $param.Required
				$position = $param.Position
				$defaultValue = $param.DefaultValue
				$pipeline = $param.PipelineInput
				Write-Output "`n## $name" | Out-File $file -Append
				Write-Output "$description`n" | Out-File $file -Append
				Write-Output "Property | Value" | Out-File $file -Append
				Write-Output "--- | ---" | Out-File $file -Append
				Write-Output "Type | $type" | Out-File $file -Append
				Write-Output "Required | $required" | Out-File $file -Append
				Write-Output "Position | $position" | Out-File $file -Append
				Write-Output "Default value | $defaultValue" | Out-File $file -Append
				Write-Output "Accept pipeline input | $pipeline" | Out-File $file -Append
			}
		}
        Write-Output "`n# Examples" | Out-File $file -Append
		if(Test-PropertyExists $help examples){
			foreach($example in $help.examples.example) {
				Write-Output "``$($example.code)``" | Out-File $file -Append
			}
		}
    }
}


