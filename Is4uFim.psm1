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
if(@(Get-PSSnapin | Where-Object {$_.Name -eq "FIMAutomation"}).Count -eq 0) {
	Add-PSSnapin FIMAutomation
}
Import-Module .\FimPowerShellModule.psm1
Import-Module .\Is4u.psm1
Add-TypeAccelerators -AssemblyName Microsoft.ResourceManagement -Class UniqueIdentifier

Function Add-ObjectToSet
{
<#
.SYNOPSIS
Add an object to the explicit members of a set.

.DESCRIPTION
Add an object to the explicit members of a set.

.EXAMPLE
Add-ObjectToSet -DisplayName Administrators -ObjectId 7fb2b853-24f0-4498-9534-4e10589723c4
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$ObjectId
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @()
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ExplicitMember' -AttributeValue $ObjectId.ToString()
	New-FimImportObject -ObjectType Set -State Put -Anchor $anchor -Changes $changes -ApplyNow	
}

Function New-Workflow
{
<#
.SYNOPSIS
Create a new workflow.

.DESCRIPTION
Create a new workflow.

.EXAMPLE
New-Workflow -DisplayName "IS4U: This is not a workflow" -Xoml <XOML> -RequestPhase Action
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,
		
		[Parameter(Mandatory=$True)]
		[String]
		$Xoml,

		[Parameter(Mandatory=$True)]
		[String]
		[ValidateScript({("Authorization", "Authentication", "Action") -contains $_})]
		$RequestPhase
	)

	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("RequestPhase", $RequestPhase)
	$changes.Add("XOML", $Xoml)
	New-FimImportObject -ObjectType WorkflowDefinition -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType WorkflowDefinition -AttributeName DisplayName -AttributeValue $displayName
	return $id
}

Function Update-Workflow
{
<#
.SYNOPSIS
Update an existing workflow.

.DESCRIPTION
Update an existing workflow with a new xoml definition.

.EXAMPLE
New-Workflow -DisplayName "IS4U: This is not a workflow" -Xoml <XOML>
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Xoml
	)

	$anchor = @{'DisplayName' = $displayName}
	$changes = @{}
	$changes.Add("XOML", $Xoml)
	New-FimImportObject -ObjectType WorkflowDefinition -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType WorkflowDefinition -AttributeName DisplayName -AttributeValue $displayName
	return $id
}

Function New-Mpr
{
<#
.SYNOPSIS
Create a new management policy rule.

.DESCRIPTION
Create a new management policy rule.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$ActionWfId,

		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$PrincipalSetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$SetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$AuthWfId,
		
		[Parameter(Mandatory=$False)]
		[String]
		$ActionType = "Modify",

		[Parameter(Mandatory=$False)]
		[String]
		$ActionParameter = "ResetPassword",
		
		[Parameter(Mandatory=$False)]
		[String]
		$ManagementPolicyRuleType = "Request",

		[Parameter(Mandatory=$False)]
		[Boolean]
		$GrantRight = $True,
		
		[Parameter(Mandatory=$False)]
		[Boolean]
		$Disabled = $False
	)
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'DisplayName' -AttributeValue $DisplayName
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'PrincipalSet' -AttributeValue $PrincipalSetId.ToString()
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionParameter' -AttributeValue $ActionParameter
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionType' -AttributeValue $ActionType
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionWorkflowDefinition' -AttributeValue $ActionWfId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ManagementPolicyRuleType' -AttributeValue $ManagementPolicyRuleType
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'GrantRight' -AttributeValue $GrantRight
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Disabled' -AttributeValue $Disabled
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceCurrentSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceFinalSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'AuthenticationWorkflowDefinition' -AttributeValue $AuthWfId.ToString()
	New-FimImportObject -ObjectType ManagementPolicyRule -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ManagementPolicyRule -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Update-Mpr
{
<#
.SYNOPSIS
Update management policy rule

.DESCRIPTION
Update management policy rule
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$ActionWfId,

		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$PrincipalSetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$SetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$AuthWfId,

		[Parameter(Mandatory=$False)]
		[String]
		$ActionType = "Modify",

		[Parameter(Mandatory=$False)]
		[String]
		$ActionParameter = "ResetPassword",
		
		[Parameter(Mandatory=$False)]
		[Boolean]
		$GrantRight = $True,
		
		[Parameter(Mandatory=$False)]
		[Boolean]
		$Disabled = $False
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'PrincipalSet' -AttributeValue $PrincipalSetId.ToString()
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionParameter' -AttributeValue $ActionParameter
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionType' -AttributeValue $ActionType
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionWorkflowDefinition' -AttributeValue $ActionWfId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'GrantRight' -AttributeValue $GrantRight
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Disabled' -AttributeValue $Disabled
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceCurrentSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceFinalSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'AuthenticationWorkflowDefinition' -AttributeValue $AuthWfId.ToString()
	New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ManagementPolicyRule -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function New-Set
{
<#
.SYNOPSIS
Create a new set.

.DESCRIPTION
Create a new set.
#>
	param(
		[Parameter(Mandatory=$True)]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		$Condition
	)
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$filter = Get-Filter $Condition
	$changes.Add("Filter", $filter)
	New-FimImportObject -ObjectType Set -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Update-Set
{
<#
.SYNOPSIS
Update a set.

.DESCRIPTION
Update a set.
#>
	param(
		[Parameter(Mandatory=$True)]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		$Condition
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$filter = Get-Filter $Condition
	$changes = @{'Filter' = $filter}
	New-FimImportObject -ObjectType Set -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Get-Filter
{
<#
.SYNOPSIS
Constructs a filter you can use in sets and dynamic groups for the given XPath filter.

.DESCRIPTION
Constructs a filter you can use in sets and dynamic groups for the given XPath filter.
#>
	param(
		[Parameter(Mandatory=$True)]
		$XPathFilter
	)
	return "<Filter xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema' Dialect='http://schemas.microsoft.com/2006/11/XPathFilterDialect' xmlns='http://schemas.xmlsoap.org/ws/2004/09/enumeration'>{0}</Filter>" -F $XPathFilter
}

Function Enable-Mpr
{
<#
.SYNOPSIS
Enables a MPR.

.DESCRIPTION
Enables the given management policy rule.

.EXAMPLE
PS C:\$ Enable-Mpr "Administration: Administrators can read and update Users"
#>
	param(
		[Parameter(Mandatory=$True)]
		$DisplayName
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @{}
	$changes.Add("Disabled", $false)
	New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Disable-Mpr
{
<#
.SYNOPSIS
Disables a MPR.

.DESCRIPTION
Disables the given management policy rule.

.EXAMPLE
PS C:\$ Disable-Mpr "Administration: Administrators can read and update Users"
#>
	param(
		[Parameter(Mandatory=$True)]
		$DisplayName
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @{}
	$changes.Add("Disabled", $true)
	New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Test-ObjectExists
{
<#
.SYNOPSIS
Check if a given object exists in the FIM portal.

.DESCRIPTION
Check if a given object exists in the FIM portal.

.EXAMPLE
Test-ObjectExists -Value is4u.admin -Attribute AccountName -ObjectType Person	
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Value,
	
		[Parameter(Mandatory=$false)] 
		[String]
		$Attribute = "AccountName",
	
		[Parameter(Mandatory=$false)] 
		[String]
		$ObjectType = "Person"	
	)
	$obj = Export-FIMConfig -CustomConfig "/$ObjectType[$Attribute='$Value']" -OnlyBaseResources
	$exists = $obj -ne $null
	return $exists
}

Function Get-FimObject
{
<#
.SYNOPSIS
Retrieve an object from the FIM portal.

.DESCRIPTION
Search for an object in the FIM portal and display his properties. This function searches Person objects
by AccountName by default. It is possible to provide another object type or search attribute 
by providing the Attribute and ObjectType parameters.

.EXAMPLE
PS C:\$ Get-FimObject is4u.admin

PS C:\$ Get-FimObject -Attribute DisplayName -Value "IS4U Administrator"

PS C:\$ Get-FimObject -Attribute DisplayName -Value Administrators -ObjectType Set
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Value,
	
		[Parameter(Mandatory=$false)] 
		[String]
		$Attribute = "AccountName",
	
		[Parameter(Mandatory=$false)] 
		[String]
		$ObjectType = "Person"	
	)
	$obj = Export-FIMConfig -CustomConfig "/$ObjectType[$Attribute='$Value']" -OnlyBaseResources | Convert-FimExportToPSObject
	return $obj
}

Function New-Attribute
{
<#
.SYNOPSIS
Create a new attribute in the FIM Portal schema.

.DESCRIPTION
Create a new attribute in the FIM Portal schema.

.EXAMPLE
New-Attribute -Name Visa -Type String -MultiValue $false
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

Function Add-AttributeToMPR
{
<#
.SYNOPSIS
Adds an attribute to the list of selected attributes in the scope of the management policy rule.

.DESCRIPTION
Adds an attribute to the list of selected attributes in the scope of the management policy rule.

.EXAMPLE
Add-AttributeToMPR -AttrName Visa -MprName "Administration: Administrators can read and update Users"
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttrName,
		
		[Parameter(Mandatory=$True)]
		[String]
		$MprName
	)
    $anchor = @{'DisplayName' = $MprName}
    $changes = @(New-FimImportChange -Operation 'Add' -AttributeName 'ActionParameter' -AttributeValue $AttrName)
    New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-AttributeFromMPR
{
<#
.SYNOPSIS
Removes an attribute from the list of selected attributes in the scope of the management policy rule.

.DESCRIPTION
Removes an attribute from the list of selected attributes in the scope of the management policy rule.

.EXAMPLE
Remove-AttributeFromMPR -AttrName Visa -MprName "Administration: Administrators can read and update Users"
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttrName,
		
		[Parameter(Mandatory=$True)]
		[String]
		$MprName
	)
    $anchor = @{'DisplayName' = $MprName}
    $changes = @(New-FimImportChange -Operation 'Delete' -AttributeName 'ActionParameter' -AttributeValue $AttrName)
    New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Add-AttributeToFilterScope
{
<#
.SYNOPSIS
Adds an attribute to the filter scope.

.DESCRIPTION
Adds an attribute to the filter scope.

.EXAMPLE
[UniqueIdentifier] $attrId = New-Attribute -Name TestAttribute -DisplayName "Test Attribute" -Type String
Add-AttributeToFilterScope -Attribute $attrId -DisplayName "Administrator Filter Permission"
#>
	param(
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$Attribute,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Administrator Filter Permission"
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Add' -AttributeName 'AllowedAttributes' -AttributeValue $Attribute.ToString())
	New-FimImportObject -ObjectType FilterScope -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-AttributeFromFilterScope
{
<#
.SYNOPSIS
Removes an attribute from the filter scope.

.DESCRIPTION
Removes an attribute from the filter scope.

.EXAMPLE
[UniqueIdentifier] $attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue TestAttribute
Remove-AttributeFromFilterScope -Attribute $attrId -DisplayName "Administrator Filter Permission"
#>
	param(
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$Attribute,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Administrator Filter Permission"
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Delete' -AttributeName 'AllowedAttributes' -AttributeValue $Attribute.ToString())
	New-FimImportObject -ObjectType FilterScope -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-FimObject
{
<#
.SYNOPSIS
Delete an object.

.DESCRIPTION
Delete an object given the object type, anchor attribute and anchor value.

.EXAMPLE
Remove-FimObject -AnchorName AccountName -AnchorValue mickey.mouse -ObjectType Person
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AnchorName,

		[Parameter(Mandatory=$True)]
		[String]
		$AnchorValue,
		
		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	$anchor = @{$AnchorName = $AnchorValue}
	New-FimImportObject -ObjectType $ObjectType -State Delete -AnchorPairs $anchor -ApplyNow
}