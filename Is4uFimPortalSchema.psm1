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
Import-Module .\Is4uFimPortal.psm1

Function New-Attribute
{
<#
	.SYNOPSIS
	Create a new attribute in the FIM Portal schema.

	.DESCRIPTION
	Create a new attribute in the FIM Portal schema.

	.EXAMPLE
	New-Attribute -Name Visa -DisplayName Visa -Type String -MultiValued "False"
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

		[Parameter(Mandatory=$True)]
		[String]
		$MultiValued
	)
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Name", $Name)
	$changes.Add("DataType", $Type)
	$changes.Add("Multivalued", $MultiValued)
	New-FimImportObject -ObjectType AttributeTypeDescription -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $Name
	return $id
}

Function Remove-Attribute
{
<#
	.SYNOPSIS
	Remove an attribute from the FIM Portal schema.

	.DESCRIPTION
	Remove an attribute from the FIM Portal schema.

	.EXAMPLE
	Remove-Attribute -AttrName Visa
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name
	)
	$anchor = @{"Name"=$Name}
	New-FimImportObject -ObjectType AttributeTypeDescription -State Delete -AnchorPairs $anchor -ApplyNow
}

Function New-AttributeBinding
{
<#
	.SYNOPSIS
	Create a new attribute binding in the FIM Portal schema.

	.DESCRIPTION
	Create a new attribute binding in the FIM Portal schema.

	.EXAMPLE
	New-AttributeBinding -AttrName Visa -DisplayName "Visa Card Number" -ObjectType Person
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttrName, 
	
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName, 
	
		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	$attr = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttrName
	$changes = @{}
	$changes.Add("Required", $false)
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("BoundAttributeType", $attr)
	$changes.Add("BoundObjectType", $ObjectType)
	New-FimImportObject -ObjectType BindingDescription -State Create -Changes $changes -ApplyNow
}

Function Remove-AttributeBinding
{
<#
	.SYNOPSIS
	Remove an attribute binding from the FIM Portal schema.

	.DESCRIPTION
	Remove an attribute binding from the FIM Portal schema.

	.EXAMPLE
	Remove-AttributeBinding -AttrName Visa
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name
	)
	$attr = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name
	$anchor = @{"BoundAttributeType"=$attr}
	New-FimImportObject -ObjectType BindingDescription -State Delete -AnchorPairs $anchor -ApplyNow
}

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
		[String]
		$MultiValued = "False",
		
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

Function Import-SchemaExtensions {
<#
	.SYNOPSIS
	Create new attributes and bindings based on data in given CSV file.

	.DESCRIPTION
	Create new attributes and bindings based on data in given CSV file.

	.EXAMPLE
	Import-SchemaExtensions -CsvFile ".\SchemaExtensions.csv"
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$CsvFile
	)
	$csv = Import-Csv $CsvFile
	ForEach ($entry in $csv) {
		New-AttributeAndBinding -Name $entry.SystemName -DisplayName $entry.DisplayName -Type $entry.DataType -MultiValued $entry.MultiValued -ObjectType $entry.ObjectType
	}
}

Function New-ObjectType
{
<#
	.SYNOPSIS
	Create a new object type in the FIM Portal schema.

	.DESCRIPTION
	Create a new object type in the FIM Portal schema.

	.EXAMPLE
	New-ObjectType -Name Department -DisplayName Department -Description Department
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
		$Description
	)
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Name", $Name)
	$changes.Add("Description", $Description)
	New-FimImportObject -ObjectType ObjectTypeDescription -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $Name
	return $id
}

Function Update-ObjectType
{
<#
	.SYNOPSIS
	Update the object type in the FIM Portal schema.

	.DESCRIPTION
	Update the object type in the FIM Portal schema.

	.EXAMPLE
	Update-ObjectType -Name Department -DisplayName Department -Description Department
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
		$Description
	)
	$anchor = @{'Name' = $name}
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Description", $Description)
	New-FimImportObject -ObjectType ObjectTypeDescription -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $Name
	return $id
}