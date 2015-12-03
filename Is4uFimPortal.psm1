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
Import-Module .\Is4u.psm1
Import-Module .\Is4uFim.psm1

Function New-AttributeAndBinding {
<#
.SYNOPSIS
Create a new attribute, attribute binding, MPR-config, filter permission, ... in the FIM Portal schema.

.DESCRIPTION
Create a new attribute, attribute binding, MPR-config, filter permission, ... in the FIM Portal schema.

.EXAMPLE
New-AttributeAndBinding -AttrName Visa -DisplayName "Visa Card Number" -Type String
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name, 
		
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		[ValidateScript({("String", "DateTime", "Integer", "Reference", "Boolean", "Text", "Binary") -contains $_})]
		$Type, 
		
		[Parameter(Mandatory=$False)]
		[Boolean]
		$MultiValued = $False,
		
		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)

    [UniqueIdentifier] $attrId = New-Attribute -Name $Name -DisplayName $DisplayName -Type $Type -MultiValued $MultiValued
	$obj = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $ObjectType
    New-AttributeBinding -AttrName $Name -DisplayName $DisplayName -ObjectType $obj
	if($ObjectType -eq "Person"){
		Add-AttributeToMPR -AttrName $Name -MprName "Administration: Administrators can read and update Users"
		Add-AttributeToMPR -AttrName $Name -MprName "Synchronization: Synchronization account controls users it synchronizes"
	}
	Add-AttributeToFilterScope -Attribute $attrId -DisplayName "Administrator Filter Permission"
}

Function Remove-AttributeAndBinding {
<#
.SYNOPSIS
Remove an attribute, attribute binding, MPR-config, filter permission, ... from the FIM Portal schema.

.DESCRIPTION
Remove an attribute, attribute binding, MPR-config, filter permission, ... from the FIM Portal schema.

.EXAMPLE
Remove-AttributeAndBinding -AttrName Visa
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name,
		
		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	if($ObjectType -eq "Person"){
		Remove-AttributeFromMPR -AttrName $Name -MprName "Administration: Administrators can read and update Users"
		Remove-AttributeFromMPR -AttrName $Name -MprName "Synchronization: Synchronization account controls users it synchronizes"
	}
	Remove-AttributeFromFilterScope -Attribute $attrId -DisplayName "Administrator Filter Permission"
	Remove-AttributeBinding $Name
	Remove-Attribute $Name
}

