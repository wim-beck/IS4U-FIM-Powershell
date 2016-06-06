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

Function New-Attribute {
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

		[Parameter(Mandatory=$False)]
		[String]
		$Description,

		[Parameter(Mandatory=$True)]
		[String]
		[ValidateScript({("String", "DateTime", "Integer", "Reference", "Boolean", "Text", "Binary") -ccontains $_})]
		$Type,

		[Parameter(Mandatory=$False)]
		[String]
		$MultiValued = "False"
	)
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Name", $Name)
	$changes.Add("Description", $Description)
	$changes.Add("DataType", $Type)
	$changes.Add("Multivalued", $MultiValued)
	New-FimImportObject -ObjectType AttributeTypeDescription -State Create -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $Name
	return $id
}

Function Update-Attribute {
<#
	.SYNOPSIS
	Update an attribute in the FIM Portal schema.

	.DESCRIPTION
	Update an attribute in the FIM Portal schema.

	.EXAMPLE
	Update-Attribute -Name Visa -DisplayName Visa -Description "Visa card number"
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name,

		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$False)]
		[String]
		$Description
	)
	$anchor = @{'Name' = $Name}
	$changes = @{}
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Description", $Description)
	New-FimImportObject -ObjectType AttributeTypeDescription -State Put -Anchor $anchor -Changes $changes -ApplyNow
	[GUID] $id = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $Name
	return $id
}

Function Remove-Attribute {
<#
	.SYNOPSIS
	Remove an attribute from the FIM Portal schema.

	.DESCRIPTION
	Remove an attribute from the FIM Portal schema.

	.EXAMPLE
	Remove-Attribute -Name Visa
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name
	)
	Remove-FimObject -AnchorName Name -AnchorValue $Name -ObjectType AttributeTypeDescription
}

Function New-Binding {
<#
	.SYNOPSIS
	Create a new attribute binding in the FIM Portal schema.

	.DESCRIPTION
	Create a new attribute binding in the FIM Portal schema.

	.EXAMPLE
	New-Binding -AttributeName Visa -DisplayName "Visa Card Number"

	.EXAMPLE
	New-Binding -AttributeName Visa -DisplayName "Visa Card Number" -Required $False -ObjectType Person
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttributeName,
	
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName, 

		[Parameter(Mandatory=$False)]
		[String]
		$Description, 
	
		[Parameter(Mandatory=$False)]
		[String]
		$Required = "False",

		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	$attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttributeName
	$objId = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $ObjectType
	$changes = @{}
	$changes.Add("Required", $Required)
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Description", $Description)
	$changes.Add("BoundAttributeType", $attrId)
	$changes.Add("BoundObjectType", $objId)
	New-FimImportObject -ObjectType BindingDescription -State Create -Changes $changes -ApplyNow
	$binding = Get-FimObject -Filter "/BindingDescription[BoundAttributeType='$attrId' and BoundObjectType='$objId']"
	[UniqueIdentifier] $id = $binding.ObjectID
	return $id.Value
}

Function Update-Binding {
<#
	.SYNOPSIS
	Update an attribute binding in the FIM Portal schema.

	.DESCRIPTION
	Update an attribute binding in the FIM Portal schema.

	.EXAMPLE
	Update-Binding -AttributeName Visa -DisplayName "Visa Card Number"

	.EXAMPLE
	Update-Binding -AttributeName Visa -DisplayName "Visa Card Number" -Required $False -ObjectType Person
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName, 

		[Parameter(Mandatory=$False)]
		[String]
		$Description, 
	
		[Parameter(Mandatory=$False)]
		[String]
		$Required = "False",

		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	$attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttributeName
	$objId = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $ObjectType
	$binding = Get-FimObject -Filter "/BindingDescription[BoundAttributeType='$attrId' and BoundObjectType='$objId']"
	[UniqueIdentifier] $id = $binding.ObjectID
	$anchor = @{"ObjectID" = $id.Value}
	$changes = @{}
	$changes.Add("Required", $Required)
	$changes.Add("DisplayName", $DisplayName)
	$changes.Add("Description", $Description)
	New-FimImportObject -ObjectType BindingDescription -State Put -Anchor $anchor -Changes $changes -ApplyNow
	return $id.Value
}

Function Remove-Binding {
<#
	.SYNOPSIS
	Remove an attribute binding from the FIM Portal schema.

	.DESCRIPTION
	Remove an attribute binding from the FIM Portal schema.

	.EXAMPLE
	Remove-Binding -AttributeName Visa
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$AttributeName,

		[Parameter(Mandatory=$False)]
		[String]
		$ObjectType = "Person"
	)
	$attrId = Get-FimObjectID -ObjectType AttributeTypeDescription -AttributeName Name -AttributeValue $AttributeName
	$objId = Get-FimObjectID -ObjectType ObjectTypeDescription -AttributeName Name -AttributeValue $ObjectType
	$binding = Get-FimObject -Filter "/BindingDescription[BoundAttributeType='$attrId' and BoundObjectType='$objId']"
	[UniqueIdentifier] $id = $binding.ObjectID
	Remove-FimObject -AnchorName ObjectID -AnchorValue $id.Value -ObjectType BindingDescription
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
	New-Binding -AttributeName $Name -DisplayName $DisplayName -ObjectType $ObjectType
	if($ObjectType -eq "Person") {
		Add-AttributeToMPR -AttrName $Name -MprName "Administration: Administrators can read and update Users"
		Add-AttributeToMPR -AttrName $Name -MprName "Synchronization: Synchronization account controls users it synchronizes"
	} elseif($ObjectType -eq "Group") {
		Add-AttributeToMPR -AttrName $Name -MprName "Group management: Group administrators can update group resources"
		Add-AttributeToMPR -AttrName $Name -MprName "Synchronization: Synchronization account controls group resources it synchronizes"
	}
	Add-AttributeToFilterScope -AttributeId $attrId -DisplayName "Administrator Filter Permission"
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
	if($ObjectType -eq "Person") {
		Remove-AttributeFromMPR -AttrName $Name -MprName "Administration: Administrators can read and update Users"
		Remove-AttributeFromMPR -AttrName $Name -MprName "Synchronization: Synchronization account controls users it synchronizes"
	}
	Remove-AttributeFromFilterScope -AttributeName $Name -DisplayName "Administrator Filter Permission"
	Remove-Binding -AttributeName $Name -ObjectType $ObjectType
	Remove-Attribute -Name $Name
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

		### TODO : add parameter for MPR
	)
	$csv = Import-Csv $CsvFile
	ForEach ($entry in $csv) {
		New-AttributeAndBinding -Name $entry.SystemName -DisplayName $entry.DisplayName -Type $entry.DataType -MultiValued $entry.MultiValued -ObjectType $entry.ObjectType
	}
}

Function New-ObjectType {
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

Function Update-ObjectType {
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

Function Remove-ObjectType {
<#
	.SYNOPSIS
	Remove an object type from the FIM Portal schema.

	.DESCRIPTION
	Remove an object type from the FIM Portal schema.

	.EXAMPLE
	Remove-ObjectType -Name Department
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$Name
	)
	Remove-FimObject -AnchorName Name -AnchorValue $Name -ObjectType ObjectTypeDescription
}

Function New-ObjectTypeConfiguration {
<#
	.SYNOPSIS
	Create a new object type configuration.

	.DESCRIPTION
	Create a new object type based on the given config file.
	This includes creating a new object type, a MPR, default attributes and bindings, 
	search scope, a navigation bar resource and configuring a synchronization fiter.

	.EXAMPLE
	New-ObjectTypeConfiguration -ConfigFile .\newObject.xml
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$ConfigFile
	)
	Add-TypeAccelerators -Assembly System.Xml.Linq -Class XAttribute
	$config = [XDocument]::Load((Join-Path $pwd $ConfigFile))
	$root = [XElement] $config.Root
	$objectConfig = [XElement] $root.Element("Object")
	
	#-------------------------------
	Write-Host "Create object type"
	#-------------------------------
	[UniqueIdentifier] $objectTypeId = [Guid]::Empty
	$objectName = $objectConfig.Attribute("SystemName").Value
	$objectDisplayName = $objectConfig.Attribute("DisplayName").Value
	$objectDescription = $objectConfig.Element("Description").Value
	$objectExists = Test-ObjectExists -Value $objectName -Attribute Name -ObjectType ObjectTypeDescription
	if($objectExists) {
		Write-Host "Update existing object type '$objectName'"
		$objectTypeId = Update-ObjectType -Name $objectName -DisplayName $objectDisplayName -Description $objectDescription
	} else {
		Write-Host "Create object type '$objectName'"
		$objectTypeId = New-ObjectType -Name $objectName -DisplayName $objectDisplayName -Description $objectDescription
	}

	#-------------------------------
	Write-Host "Add object to synchronization filter"
	#-------------------------------
	Add-ObjectToSynchronizationFilter -ObjectId $objectTypeId

	#-------------------------------
	Write-Host "Create Set"
	#-------------------------------
	[UniqueIdentifier] $setId = [Guid]::Empty
	$setConfig = [XElement] $objectConfig.Element("Set")
	$setDisplayName = $setConfig.Attribute("DisplayName").Value
	$setExists = Test-ObjectExists -Value $setDisplayName -Attribute DisplayName -ObjectType Set
	if($setExists) {
		Write-Host "Update existing set '$setDisplayName'"
		$setId = Update-Set -DisplayName $setDisplayName -Condition "/$objectName" -Description $setConfig.Attribute("Description").Value
	} else {
		Write-Host "Create set '$setDisplayName'"
		$setId = New-Set -DisplayName $setDisplayName -Condition "/$objectName" -Description $setConfig.Attribute("Description").Value
	}

	#-------------------------------
	Write-Host "Configure management policy rules"
	#-------------------------------
	$policy = $objectConfig.Element("Policy")
	foreach($mprConfig in $policy.Elements("MPR")) {
		$mprDisplayName = $mprConfig.Element("DisplayName").Value
		[UniqueIdentifier] $mprRequestors = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue $mprConfig.Element("Requestors").Value
		$mprDescription = $mprConfig.Element("Description").Value
		$mprType = $mprConfig.Attribute("Type").Value
		$mprGrant = $mprConfig.Attribute("GrantRight").Value
		$mprDisabled = $mprConfig.Attribute("Disabled").Value
		$mprActions = @()
		foreach($operation in $mprConfig.Element("Operations").Elements("Operation")) {
			$mprActions += $operation.Value
		}
		$mprAttr = @()
		foreach($attribute in $mprConfig.Element("Attributes").Elements("Attribute")) {
			$mprAttr += $attribute.Value
		}
		$mprExists = Test-ObjectExists -Value $mprDisplayName -Attribute DisplayName -ObjectType ManagementPolicyRule
		if($mprExists) {
			Write-Host "Update existing mpr '$mprDisplayName'"
			Update-Mpr -DisplayName $mprDisplayName -PrincipalSetId $mprRequestors -SetId $setId -ActionType $mprActions -ActionParameter $mprAttr -GrantRight $mprGrant -Description $mprDescription -Disabled $mprDisabled
		} else {
			Write-Host "Create mpr '$mprDisplayName'"
			New-Mpr -DisplayName $mprDisplayName -PrincipalSetId $mprRequestors -SetId $setId -ActionType $mprActions -ActionParameter $mprAttr -GrantRight $mprGrant -ManagementPolicyRuleType $mprType -Description $mprDescription -Disabled $mprDisabled
		}
	}

	#-------------------------------
	Write-Host "Create the reference attribute"
	#-------------------------------
	[UniqueIdentifier] $attrId = [Guid]::Empty
	$attrConfig = $objectConfig.Element("Attribute")
	$attrName = $attrConfig.Attribute("SystemName").Value
	$attrDisplayName = $attrConfig.Attribute("DisplayName").Value
	$attrDescription = $attrConfig.Attribute("Description").Value
	$attrMultivalued = $attrConfig.Element("Multivalued").Value
	$attrExists = Test-ObjectExists -Value $attrName -Attribute Name -ObjectType AttributeTypeDescription
	if($attrExists) {
		Write-Host "Update existing attribute '$attrName'"
		$attrId = Update-Attribute -Name $attrName -DisplayName $attrDisplayName -Description $attrDescription
	} else {
		Write-Host "Create attribute '$attrName'"
		$attrId = New-Attribute -Name $attrName -DisplayName $attrDisplayName -Description $attrDescription -Type "Reference" -MultiValued $attrMultivalued
	}
	
	#-------------------------------
	Write-Host "Add reference attribute to MPR's"
	#-------------------------------
	foreach($mprConfig in $attrConfig.Element("Policy").Elements("MPR")) {
		Add-AttributeToMPR -AttrName $attrName -MprName $mprConfig.Element("DisplayName").Value
	}

	#-------------------------------
	Write-Host "Create bindings for the reference attribute"
	#-------------------------------
	foreach($bindingConfig in $attrConfig.Element("Bindings").Elements("Binding")) { 
		$bindingDisplayName = $bindingConfig.Attribute("DisplayName").Value
		$bindingRequired = $bindingConfig.Attribute("Required").Value
		$boundObjectType = $bindingConfig.Attribute("Object").Value
		$bindingExists = Test-ObjectExists -Value $bindingDisplayName -Attribute DisplayName -ObjectType BindingDescription
		if($bindingExists) {
			Write-Host "Update existing binding '$bindingDisplayName'"
			Update-Binding -AttributeName $attrName -DisplayName $bindingDisplayName -Required $bindingRequired -ObjectType $boundObjectType
		} else {
			Write-Host "Create binding '$bindingDisplayName'"
			New-Binding -AttributeName $attrName -DisplayName $bindingDisplayName -Required $bindingRequired -ObjectType $boundObjectType
		}
	}

	#-------------------------------
	Write-Host "Edit RCDC"
	#-------------------------------
	$ns = [XNameSpace] "http://schemas.microsoft.com/2006/11/ResourceManagement"
	$rcdcName = $attrConfig.Element("RCDCs").Element("RCDC").Attribute("DisplayName").Value
	$rcdcObjectType = $attrConfig.Element("RCDCs").Element("RCDC").Element("Object").Value
	$rcdcGrouping = $attrConfig.Element("RCDCs").Element("RCDC").Element("Grouping").Value
	$rcdcCaption = $attrConfig.Element("RCDCs").Element("RCDC").Element("Caption").Value
	$rcdcElement = Get-RcdcIdentityPicker -AttributeName $attrName -ObjectType $rcdcObjectType

	$rcdc = Get-FimObject -Attribute DisplayName -Value $rcdcName -ObjectType ObjectVisualizationConfiguration
	$date = [datetime]::now.ToString("yyyy-MM-dd_HHmmss")
	$file = "$pwd/$date"+"_userEdit_before.xml"
	Write-Output $rcdc.ConfigurationData | Out-File $file -Encoding UTF8

	$xDoc = [XDocument]::Load($file)
	$panel = [XElement] $xDoc.Root.Element($ns + "Panel")
	$grouping = [XElement] ($panel.Elements($ns + "Grouping") | Where { $_.Attribute($ns + "Name").Value -eq "$rcdcGrouping" } | Select -index 0)

	if($grouping -eq $null) {
		$grouping = New-Object XElement ($ns + "Grouping")
		$grouping.Add((New-Object XAttribute ($ns + "Name"), $rcdcGrouping))
		$grouping.Add((New-Object XAttribute ($ns + "Caption"), $rcdcCaption))
		$grouping.Add((New-Object XAttribute ($ns + "Enabled"), $true))
		$grouping.Add((New-Object XAttribute ($ns + "Visible"), $true))
		$grouping.Add($rcdcElement)
		$panel.Add($grouping)
	} else {
		$grouping.Add($rcdcElement)
	}
	
	$exportFile = "$pwd/$date"+"_userEdit_after.xml"
	$xDoc.Save($exportFile)
	
	$anchor = @{'DisplayName' = $rcdcName}
	$changes = @{"ConfigurationData" = $xDoc.ToString()}
	New-FimImportObject -ObjectType ObjectVisualizationConfiguration -State Put -Anchor $anchor -Changes $changes -ApplyNow

	#-------------------------------
	Write-Host "Create search scope"
	#-------------------------------
	$searchScopeConfig = $objectConfig.Element("SearchScope")
	$searchScopeDisplayName = $searchScopeConfig.Attribute("DisplayName").Value
	$searchScopeOrder = $searchScopeConfig.Attribute("Order").Value
	$searchScopeContext = $searchScopeConfig.Element("Context").Value
	$searchScopeColumn = $searchScopeConfig.Element("Column").Value
	$searchScopeKeywords = @()
	foreach($keyword in $searchScopeConfig.Element("UsageKeywords").Elements("UsageKeyword")) {
		$searchScopeKeywords += $keyword.Value
	}
	$searchScopeExists = Test-ObjectExists -Value $searchScopeDisplayName -Attribute DisplayName -ObjectType SearchScopeConfiguration
	if($searchScopeExists) {
		Write-Host "Update existing search scope '$searchScopeDisplayName'"
		Update-SearchScope -DisplayName $searchScopeDisplayName -Order $searchScopeOrder -ObjectType $objectName -AttributeName $attrName -Context $searchScopeContext -Column $searchScopeColumn -UsageKeyWords $searchScopeKeywords
	} else {
		Write-Host "Create search scope '$searchScopeDisplayName'"
		New-SearchScope -DisplayName $searchScopeDisplayName -Order $searchScopeOrder -ObjectType $objectName -AttributeName $attrName -Context $searchScopeContext -Column $searchScopeColumn -UsageKeyWords $searchScopeKeywords
	}

	#-------------------------------
	Write-Host "Create navigation bar"
	#-------------------------------
	$navBar = $objectConfig.Element("NavigationBarResource")
	$navBarDisplayName = $navBar.Attribute("DisplayName").Value
	$navBarOrder = $navBar.Attribute("Order").Value
	$navBarParentOrder = $navBar.Attribute("ParentOrder").Value
	$navBarKeywords = @()
	foreach($keyword in $navBar.Element("UsageKeywords").Elements("UsageKeyword")) {
		$navBarKeywords += $keyword.Value
	}
	$navBarExists = Test-ObjectExists -Value $navBarDisplayName -Attribute DisplayName -ObjectType NavigationBarConfiguration
	if($navBarExists) {
		Write-Host "Update existing navigation bar '$navBarDisplayName'"
		Update-NavigationBar -DisplayName $navBarDisplayName -Order $navBarOrder -ParentOrder $navBarParentOrder -ObjectType $objectName -UsageKeyWords $navBarKeywords
	} else {
		Write-Host "Create navigation bar '$navBarDisplayName'"
		New-NavigationBar -DisplayName $navBarDisplayName -Order $navBarOrder -ParentOrder $navBarParentOrder -ObjectType $objectName -UsageKeyWords $navBarKeywords
	}
}

Function Get-RcdcIdentityPicker {
<#
	.SYNOPSIS
	Create an XElement configuration for an RCDC Identity Picker.

	.DESCRIPTION
	
	.EXAMPLE
	Get-RcdcIdentityPicker -AttributeName DepartmentReference -ObjectType Person
#>
	param(
		[Parameter(Mandatory=$True)] 
		[String]
		$AttributeName,

		[Parameter(Mandatory=$True)] 
		[String]
		$ObjectType,

		[Parameter(Mandatory=$False)] 
		[String]
		$ListViewTitle = "ListViewTitle",

		[Parameter(Mandatory=$False)] 
		[String]
		$PreviewTitle = "PreviewTitle",

		[Parameter(Mandatory=$False)] 
		[String]
		$MainSearchScreenText = "MainSearchScreenText",

		[Parameter(Mandatory=$False)] 
		[XNameSpace]
		$Ns = "http://schemas.microsoft.com/2006/11/ResourceManagement"
	)
	
	$element = New-Object XElement ($Ns + "Control")
	$element.Add((New-Object XAttribute ($Ns+"Name"), $AttributeName))
	$element.Add((New-Object XAttribute ($Ns+"TypeName"), "UocIdentityPicker"))
	$element.Add((New-Object XAttribute ($Ns+"Caption"), "{Binding Source=schema, Path=$AttributeName.DisplayName}"))
	$element.Add((New-Object XAttribute ($Ns+"Description"), "{Binding Source=schema, Path=$AttributeName.Description}"))
	$element.Add((New-Object XAttribute ($Ns+"RightsLevel"), "{Binding Source=rights, Path=$AttributeName}"))

	$properties = New-Object XElement ($Ns + "Properties")

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "Required"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), "{Binding Source=schema, Path=$AttributeName.Required}"))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "Mode"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), "SingleResult"))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "ObjectTypes"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $ObjectType))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "ColumnsToDisplay"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), "DisplayName, Description"))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "UsageKeywords"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $ObjectType))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "ResultObjectType"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $ObjectType))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "Value"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), "{Binding Source=object, Path=$AttributeName, Mode=TwoWay}"))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "ListViewTitle"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $ListViewTitle))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "PreviewTitle"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $PreviewTitle))
	$properties.Add($property)

	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns+"Name"), "MainSearchScreenText"))
	$property.Add((New-Object XAttribute ($Ns+"Value"), $MainSearchScreenText))
	$properties.Add($property)

	$element.Add($properties)

	return $element
}