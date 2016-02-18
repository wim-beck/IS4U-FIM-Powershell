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
if(@(Get-PSSnapin | Where-Object {$_.Name -eq "FIMAutomation"}).Count -eq 0) {
	Add-PSSnapin FIMAutomation
}
Import-Module .\FimPowerShellModule.psm1
Add-TypeAccelerators -AssemblyName Microsoft.ResourceManagement -Class UniqueIdentifier

Function Get-DynamicGroupFilter {
<#
	.SYNOPSIS
	Get a report from the filters of dynamic groups in FIM.

	.DESCRIPTION
	Get a report from the filters of dynamic groups in FIM.

	.EXAMPLE
	Get-DynamicGroupFilter
#>
	param( 
		[Parameter(Mandatory=$False)] 
		[String]
		$OutputFile = "groupFilters.csv"
	)
	$chars = "\w\s\+&\-%\.,"
	[Regex] $is = "(?:^|\s)\((\w+) = '([$chars]+)'\)(?:$|\s)"
	[Regex] $isNot = "(?:^|\s)\(not\((\w+) = '([$chars]+)'\)(?:$|\s)"
	[Regex] $startsWith = "(?:^|\s)\(starts-with\((\w+), '([$chars]+)'\)(?:$|\s)"
	[Regex] $startsNotwith = "(?:^|\s)\(not\(starts-with\((\w+), '([$chars]+)'\)(?:$|\s)"
	[Regex] $endsWith = "(?:^|\s)\(ends-with\((\w+), '([$chars]+)'\)(?:$|\s)"
	[Regex] $endsNotWith = "(?:^|\s)\(not\(ends-with\((\w+), '([$chars]+)'\)(?:$|\s)"
	Write-Output "Name;Object;Attribute;Operation;Value;Filter" | Out-File $OutputFile
	Add-TypeAccelerators -AssemblyName System.Xml.Linq -Class XAttribute
	$groups = Export-FIMConfig -CustomConfig "/Group[MembershipLocked='true']" -OnlyBaseResources
	foreach($g in $groups) {
		$group = Convert-FimExportToPSObject $g
		[XElement] $filter = New-Object XElement($group.Filter)
		if($filter.Value -match "\/(.+)\[(.+)\]") {
			$name = $group.DisplayName
			$obj = $Matches[1]
			$criteria0 = $Matches[2]
			$criteria = $criteria0 -replace "\s*\(+\s*","("
			$criteria = $criteria -replace "\s*\)+\s*",")"
			$criteria = $criteria -replace "\s*=\s*"," = "
			$criteria = $criteria -replace "\)\s*and\s*\(",") and ("
			$criteria = $criteria -replace "\)\s*or\s*\(",") or ("
			$criteria = $criteria -replace "\s*,\s*",", "
			Write-Output "$name;$obj;;;;$criteria0" | Out-File $OutputFile -Append
			$matches = $is.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;is;$val;" | Out-File $OutputFile -Append
			}
			$matches = $isNot.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;is not;$val;" | Out-File $OutputFile -Append
			}
			$matches = $startsWith.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;starts with;$val;" | Out-File $OutputFile -Append
			}
			$matches = $startsNotwith.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;starts not with;$val;" | Out-File $OutputFile -Append
			}
			$matches = $endsWith.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;ends with;$val;" | Out-File $OutputFile -Append
			}
			$matches = $endsNotWith.Matches($criteria);
			foreach($match in $matches) {
				$attr = $match.Groups[1].Value
				$val = $match.Groups[2].Value
				Write-Output "$name;;$attr;ends not with;$val;" | Out-File $OutputFile -Append
			}
		} else {
			Write-Host "Filter did not match for group" $group.DisplayName
		}
	}
}

Function Remove-ObjectsFromPortal {
<#
	.SYNOPSIS
	Removes all objects of a certain type from the FIM Portal.

	.DESCRIPTION
	Removes all objects of a certain type from the FIM Portal.

	.EXAMPLE
	Remove-ObjectsFromPortal -ObjectType "Person"
#>
	param(
		[Parameter(Mandatory=$False)] 
		[String]
		$ObjectType="Person"
	)
	$specialUsers = ("fb89aefa-5ea1-47f1-8890-abe7797d6497","7fb2b853-24f0-4498-9534-4e10589723c4")
	Write-Host "Start exporting objects.."
	$objects = Export-FIMConfig -CustomConfig "/$ObjectType" -OnlyBaseResources
	Write-Host "Start deleting objects.."
	foreach($entry in $objects) {
		$user = Convert-FimExportToPSObject $entry
		$objId = $user.ObjectID.split(':')[2]
		if($specialUsers.Contains($objId)) {
			Write-Host "Do not delete account with id '$objId'"
		} else {
			Remove-FimObject -AnchorName ObjectID -AnchorValue $objId -ObjectType $ObjectType
		}
	}
}

Function Enable-PortalAccess {
<#
	.SYNOPSIS
	Enables all MPR's required for users to access the FIM Portal.

	.DESCRIPTION
	Enables all MPR's required for users to access the FIM Portal.
#>
	Enable-Mpr "General: Users can read non-administrative configuration resources"
	Enable-Mpr "User management: Users can read attributes of their own"
}

Function Set-ObjectSid {
<#
	.SYNOPSIS
	Set the object sid of a given FIM portal user to the correct value.

	.DESCRIPTION
	Set the object sid of a given FIM portal user to the correct value.

	.EXAMPLE
	Set-ObjectSid -AccountName mim.installer -Domain IS4U
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AccountName,
		
		[Parameter(Mandatory=$False)]
		[String]
		$Domain
	)
	$objExists = $False
	if($Domain -ne "" -and (Test-ObjectExists -Filter "/Person[AccountName='$AccountName' and Domain='$Domain']")) {
		$objExists = $True
		$object = Get-FimObject -Filter "/Person[AccountName='$AccountName' and Domain='$Domain']"
	} elseif(Test-ObjectExists -Value $AccountName) {
		$objExists = $True
		$object = Get-FimObject -Value $AccountName
	}
	if($objExists) {
		Write-Host " -Reading account information"
		$accountSid = Get-ObjectSid $AccountName $Domain
		[UniqueIdentifier] $objectId = $object.ObjectID
		$anchor = @{'ObjectID' = $objectId.Value}
		$changes = @{"ObjectSID" = $accountSid}
		Write-Host " -Writing Account information ObjectSID = $accountSid"
		New-FimImportObject -ObjectType Person -State Put -Anchor $anchor -Changes $changes -ApplyNow
	} else {
		Throw "Cannot find an account with name '$AccountName' and domain '$Domain' or multiple matches found."
	}
}

Function New-Workflow {
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

Function Update-Workflow {
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

Function Remove-Workflow {
<#
	.SYNOPSIS
	Remove a workflow

	.DESCRIPTION
	Remove a workflow
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType WorkflowDefinition
}

Function New-Mpr {
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
		$PrincipalSetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$SetId,
		
		[Parameter(Mandatory=$True)]
		[Array]
		$ActionType,

		[Parameter(Mandatory=$True)]
		[Array]
		$ActionParameter,
		
		[Parameter(Mandatory=$True)]
		[String]
		[ValidateScript({("True", "False") -contains $_})]
		$GrantRight,
		
		[Parameter(Mandatory=$True)]
		[String]
		$ManagementPolicyRuleType,
		
		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$AuthWfId,

		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$ActionWfId,

		[Parameter(Mandatory=$False)]
		[String]
		[ValidateScript({("True", "False") -contains $_})]
		$Disabled = "False",

		[Parameter(Mandatory=$False)]
		[String]
		$Description
	)
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'DisplayName' -AttributeValue $DisplayName
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Description' -AttributeValue $Description
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'PrincipalSet' -AttributeValue $PrincipalSetId.ToString()
	foreach($param in $ActionParameter) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionParameter' -AttributeValue $param
	}
	foreach($action in $ActionType) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionType' -AttributeValue $action
	}
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ManagementPolicyRuleType' -AttributeValue $ManagementPolicyRuleType
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'GrantRight' -AttributeValue $GrantRight
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Disabled' -AttributeValue $Disabled
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceCurrentSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceFinalSet' -AttributeValue $SetId.ToString()
	if($ActionWfId -ne $null) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionWorkflowDefinition' -AttributeValue $ActionWfId.ToString()
	}
	if($AuthWfId -ne $null) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'AuthenticationWorkflowDefinition' -AttributeValue $AuthWfId.ToString()
	}
	New-FimImportObject -ObjectType ManagementPolicyRule -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ManagementPolicyRule -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Update-Mpr {
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
		$PrincipalSetId,
		
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$SetId,

		[Parameter(Mandatory=$True)]
		[Array]
		$ActionType,

		[Parameter(Mandatory=$True)]
		[Array]
		$ActionParameter,
		
		[Parameter(Mandatory=$True)]
		[String]
		[ValidateScript({("True", "False") -contains $_})]
		$GrantRight,
		
		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$AuthWfId,

		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$ActionWfId,

		[Parameter(Mandatory=$False)]
		[String]
		[ValidateScript({("True", "False") -contains $_})]
		$Disabled = "False",

		[Parameter(Mandatory=$False)]
		[String]
		$Description
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Description' -AttributeValue $Description
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'PrincipalSet' -AttributeValue $PrincipalSetId.ToString()
	foreach($param in $ActionParameter) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionParameter' -AttributeValue $param
	}
	foreach($action in $ActionType) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionType' -AttributeValue $action
	}
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'GrantRight' -AttributeValue $GrantRight
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Disabled' -AttributeValue $Disabled
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceCurrentSet' -AttributeValue $SetId.ToString()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ResourceFinalSet' -AttributeValue $SetId.ToString()
	if($ActionWfId -ne $null) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'ActionWorkflowDefinition' -AttributeValue $ActionWfId.ToString()
	}
	if($AuthWfId -ne $null) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'AuthenticationWorkflowDefinition' -AttributeValue $AuthWfId.ToString()
	}
	New-FimImportObject -ObjectType ManagementPolicyRule -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType ManagementPolicyRule -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Enable-Mpr {
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

Function Disable-Mpr {
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

Function Add-AttributeToMPR {
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

Function Remove-AttributeFromMPR {
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

Function Remove-Mpr {
<#
	.SYNOPSIS
	Remove a management policy rule

	.DESCRIPTION
	Remove a management policy rule
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType ManagementPolicyRule
}

Function New-Set {
<#
	.SYNOPSIS
	Create a new set.

	.DESCRIPTION
	Create a new set.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Condition,

		[Parameter(Mandatory=$False)]
		[String]
		$Description
	)
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Description", $Description)
	$filter = Get-Filter $Condition
	$changes.Add("Filter", $filter)
	New-FimImportObject -ObjectType Set -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Update-Set {
<#
	.SYNOPSIS
	Update a set.

	.DESCRIPTION
	Update a set.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Condition,

		[Parameter(Mandatory=$False)]
		[String]
		$Description
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$filter = Get-Filter $Condition
	$changes = @{}
	$changes.Add("Filter", $filter)
	$changes.Add("Description", $Description)
	New-FimImportObject -ObjectType Set -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue $DisplayName
	return $id
}

Function Add-ObjectToSet {
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

Function Remove-Set {
<#
	.SYNOPSIS
	Remove a set.

	.DESCRIPTION
	Remove a set.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType Set
}

Function Get-Filter {
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

Function Test-ObjectExists {
<#
	.SYNOPSIS
	Check if a given object exists in the FIM portal.

	.DESCRIPTION
	Check if a given object exists in the FIM portal.
	Returns false if no or multiple matches are found.

	.EXAMPLE
	Test-ObjectExists -Value is4u.admin -Attribute AccountName -ObjectType Person	
#>
	param(
		[Parameter(Mandatory=$False)]
		[String]
		$Value,
	
		[Parameter(Mandatory=$false)] 
		[String]
		$Attribute = "AccountName",
	
		[Parameter(Mandatory=$False)] 
		[String]
		$ObjectType = "Person",

		[Parameter(Mandatory=$False)] 
		[String]
		$Filter
	)
	$searchFilter = $Filter
	if($Value -ne "") {
		$searchFilter = "/$ObjectType[$Attribute='$Value']"
	}
	if($searchFilter -eq "") {
		Throw "No search criteria specified"
	}
	$obj = Export-FIMConfig -CustomConfig $searchFilter -OnlyBaseResources
	if ($obj -ne $null) {
		if($obj.GetType().Name -ne "ExportObject") {
			Throw "Multiple matches found for filter '$searchFilter'"
		}
		return $true
	}
	return $false
}

Function Get-FimObject {
<#
	.SYNOPSIS
	Retrieve an object from the FIM portal.

	.DESCRIPTION
	Search for an object in the FIM portal and display his properties. This function searches Person objects
	by AccountName by default. It is possible to provide another object type or search attribute 
	by providing the Attribute and ObjectType parameters.

	.EXAMPLE
	Get-FimObject is4u.admin

	Get-FimObject -Attribute DisplayName -Value "IS4U Administrator"

	Get-FimObject -Attribute DisplayName -Value Administrators -ObjectType Set
#>
	param(
		[Parameter(Mandatory=$False)]
		[String]
		$Value,
	
		[Parameter(Mandatory=$False)] 
		[String]
		$Attribute = "AccountName",
	
		[Parameter(Mandatory=$False)] 
		[String]
		$ObjectType = "Person",

		[Parameter(Mandatory=$False)] 
		[String]
		$Filter
	)
	$searchFilter = $Filter
	if($Value -ne "") {
		$searchFilter = "/$ObjectType[$Attribute='$Value']"
	}
	if($searchFilter -eq "") {
		Throw "No search criteria specified"
	}
	$obj = Export-FIMConfig -CustomConfig $searchFilter -OnlyBaseResources
	if($obj.GetType().Name -ne "ExportObject") {
		Throw "Multiple matches found for filter '$searchFilter'"
	}
	return (Convert-FimExportToPSObject $obj)
}

Function Remove-FimObject {
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
	New-FimImportObject -ObjectType $ObjectType -State Delete -Anchor $anchor -ApplyNow
}

Function Add-ObjectToSynchronizationFilter {
<#
	.SYNOPSIS
	Adds an object type to the synchronization filter.

	.DESCRIPTION
	Adds an object type to the synchronization filter.

	.EXAMPLE
	[UniqueIdentifier] $objectTypeId = New-ObjectType -Name Department -DisplayName Department -Description Department
	Add-ObjectToSynchronizationFilter -ObjectId $objectTypeId
#>
	param(
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$ObjectId,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Synchronization Filter"
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Add' -AttributeName 'SynchronizeObjectType' -AttributeValue $ObjectId.ToString())
	New-FimImportObject -ObjectType SynchronizationFilter -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-ObjectFromSynchronizationFilter {
<#
	.SYNOPSIS
	Removes an object type from the synchronization filter.

	.DESCRIPTION
	Removes an object type from the synchronization filter.

	.EXAMPLE
	[UniqueIdentifier] $objectTypeId = New-ObjectType -Name Department -DisplayName Department -Description Department
	Remove-ObjectFromSynchronizationFilter -ObjectId $objectTypeId
#>
	param(
		[Parameter(Mandatory=$True)]
		[UniqueIdentifier]
		$ObjectId,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Synchronization Filter"
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Delete' -AttributeName 'SynchronizeObjectType' -AttributeValue $ObjectId.ToString())
	New-FimImportObject -ObjectType SynchronizationFilter -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Add-AttributeToFilterScope {
<#
	.SYNOPSIS
	Adds an attribute to the filter scope.

	.DESCRIPTION
	Adds an attribute to the filter scope.

	.EXAMPLE
	Add-AttributeToFilterScope -AttributeName Visa -DisplayName "Administrator Filter Permission"
#>
	param(
		[Parameter(Mandatory=$False)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$AttributeId,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Administrator Filter Permission"
	)
	if($AttributeId -eq $null) {
		$attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttributeName
	} else {
		$attrId = $AttributeId
	}
	if($attrId -eq "") {
		Throw "No attribute specified"
	}
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Add' -AttributeName 'AllowedAttributes' -AttributeValue $attrId)
	New-FimImportObject -ObjectType FilterScope -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-AttributeFromFilterScope {
<#
	.SYNOPSIS
	Removes an attribute from the filter scope.

	.DESCRIPTION
	Removes an attribute from the filter scope.

	.EXAMPLE
	Remove-AttributeFromFilterScope -AttributeName Visa -DisplayName "Administrator Filter Permission"
#>
	param(
		[Parameter(Mandatory=$False)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$False)]
		[UniqueIdentifier]
		$AttributeId,

		[Parameter(Mandatory=$False)]
		[String]
		$DisplayName = "Administrator Filter Permission"
	)
	if($AttributeId -eq $null) {
		$attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttributeName
	} else {
		$attrId = $AttributeId
	}
	if($attrId -eq "") {
		Throw "No attribute specified"
	}
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @(New-FimImportChange -Operation 'Delete' -AttributeName 'AllowedAttributes' -AttributeValue $attrId)
	New-FimImportObject -ObjectType FilterScope -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function New-SearchScope {
<#
	.SYNOPSIS
	Create a new search scope.

	.DESCRIPTION
	Create a new search scope.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Order,

		[Parameter(Mandatory=$True)]
		[String]
		$ObjectType,

		[Parameter(Mandatory=$True)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$True)]
		[String]
		$Context,

		[Parameter(Mandatory=$True)]
		[String]
		$Column,

		[Parameter(Mandatory=$True)]
		[Array]
		$UsageKeyWords
	)
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'DisplayName' -AttributeValue $DisplayName
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Order' -AttributeValue $Order
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScope' -AttributeValue "/$ObjectType"
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'SearchScopeContext' -AttributeValue $Context
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeColumn' -AttributeValue $Column
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeResultObjectType' -AttributeValue $ObjectType
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeTargetURL' -AttributeValue "~/IdentityManagement/aspx/customized/CustomizedObjects.aspx?type=$ObjectType&display=$ObjectType"
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'IsConfigurationType' -AttributeValue $True
	foreach($keyword in $UsageKeyWords){
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'UsageKeyword' -AttributeValue $keyword
	}
	New-FimImportObject -ObjectType SearchScopeConfiguration -State Create -Changes $changes -ApplyNow
}

Function Update-SearchScope {
<#
	.SYNOPSIS
	Update a search scope.

	.DESCRIPTION
	Update a search scope.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Order,

		[Parameter(Mandatory=$True)]
		[String]
		$ObjectType,

		[Parameter(Mandatory=$True)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$True)]
		[String]
		$Context,

		[Parameter(Mandatory=$True)]
		[String]
		$Column,

		[Parameter(Mandatory=$True)]
		[Array]
		$UsageKeyWords
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Order' -AttributeValue $Order
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScope' -AttributeValue "/$ObjectType"
	$changes += New-FimImportChange -Operation 'Add' -AttributeName 'SearchScopeContext' -AttributeValue $Context
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeColumn' -AttributeValue $Column
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeResultObjectType' -AttributeValue $ObjectType
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'SearchScopeTargetURL' -AttributeValue "~/IdentityManagement/aspx/customized/CustomizedObjects.aspx?type=$ObjectType&display=$ObjectType"
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'IsConfigurationType' -AttributeValue $True
	foreach($keyword in $UsageKeyWords){
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'UsageKeyword' -AttributeValue $keyword
	}
	New-FimImportObject -ObjectType SearchScopeConfiguration -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-SearchScope {
<#
	.SYNOPSIS
	Remove a search scope.

	.DESCRIPTION
	Remove a search scope.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType SearchScopeConfiguration
}

Function New-NavigationBar {
<#
	.SYNOPSIS
	Create a new navigation bar.

	.DESCRIPTION
	Create a new navigation bar.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Order,

		[Parameter(Mandatory=$True)]
		[String]
		$ParentOrder,

		[Parameter(Mandatory=$True)]
		[String]
		$ObjectType,

		[Parameter(Mandatory=$True)]
		[Array]
		$UsageKeyWords
	)
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'DisplayName' -AttributeValue $DisplayName
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'NavigationUrl' -AttributeValue "~/IdentityManagement/aspx/customized/CustomizedObjects.aspx?type=$ObjectType&display=$ObjectType"
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Order' -AttributeValue $Order
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ParentOrder' -AttributeValue $ParentOrder
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'IsConfigurationType' -AttributeValue $True
	foreach($keyword in $UsageKeyWords) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'UsageKeyword' -AttributeValue $keyword
	}
	New-FimImportObject -ObjectType NavigationBarConfiguration -State Create -Changes $changes -ApplyNow
}

Function Update-NavigationBar {
<#
	.SYNOPSIS
	Update a navigation bar.

	.DESCRIPTION
	Update a navigation bar.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$Order,

		[Parameter(Mandatory=$True)]
		[String]
		$ParentOrder,

		[Parameter(Mandatory=$True)]
		[String]
		$ObjectType,

		[Parameter(Mandatory=$True)]
		[Array]
		$UsageKeyWords
	)
	$anchor = @{'DisplayName' = $DisplayName}
	$changes = @()
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'NavigationUrl' -AttributeValue "~/IdentityManagement/aspx/customized/CustomizedObjects.aspx?type=$ObjectType&display=$ObjectType"
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'Order' -AttributeValue $Order
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'ParentOrder' -AttributeValue $ParentOrder
	$changes += New-FimImportChange -Operation 'None' -AttributeName 'IsConfigurationType' -AttributeValue $True
	foreach($keyword in $UsageKeyWords) {
		$changes += New-FimImportChange -Operation 'Add' -AttributeName 'UsageKeyword' -AttributeValue $keyword
	}
	New-FimImportObject -ObjectType NavigationBarConfiguration -State Put -Anchor $anchor -Changes $changes -ApplyNow
}

Function Remove-NavigationBar {
<#
	.SYNOPSIS
	Remove a navigation bar.

	.DESCRIPTION
	Remove a navigation bar.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType NavigationBarConfiguration
}