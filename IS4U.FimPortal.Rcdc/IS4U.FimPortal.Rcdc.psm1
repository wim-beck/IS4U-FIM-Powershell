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
Add-TypeAccelerators -Assembly System.Xml.Linq -Class XAttribute
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
[XNamespace] $Ns = "http://schemas.microsoft.com/2006/11/ResourceManagement"
$RcdcSchema = New-Object System.Xml.Schema.XmlSchemaSet
$RcdcSchema.Add($Ns, (Join-Path $Dir ".\rcdc.xsd"))

Function Test-RcdcConfiguration {
<#
	.SYNOPSIS
	Test the validity of the rcdc configuration against the schema.

	.DESCRIPTION
	Test the validity of the rcdc configuration against the schema.
	
	.EXAMPLE
	Test-RcdcConfiguration -Rcdc <configurationData>
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$ConfigurationData
	)
	[xml] $rcdc = $ConfigurationData
	$rcdc.Schemas.Add($RcdcSchema)
	try {
		$rcdc.Validate($null)
		return $true
	} catch [System.Xml.Schema.XmlSchemaValidationException] {
		Write-Warning $_.Exception.Message
		return $false
	}
}

Function New-Rcdc {
<#
	.SYNOPSIS
	Create a new resource configuration display configuration.

	.DESCRIPTION
	Create a new resource configuration display configuration.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$TargetObjectType,

		[Parameter(Mandatory=$True)]
		[String]
		$ConfigurationData,

		[Switch]
		$AppliesToEdit,

		[Switch]
		$AppliesToView,

		[Switch]
		$AppliesToCreate
	)
	if(Test-RcdcConfiguration -ConfigurationData $ConfigurationData) {
		$changes = @()
		$changes += New-FimImportChange -Operation 'None' -AttributeName 'DisplayName' -AttributeValue $DisplayName
		$changes += New-FimImportChange -Operation 'None' -AttributeName 'TargetObjectType' -AttributeValue $TargetObjectType
		$changes += New-FimImportChange -Operation 'None' -AttributeName 'ConfigurationData' -AttributeValue $ConfigurationData
		if($AppliesToCreate) {
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToCreate' -AttributeValue $True
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToEdit' -AttributeValue $False
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToView' -AttributeValue $False
		} elseif($AppliesToEdit) {
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToCreate' -AttributeValue $False
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToEdit' -AttributeValue $True
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToView' -AttributeValue $False
		} elseif($AppliesToView) {
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToCreate' -AttributeValue $False
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToEdit' -AttributeValue $False
			$changes += New-FimImportChange -Operation 'None' -AttributeName 'AppliesToView' -AttributeValue $True
		}
		New-FimImportObject -ObjectType ObjectVisualizationConfiguration -State Create -Changes $changes -ApplyNow
	} else {
		Write-Warning "Invalid rcdc configuration not created" 
	}
}

Function Update-Rcdc {
<#
	.SYNOPSIS
	Update a resource configuration display configuration.

	.DESCRIPTION
	Update a resource configuration display configuration.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName,

		[Parameter(Mandatory=$True)]
		[String]
		$ConfigurationData
	)
	if(Test-RcdcConfiguration -ConfigurationData $ConfigurationData) {
		$anchor = @{'DisplayName' = $DisplayName}
		$changes = @{"ConfigurationData" = $ConfigurationData}
		New-FimImportObject -ObjectType ObjectVisualizationConfiguration -State Put -Anchor $anchor -Changes $changes -ApplyNow
	} else {
		Write-Warning "Invalid rcdc configuration not uploaded" 
	}
}

Function Remove-Rcdc {
<#
	.SYNOPSIS
	Remove a resource configuration display configuration.

	.DESCRIPTION
	Remove a resource configuration display configuration.
#>
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$DisplayName
	)
	Remove-FimObject -AnchorName DisplayName -AnchorValue $DisplayName -ObjectType ObjectVisualizationConfiguration
}

Function Add-ElementToRcdc {
<#
	.SYNOPSIS
	Add an element to the RCDC configuration.

	.DESCRIPTION
	Add an element to the RCDC configuration.
	
	.EXAMPLE
	Add-ElementToRcdc -DisplayName "Configuration for user editing" -GroupingName "Basic" -RcdcElement <Element>
#>
	param(
		[Parameter(Mandatory=$True)] 
		[String]
		$DisplayName,
		
		[Parameter(Mandatory=$True)]
		[String]
		$GroupingName,
		
		[Parameter(Mandatory=$True)]
		[XElement]
		$RcdcElement,
		
		[Parameter(Mandatory=$False)]
		[String]
		$Caption = "Caption"
	)
	$rcdc = Get-FimObject -Attribute DisplayName -Value $DisplayName -ObjectType ObjectVisualizationConfiguration
	$date = [datetime]::now.ToString("yyyy-MM-dd_HHmmss")
	$file = "$pwd/$date" + "_" + $DisplayName + "_before.xml"
	Write-Output $rcdc.ConfigurationData | Out-File $file -Encoding UTF8

	$xDoc = [XDocument]::Load($file)
	$panel = [XElement] $xDoc.Root.Element($Ns + "Panel")
	$grouping = [XElement] ($panel.Elements($Ns + "Grouping") | Where { $_.Attribute($Ns + "Name").Value -eq $GroupingName } | Select -index 0)
	
	if($grouping -eq $null) {
		$grouping = New-Object XElement ($ns + "Grouping")
		$grouping.Add((New-Object XAttribute ($ns + "Name"), $GroupingName))
		$grouping.Add((New-Object XAttribute ($ns + "Caption"), $Caption))
		$grouping.Add((New-Object XAttribute ($ns + "Enabled"), $true))
		$grouping.Add((New-Object XAttribute ($ns + "Visible"), $true))
		$grouping.Add($RcdcElement)
		$summary = [XElement] ($panel.Elements($Ns + "Grouping") | Where { $_.Attribute($Ns + "IsSummary").Value -eq "true" } | Select -index 0)
		$summary.AddBeforeSelf($grouping)
	} else {
		$grouping.Add($RcdcElement)
	}
	$file = "$pwd/$date" + "_" + $DisplayName + "_after.xml"
	$xDoc.Save($file)
	if(Test-RcdcConfiguration -ConfigurationData $xDoc.ToString()) {
		Update-Rcdc -DisplayName $DisplayName -ConfigurationData $xDoc.ToString()
	} else {
		Write-Warning "Invalid rcdc configuration not uploaded" 
	}
}

Function Get-DefaultRcdc {
<#
	.SYNOPSIS
	Get default create RCDC configuration.

	.DESCRIPTION
	Get default create RCDC configuration.

	.EXAMPLE
	Get-DefaultRcdc -Caption "Create Department" -Xml defaultCreate.xml
#>
	param(
		[Parameter(Mandatory=$True)] 
		[String]
		$Caption,
		
		[Parameter(Mandatory=$False)]
		[String]
		$Xml,
		
		[Switch]
		$Create,
		
		[Switch]
		$Edit,

		[Switch]
		$View
	)
	if($Xml) {
		$rcdc = [XDocument]::Load((Join-Path $pwd $Xml))
	} elseif($Create) {
		$rcdc = [XDocument]::Load((Join-Path $Dir ".\defaultCreateRcdc.xml"))
	} elseif($Edit) {
		$rcdc = [XDocument]::Load((Join-Path $Dir ".\defaultEditRcdc.xml"))
	} elseif($View) {
		$rcdc = [XDocument]::Load((Join-Path $Dir ".\defaultViewRcdc.xml"))
	}
	$rcdc.Root.Element($Ns + "Panel").Element($Ns+"Grouping").Element($Ns + "Control").Attribute($Ns+"Caption").Value = $Caption
	return $rcdc
}

Function Get-RcdcIdentityPicker {
<#
	.SYNOPSIS
	Create an XElement configuration for an RCDC Identity Picker.

	.DESCRIPTION
	Create an XElement configuration for an RCDC Identity Picker.
	
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
		$MainSearchScreenText = "MainSearchScreenText"
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

Function Get-RcdcTextBox {
<#
	.SYNOPSIS
	Create an XElement configuration for an RCDC Text Box.

	.DESCRIPTION
	Create an XElement configuration for an RCDC Text Box.
	
	.EXAMPLE
	Get-RcdcTextBox -AttributeName VisaCardNumber
#>
	param(
		[Parameter(Mandatory=$True)] 
		[String]
		$AttributeName
	)
	$element = New-Object XElement ($Ns + "Control")
	$element.Add((New-Object XAttribute ($Ns + "Name"), $AttributeName))
	$element.Add((New-Object XAttribute ($Ns + "TypeName"), "UocTextBox"))
	$element.Add((New-Object XAttribute ($Ns + "Caption"), "{Binding Source=schema, Path=$AttributeName.DisplayName}"))
	$element.Add((New-Object XAttribute ($Ns + "Description"), "{Binding Source=schema, Path=$AttributeName.Description}"))
	$element.Add((New-Object XAttribute ($Ns + "RightsLevel"), "{Binding Source=rights, Path=$AttributeName}"))
	
	$properties = New-Object XElement ($Ns + "Properties")
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "ReadOnly"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "false"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Required"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=schema, Path=$AttributeName.Required}"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Text"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=object, Path=$AttributeName, Mode=TwoWay}"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "MaxLength"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "400"))
	$properties.Add($property)	
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "RegularExpression"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=schema, Path=$AttributeName.StringRegex}"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Hint"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=schema, Path=$AttributeName.Hint}"))
	$properties.Add($property)

	$element.Add($properties)
	return $element
}

Function Get-RcdcCheckBox {
<#
	.SYNOPSIS
	Create an XElement configuration for an RCDC Check Box.

	.DESCRIPTION
	Create an XElement configuration for an RCDC Check Box.
	
	.EXAMPLE
	Get-RcdcCheckBox -AttributeName IsAwesome
#>
	param(
		[Parameter(Mandatory=$True)] 
		[String]
		$AttributeName
	)
	$element = New-Object XElement ($Ns + "Control")
	$element.Add((New-Object XAttribute ($Ns + "Name"), $AttributeName))
	$element.Add((New-Object XAttribute ($Ns + "TypeName"), "UocCheckBox"))
	$element.Add((New-Object XAttribute ($Ns + "Caption"), "{Binding Source=schema, Path=$AttributeName.DisplayName}"))
	$element.Add((New-Object XAttribute ($Ns + "Description"), "{Binding Source=schema, Path=$AttributeName.Description}"))
	$element.Add((New-Object XAttribute ($Ns + "RightsLevel"), "{Binding Source=rights, Path=$AttributeName}"))
	
	$properties = New-Object XElement ($Ns + "Properties")
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "ReadOnly"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "false"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Required"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=schema, Path=$AttributeName.Required}"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Checked"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=object, Path=$AttributeName, Mode=TwoWay}"))
	$properties.Add($property)
	
	$property = New-Object XElement ($Ns + "Property")
	$property.Add((New-Object XAttribute ($Ns + "Name"), "Hint"))
	$property.Add((New-Object XAttribute ($Ns + "Value"), "{Binding Source=schema, Path=$AttributeName.Hint}"))
	$properties.Add($property)

	$element.Add($properties)
	return $element
}