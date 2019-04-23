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

#region Lithnet
if(!(Get-Module -Name LithnetRMA)) {
    Import-Module LithnetRMA
}
#Set-ResourceManagementClient -BaseAddress http://localhost:5725;
#endregion Lithnet

# Global variable path for the destination folder of the DeltaConfiguration.xml file
$global:Path = ""
# Global variable PathToConfigFiles for the source folder of development config xml files
$global:PathToConfig = ""

Function Start-Migration {
    <#
    .SYNOPSIS
    Starts the migration of a MIM-Setup by either comparing certain configurations between a source MIM-Setup and a
    target MIM-Setup or importing the delta in a target MIM-Setup.
    
    .DESCRIPTION 
    The source MIM-Setup xml files are acquired by calling Export-MIMConfig in the source environment.
    Start-Migration will serialize the target MIM setup resources to clixml and deserialize them
    so they can be compared with the resources from the source xml files.
    The differences that are found are writen to a Lithnet-format xml file called ConfigurationDelta.xml.
    When Start-Migration is called with -ImportDelta, the FimDelta.exe program is 
    called and the user can choose which resources get imported from the configuration delta.
    The final (or total) configuration then gets imported in the target MIM-Setup.

    .Parameter All
    If Start-Migration is called with the flag parameter '-All', all resources that are found in the Source and Target MIM-Setup
    will be compared. This will automatically create a complete ConfigurationDelta.xml where all the new and different resources
    are stored for every MIM-object type.

    .PARAMETER CompareSchema
    This parameter has the same effect as ComparePolicy and ComparePortal:
    The variable All will be set to false, this will cause to only compare the
    configurations where the flags are called, in this case the Schema configuration.
    
    .PARAMETER ImportDelta
    To ensure the differences get imported in the target MIM-Setup, call 'Start-Migration -ImportDelta'.
    This will use the created ConfigurationDelta.xml (from the chosen configurations) with Start-FimDelta (FimDelta.exe).
    If the user wishes to not import all resources and saves the selected resources, a ConfigurationDelta2.xml file will be
    created. The ConfigurationDelta.xml or ConfigurationDelta2.xml then gets imported in the target MIM-Setup

    .Parameter PathForDelta
    Optional parameter to declare a path where the ConfigurationDelta(2).xml will be saved. If this parameter is not declared
    a folder browser prompt will appear where the user can choose this path.

    .Parameter PathToConfigFiles
    Optional parameter to declare a path where the resources in xml files are located. If this parameter is not declared
    a folder browser prompt will appear where the user can choose this path.
    
    .EXAMPLE
    Start-Migration -All -PathForDelta "C:\" -PathToConfigFiles "C:\Program Files\MIMExportFiles"
    Start-Migration -ComparePolicy -CompareSchema
    Start-Migration -ImportDelta

    .Notes
    IMPORTANT:
    This module has been designed to only use Start-Migration and Export-MIMSetup functions.
    When other function are called there is no guarantee the desired effect will be accomplished.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [switch]
        $All,

        [Parameter(Mandatory=$False)]
        [switch]
        $CompareSchema,
        
        [Parameter(Mandatory=$False)]
        [switch]
        $ComparePolicy,
        
        [Parameter(Mandatory=$False)]
        [switch]
        $ComparePortal,

        [Parameter(Mandatory=$False)]
        [switch]
        $ImportDelta,

        [Parameter(Mandatory=$False)]
        [String]
        $PathForDelta,

        [Parameter(Mandatory=$False)]
        [String]
        $PathToConfigFiles
    )
    if (!($All.IsPresent -or $CompareSchema.IsPresent -or $ComparePolicy.IsPresent -or $ComparePortal.IsPresent -or $ImportDelta.IsPresent)) {
        Write-Host "Use Start-Migration with flag(s) (-All, -CompareSchema, -ComparePolicy, -ComparePortal or -ImportDelta)" -ForegroundColor Red
        return
    }
    if($PathToConfigFiles){
        if(Test-Path -path $PathToConfigFiles) {
        $global:PathToConfig = $PathToConfigFiles
        } else {
            Write-Host "$PathToConfigFiles folder not found!" -ForegroundColor Red
            $global:PathToConfig = Select-FolderDialog -Message "Select the folder where development config files are stored"
            if(!$PathToConfig){
                return
            }
        }
    } elseif(!$PathToConfig) {
        $global:PathToConfig = Select-FolderDialog -Message "Select the folder where development config files are stored"
        if(!$PathToConfig){
            return
        }
    }
    if($PathForDelta){
        if(Test-Path -path $PathForDelta){
            $global:Path = $PathForDelta
        } else {
            Write-Host "No $PathForDelta path found!" -ForegroundColor red
            $global:Path = Select-FolderDialog -Message "Select the folder where the ConfigurationDelta.xml will be saved"
            if (!$path) {
                return
            }
        }
    } elseif (!$path) {
        $global:Path = Select-FolderDialog -Message "Select the folder where the ConfigurationDelta.xml will be saved"
        if (!$path) {
            return
        }
    }
    # ReferentialList to store Objects and Attributes in memory for reference of bindings
    $global:ReferentialList = @{SourceRefObjs = [System.Collections.ArrayList]@(); DestRefObjs = [System.Collections.ArrayList] @();
    SourceRefAttrs = [System.Collections.ArrayList]@(); DestRefAttrs = [System.Collections.ArrayList]@()}
    $global:bindingRefs = [System.Collections.ArrayList] @()
    if ($CompareSchema -or $ComparePolicy -or $ComparePortal -or $ImportDelta) {
        $All = $False
    }
    if ($All) {
        Compare-Schema -path $path -PathConfig $PathToConfig
        Compare-Portal -path $path -PathConfig $PathToConfig
        Compare-Policy -path $path -PathConfig $PathToConfig
        #$ImportDelta = $True
    } else {
        if ($CompareSchema) {
            Compare-Schema -path $path -PathConfig $PathToConfig
        }
        if ($ComparePolicy) {
            $attrsSource = Get-ObjectsFromXml -XmlFilePath "ConfigAttributes.xml"
            foreach($objt in $attrsSource) {
                if (!($global:ReferentialList.SourceRefAttrs -contains $objt)){
                    $global:ReferentialList.SourceRefAttrs.Add($objt) | Out-Null
                }
            }
            $attrsDest = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
            foreach($objt in $attrsDest) {
                if (!($global:ReferentialList.DestRefAttrs -contains $objt)){
                    $global:ReferentialList.DestRefAttrs.Add($objt) | Out-Null
                }
            }
            Compare-Policy -path $path -PathConfig $PathToConfig
        }
        if ($ComparePortal) {
            Compare-Portal -path $path -PathConfig $PathToConfig
        }
    }
    if ($bindingRefs) {
        Write-ToXmlFile -DifferenceObjects $Global:bindingRefs -path $path -Anchor @("Name")
    }
    if($ImportDelta){
        Remove-Variable ReferentialList -Scope Global
        Remove-Variable bindingRefs -Scope Global
        if (Test-Path -Path "$Path\ConfigurationDelta.xml") {
            Write-Host "Select objects to be imported."
            Start-FimDelta -Path $Path
            if (Test-Path -Path "$Path\ConfigurationDelta2.xml") {
                Import-Delta -DeltaConfigFilePath "$path\ConfigurationDelta2.xml"
            } else {
                Import-Delta -DeltaConfigFilePath "$path\ConfigurationDelta.xml"
            }
        } else {
            Write-Host "No configurationDelta file found: Not created or no differences."
        }
        Remove-Variable Path -Scope Global
        Remove-Variable PathToConfig -Scope Global
    }
}

Function Export-MIMSetup {
    <#
    .SYNOPSIS
    Export the source resources from a MIM-Setup to xml files in a CliXml format.
    
    .DESCRIPTION
    Export the source resources from a MIM-Setup to xml files in a CliXml format to a certain path.
    The created files are used with the function Start-Migration when in the target MIM-Environment
    so resources can be compared between the two setups.

    .Parameter ExportAll
    Ensure all the resources found in the source MIM-Setup are exported and converted to xml files in a CliXml format.
    For every object type (that has resources) a xml file will be created and saved to a certain path.

    .Parameter ExportSchema
    Ensure all the Schema resources found in the source MIM-Setup are exported and converted to xml files in a CliXml format.
    For every object type (that has resources) a xml file will be created and saved to a certain path. 

    .Parameter ExportPolicy
    Ensure all the Policy resources found in the source MIM-Setup are exported and converted to xml files in a CliXml format.
    For every object type (that has resources) a xml file will be created and saved to a certain path.
    Schema resources are also automatically retrieved and saved to xml files, certain resources require references 
    to attributes from the Schema-configuration.

    .Parameter ExportPortal
    Ensure all the Portal resources found in the source MIM-Setup are exported and converted to xml files in a CliXml format.
    For every object type (that has resources) a xml file will be created and saved to a certain path.

    .Parameter PathForExport
    Optional parameter to declare a path where the folder, containing the configuration xml files, is saved.
    If this path is not declared, the folder will be saved in the Documents (MyDocuments) folder.

    .Parameter XPathToSet
    Give the xpath to a custom set of objects. This will be created in a seperate xml file to be 
    imported in the target MIM-Setup.

    .Example
    Export-MIMSetup -ExportAll
    #>
    param(
        [Parameter(Mandatory=$False)]
        [Switch]
        $ExportAll,

        [Parameter(Mandatory=$False)]
        [String]
        $PathForExport,

        [Parameter(Mandatory=$False)]
        [Switch]
        $ExportSchema,

        [Parameter(Mandatory=$False)]
        [Switch]
        $ExportPolicy,

        [Parameter(Mandatory=$False)]
        [Switch]
        $ExportPortal,

        [Parameter(Mandatory=$False)]
        [String]
        $XPathToSet
    )
    if (!($ExportAll.IsPresent -or $ExportSchema.IsPresent -or $ExportPolicy.IsPresent -or $ExportPortal.IsPresent)) {
        Write-Host "Use Export-MIMSetup with flag(s) (-ExportAll, -ExportSchema, -ExportPolicy, -ExportPortal)" -ForegroundColor Red
        return
    }

    if($PathForExport){
        if(Test-Path -path $PathForExport) {
            $global:PathToConfig = $PathForExport
        } else {
        Write-Host "$PathForExport folder does not exist. Choose a valid folder" -ForegroundColor Red
        $global:PathToConfig = Select-FolderDialog -Message "Select the folder where export files will be saved" | Out-Null
        }
    } else {
        $DefaultPath = [Environment]::GetFolderPath("MyDocuments")
        $global:PathToConfig = $DefaultPath
    }
    Write-Host "Starting export of the MIM configuration to xml files."
    if($ExportAll){
        Get-SchemaConfig
        Get-PolicyConfig -XPathToSet $XPathToSet
        Get-PortalConfig
    } else {
        if($ExportSchema){
            Get-SchemaConfig
        }
        if($ExportPolicy){
            Write-Host "Schema configuration automatically added for references!" -ForegroundColor Yellow
            Get-SchemaConfig
            Get-PolicyConfig -XPathToSet $XPathToSet
        }
        if($ExportPortal){
            Get-PortalConfig
        }
    }
    Write-Host "Export saved to $PathToConfig!" -ForegroundColor Green
    Remove-Variable PathToConfig -Scope global
}

Function Start-FimDelta {
    <#
    .SYNOPSIS
    Start the FimDelta application to select which objects are saved to ConfigurationDelta2.xml
    
    .DESCRIPTION
    Starts the FimDelta application where the user can choose which resources are to be saved to the
    ConfigurationDelta2.xml. These resources are created after a compare between two configurations and are placed in a file
    called ConfigurationDelta.xml. 
    The ConfigurationDelta2.xml, if created, is used for Import-Delta to import all the chosen resources.
    When nothing is saved to ConfigurationDelta2.xml, the ConfigurationDelta.xml is used instead for import.
    
    .PARAMETER Path
    Path to where ConfigurationDelta.xml is currently saved.

    .Example
    Start-FimDelta -Path "C:\"
    #>
    param(
        [Parameter(Mandatory=$False)]
        [String]
        $Path  
    )
    if(!$Path) {
        $Path = Select-FolderDialog -Message "Select the folder where the ConfigurationDelta.xml is saved!"
    }
    $ExeFile = "$PSScriptRoot\FimDelta.exe"
    if(Test-Path -Path "$Path\ConfigurationDelta.xml"){
        Start-Process $ExeFile "$Path\ConfigurationDelta.xml" -Wait
    } else {
        Write-Host "No ConfigurationDelta.xml file found, try again and select the correct folder."
    }
}

Function Compare-Schema {
    <#
    .SYNOPSIS
    Get the Schema resources from both the source and target MIM-Setup (by Get-ObjectsFromXml or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Schema resources from the source (Get-ObjectsFromXml) and target MIM-Setup (Get-ObjectsFromConfig). 
    Each object type in the Schema configuration calls the function Compare-MimObjects using the found objects of
    the corresponding object type. Compare-MimObjects will compare the resources and write the differences to a xml file.
    
    .PARAMETER Path
    Path given by Start-Migration to where ConfigurationDelta.xml will be saved.

    .Parameter PathConfig
    Path given by Start-Migration to where the configuration xml files containing the source resources are stored.
    #>
    
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $Path,

        [Parameter(Mandatory=$False)]
        [String]
        $PathConfig
    )
    # Source of objects to be imported
    $attrsSource = Get-ObjectsFromXml -XmlFilePath "$PathConfig\ConfigAttributes.xml"
    foreach($objt in $attrsSource) {
        $global:ReferentialList.SourceRefAttrs.Add($objt) | Out-Null
    }
    $objsSource = Get-ObjectsFromXml -XmlFilePath "$PathConfig\ConfigObjectTypes.xml"
    foreach($objt in $objsSource) {
        $global:ReferentialList.SourceRefObjs.Add($objt) | Out-Null
    }
    $bindingsSource = Get-ObjectsFromXml -XmlFilePath "$PathConfig\ConfigBindings.xml"
    $cstspecifiersSource = Get-ObjectsFromXml -XmlFilePath "$PathConfig\ConfigConstSpecifiers.xml"
    
    # Target Setup objects
    $attrsDest = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
    foreach($objt in $attrsDest) {
        $global:ReferentialList.DestRefAttrs.Add($objt) | Out-Null
    }
    $objsDest = Get-ObjectsFromConfig -ObjectType ObjectTypeDescription
    foreach($objt in $objsDest) {
        $global:ReferentialList.DestRefObjs.Add($objt) | Out-Null
    }
    $bindingsDest = Get-ObjectsFromConfig -ObjectType BindingDescription
    $cstspecifiersDest = Get-ObjectsFromConfig -ObjectType ConstantSpecifier

    # Comparing of the Source and Target Setup to create delta xml file
    Write-Host "Starting compare of Schema configuration..."
    Compare-MimObjects -ObjsSource $attrsSource -ObjsDestination $attrsDest -path $path
    Compare-MimObjects -ObjsSource $objsSource -ObjsDestination $objsDest -path $path
    Compare-MimObjects -ObjsSource $bindingsSource -ObjsDestination $bindingsDest `
    -Anchor @("BoundAttributeType", "BoundObjectType") -path $path
    Compare-MimObjects -ObjsSource $cstspecifiersSource -ObjsDestination $cstspecifiersDest `
    -Anchor @("BoundAttributeType", "BoundObjectType", "ConstantValueKey") -path $path
    Write-Host "Compare of Schema configuration completed."
}

Function Compare-Policy {
    <#
    .SYNOPSIS
    Get the Policy resources from both the source and target MIM-Setup (by Get-ObjectsFromXml or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Policy resources from the source (Get-ObjectsFromXml) and target MIM-Setup (Get-ObjectsFromConfig). 
    Each object type in the Policy configuration calls the function Compare-MimObjects using the found objects of
    the corresponding object type. Compare-MimObjects will compare the resources and write the differences to a xml file.
    
    .PARAMETER Path
    Path given by Start-Migration to where ConfigurationDelta.xml will be saved.

    .Parameter PathConfig
    Path given by Start-Migration to where the configuration xml files containing the source resources are stored.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $path,

        [Parameter(Mandatory=$False)]
        [String]
        $PathConfig
    )
    # Source of objects to be imported
    $mgmntPlciesSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigPolicies.xml"
    $setsSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigSets.xml"
    if (Test-Path("ConfigCustomSets.xml")) {
        $CustomSetsSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigCustomSets.xml"
        Write-ToXmlFile -DifferenceObjects $CustomSetsSrc -path $Path -Anchor @("DisplayName")
    }
    $workflowSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigWorkflows.xml"
    $emailSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigEmailTemplates.xml"
    $filtersSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigFilterScopes.xml"
    $activitySrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigActivityInfo.xml"
    $funcSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigPolicyFunctions.xml"
    $syncRSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigSyncRules.xml"
    $syncFSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigSyncFilters.xml"

    # Target Setup objects
    $mgmntPlciesDest = Get-ObjectsFromConfig -ObjectType ManagementPolicyRule
    $setsDest = Get-ObjectsFromConfig -ObjectType Set
    $workflowDest = Get-ObjectsFromConfig -ObjectType WorkflowDefinition
    $emailDest = Get-ObjectsFromConfig -ObjectType EmailTemplate
    $filtersDest = Get-ObjectsFromConfig -ObjectType FilterScope
    $activityDest = Get-ObjectsFromConfig -ObjectType ActivityInformationConfiguration
    $funcDest = Get-ObjectsFromConfig -ObjectType Function 
    $syncRDest = Get-ObjectsFromConfig -ObjectType SynchronizationRule
    $syncFDest = Get-ObjectsFromConfig -ObjectType SynchronizationFilter

    # Comparing of the Source and Target Setup to create delta xml file
    Write-Host "Starting compare of Policy configuration..."
    Compare-MimObjects -ObjsSource $mgmntPlciesSrc -ObjsDestination $mgmntPlciesDest -Anchor @("DisplayName") -path $path
    # Only import sets if policy grants permission for all attributes of Set objects
    Compare-MimObjects -ObjsSource $setsSrc -ObjsDestination $setsDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $workflowSrc -ObjsDestination $workflowDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $emailSrc -ObjsDestination $emailDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $filtersSrc -ObjsDestination $filtersDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $activitySrc -ObjsDestination $activityDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $funcSrc -ObjsDestination $funcDest -Anchor @("DisplayName") -path $path
    if ($syncRSrc) {
    Compare-MimObjects -ObjsSource $syncRSrc -ObjsDestination $syncRDest -Anchor @("DisplayName") -path $path
    }
    Compare-MimObjects -ObjsSource $syncFSrc -ObjsDestination $syncFDest -Anchor @("DisplayName") -path $path
    Write-Host "Compare of Policy configuration completed."
}

Function Compare-Portal {
    <#
    .SYNOPSIS
    Get the Portal resources from both the source and target MIM-Setup (by Get-ObjectsFromXml or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Portal resources from the source (Get-ObjectsFromXml) and target MIM-Setup (Get-ObjectsFromConfig). 
    Each object type in the Portal configuration calls the function Compare-MimObjects using the found objects of
    the corresponding object type. Compare-MimObjects will compare the resources and write the differences to a xml file.
    
    .PARAMETER Path
    Path given by Start-Migration to where ConfigurationDelta.xml will be saved.

    .Parameter PathConfig
    Path given by Start-Migration to where the configuration xml files containing the source resources are stored.
    #>
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $path,

        [Parameter(Mandatory=$False)]
        [String]
        $PathConfig
    )
    # Source of objects to be imported
    $UISrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigPortalUI.xml"
    $navSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigNavBar.xml"
    $srchScopeSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigSearchScope.xml"
    $objVisSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigObjectVisual.xml"
    $homePSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigHomePage.xml"
    $configSrc = Get-ObjectsFromXml -xmlFilePath "$PathConfig\ConfigConfigur.xml"

    # Target Setup objects
    $UIDest = Get-ObjectsFromConfig -ObjectType PortalUIConfiguration
    $navDest = Get-ObjectsFromConfig -ObjectType NavigationBarConfiguration
    $srchScopeDest = Get-ObjectsFromConfig -ObjectType SearchScopeConfiguration
    $objVisDest = Get-ObjectsFromConfig -ObjectType ObjectVisualizationConfiguration
    $homePDest = Get-ObjectsFromConfig -ObjectType HomepageConfiguration
    $configDest = Get-ObjectsFromConfig -ObjectType Configuration

    # Comparing of the Source and Target Setup to create delta xml file
    Write-Host "Starting compare of Portal configuration..."
    Compare-MimObjects -ObjsSource $UISrc -ObjsDestination $UIDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $navSrc -ObjsDestination $navDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $srchScopeSrc -ObjsDestination $srchScopeDest -Anchor @("DisplayName", "Order") -path $path
    Compare-MimObjects -ObjsSource $objVisSrc -ObjsDestination $objVisDest -Anchor @("DisplayName") -path $path
    Compare-MimObjects -ObjsSource $homePSrc -ObjsDestination $homePDest -Anchor @("DisplayName") -path $path
    if ($configSrc -and $configDest) {
        Compare-MimObjects -ObjsSource $configSrc -ObjsDestination $configDest -Anchor @("DisplayName") -path $path
    }
    Write-Host "Compare of Portal configuration completed."
}

Function Get-SchemaConfig {
    <#
    .SYNOPSIS
    Collect Schema resources from the MIM-Setup and writes them to a xml file in CliXml format.
    
    .DESCRIPTION
    Collect Schema resources from the MIM-Setup and writes them to a xml file in CliXml format.
    These xml files are used at the target MIM-Setup for importing the differences.
    #>
     
    $attrs = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
    $objs = Get-ObjectsFromConfig -ObjectType ObjectTypeDescription
    $bindings = Get-ObjectsFromConfig -ObjectType BindingDescription
    $constantSpec = Get-ObjectsFromConfig -ObjectType ConstantSpecifier

    Write-ToCliXml -Objects $attrs -xmlName Attributes 
    Write-ToCliXml -Objects $objs -xmlName ObjectTypes 
    Write-ToCliXml -Objects $bindings -xmlName Bindings
    Write-ToCliXml -Objects $constantSpec -xmlName ConstSpecifiers
}

Function Get-PolicyConfig {
    <#
    .SYNOPSIS
    Collect Policy resources from the MIM-Setup and writes them to a xml file in CliXml format.
    
    .DESCRIPTION
    Collect Policy resources from the MIM-Setup and writes them to a xml file in CliXml format.
    These xml files are used at the target MIM-Setup for importing the differences.
    
    .PARAMETER XPathToSet
    Xpath to a custom set of objects in the MIM-Setup.
    #>
    
    param(
        [Parameter(Mandatory=$False)]
        [String]
        $XPathToSet
    )
    $mgmntPolicies = Get-ObjectsFromConfig -ObjectType ManagementPolicyRule
    $sets = Get-ObjectsFromConfig -ObjectType Set
    $CustomSets = $null
    if ($XPathToSet) {
        $XPathToSet -replace '[/]', ''
        $CustomSets = Get-ObjectsFromConfig -ObjectType $XPathToSet
    }
    $workflowDef = Get-ObjectsFromConfig -ObjectType WorkflowDefinition
    $emailtmplt = Get-ObjectsFromConfig -ObjectType EmailTemplate
    $filterscope = Get-ObjectsFromConfig -ObjectType FilterScope
    $activityInfo = Get-ObjectsFromConfig -ObjectType ActivityInformationConfiguration
    $funct = Get-ObjectsFromConfig -ObjectType Function
    $syncRule = Get-ObjectsFromConfig -ObjectType SynchronizationRule
    $syncFilter = Get-ObjectsFromConfig -ObjectType SynchronizationFilter

    Write-ToCliXml -Objects $mgmntPolicies -xmlName Policies
    Write-ToCliXml -Objects $sets -xmlName Sets 
    Write-ToCliXml -Objects $workflowDef -xmlName Workflows 
    Write-ToCliXml -Objects $emailtmplt -xmlName EmailTemplates 
    Write-ToCliXml -Objects $filterscope -xmlName FilterScopes 
    Write-ToCliXml -Objects $activityInfo -xmlName ActivityInfo 
    Write-ToCliXml -Objects $funct -xmlName PolicyFunctions
    if ($CustomSets) {
        Write-ToCliXml -Objects $CustomSets -xmlName CustomSets   
    }
    if ($syncRule) {
        Write-ToCliXml -Objects $syncRule -xmlName SyncRules  
    }
    Write-ToCliXml -Objects $syncFilter -xmlName SyncFilters 
}

Function Get-PortalConfig {
    <#
    .SYNOPSIS
    Collect Portal resources from the MIM-Setup and writes them to a xml file in CliXml format.
    
    .DESCRIPTION
    Collect Portal resources from the MIM-Setup and writes them to a xml file in CliXml format.
    These xml files are used at the target MIM-Setup for importing the differences.
    #>
    $portalUI = Get-ObjectsFromConfig -ObjectType PortalUIConfiguration
    $navBar = Get-ObjectsFromConfig -ObjectType NavigationBarConfiguration
    $searchScope = Get-ObjectsFromConfig -ObjectType SearchScopeConfiguration
    $objVisual = Get-ObjectsFromConfig -ObjectType ObjectVisualizationConfiguration
    $homePage = Get-ObjectsFromConfig -ObjectType HomepageConfiguration
    $configuration = Get-ObjectsFromConfig -ObjectType Configuration

    Write-ToCliXml -Objects $portalUI -xmlName PortalUI
    Write-ToCliXml -Objects $navBar -xmlName NavBar 
    Write-ToCliXml -Objects $searchScope -xmlName SearchScope 
    Write-ToCliXml -Objects $objVisual -xmlName ObjectVisual 
    Write-ToCliXml -Objects $homePage -xmlName HomePage
    if($configuration){
        Write-ToCliXml -Objects $configuration -xmlName Configur
    }
}

function Get-ObjectsFromConfig {
    <#
    .SYNOPSIS
    Gets the resources from the MIM-Setup that correspond to the given object type, serialize and
    deserialize these resources and return them.
    
    .DESCRIPTION
    Gets the resources from the MIM-Setup that correspond to the given object type.
    The read-only members of the resources are stripped as they can not be imported in a target MIM-Setup.
    The updated resources then get serialized and deserialized so that they are the same format when comparing.
    The final resources are then returned.
    
    .PARAMETER ObjectType
    Object type of a type of resource in the MIM-Setup.
    #>
    
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $ObjectType
    )
    $objects = Search-Resources -XPath "/$ObjectType" -ExpectedObjectType $ObjectType
    # Read only members, not needed for import (are generated in the MIM-Setup)
    $illegalMembers = @("CreatedTime", "Creator", "DeletedTime", "DetectedRulesList",
    "ExpectedRulesList", "ResourceTime", "ComputedMember")
    # Source and Destination MIM-Setup get compared with objects that both have been serialized and deserialized
    if ($objects) {
        # Remove read-only attributes
        foreach($obj in $objects){
            foreach($illMem in $illegalMembers){
                $obj.psobject.properties.Remove("$illMem")
            }
        }
        Write-ToCliXml -Objects $objects -xmlName Temp   
        $objects = Import-Clixml "$PathToConfig\ConfigTemp.xml"
        Remove-Item -path "$PathToConfig\ConfigTemp.xml" 
    } else {
        Write-Host "No $ObjectType objects found to write to clixml!"
    }
    return $objects
}

Function Write-ToCliXml {
    <#
    .SYNOPSIS
    Writes objects to a xml file using the CliXml format.
    
    .DESCRIPTION
    Writes objects to a xml file using the CliXml format. The files are saved in a folder called MIMExportFiles.
    This folder is saved in the declared path from Export-MIMObjects.

    .Parameter Objects
    Array of objects that will be converted to a xml file in a CliXml format.

    .Parameter xmlName
    The name of the xml file. The name will be placed between 'Config' and '.xml'.
    #>
    
    param(
        [Parameter(Mandatory=$False)]
        [Array]
        $Objects,

        [Parameter(Mandatory=$True)]
        [String]
        $xmlName
    )
    if($Objects){
        if($xmlName -eq "Temp"){
            Export-Clixml -InputObject $Objects -Path "$PathToConfig\Config$xmlName.xml" -Depth 4
            return
        }
        if(Test-Path -path "$PathToConfig\MIMExportFiles"){
            Export-Clixml -InputObject $Objects -Path "$PathToConfig\MIMExportFiles\Config$xmlName.xml" -Depth 4
        } else {
            New-Item -ItemType directory -Path "$pathToConfig\MIMExportFiles" | Out-Null
            Export-Clixml -InputObject $Objects -Path "$PathToConfig\MIMExportFiles\Config$xmlName.xml" -Depth 4
        }
    }
}


Function Get-ObjectsFromXml {
    <#
    .SYNOPSIS
    Retrieve resources from a xml file.
    
    .DESCRIPTION
    Retrieve resources from a xml file that has been created by Export-MimConfig. This file contains
    resources from a MIM-Setup that have been serialized and deserialized by using the CliXml format.
    
    .EXAMPLE
    Get-ObjectsFromXml -xmlFilePath "ConfigPortalUI.xml"
    #>
    
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $xmlFilePath
    )
    if (Test-Path $xmlFilePath) {
        $objs = Import-Clixml -Path $xmlFilePath
        return $objs
    } else {
        Write-Host "$xmlFilePath not found (no objects found in source setup or not created)" -ForegroundColor Yellow
    }
}

Function Compare-MimObjects {
    <#
    .SYNOPSIS
    Compares two arrays of MIM-object type resources and sends the differences to Write-ToXmlFile
    
    .DESCRIPTION
    Compares two arrays containing resources from the source and target MIM-Setup. The objects that are referenced by objects that
    are new for the target MIM-Setup, get immediatly added without comparing for differences (these are needed for references in xml). 
    Counters keep track of the found differences and new objects and give a summary to the user.
    The final differences from new objects, different objects and referentials are send to Write-ToXmlFile to create
    a delta configuration file used for importing.
    
    .PARAMETER ObjsSource
    Resources from the source MIM-Setup. These objects are the ones that are imported if they are not found or different
    against the target MIM-Setup.
    
    .PARAMETER ObjsDestination
    Resources from the target MIM-Setup. These are used to find differences between the two resource arrays.
    
    .PARAMETER Anchor
    An anchor to uniquely identify objects. This parameter is also used for the delta configuration file as the anchor in the 
    xml structure.
    
    .PARAMETER path
    Path to where ConfigurationDelta.xml will be saved.
    
    .NOTES
    This compare function has been designed to compare objects in an array that follow a structure that is used in a MIM-Setup.
    When comparing objects that do not have this design, the compare can crash.

    .Example
    Compare-MimObjects -ObjsSource $AttrsSource -ObjsDestination $AttrsDest -Path "C:\"
    #>
    
    param (
        [Parameter(Mandatory=$True)]
        [array]
        $ObjsSource,

        [Parameter(Mandatory=$True)]
        [array]
        $ObjsDestination,

        [Parameter(Mandatory=$False)]
        [Array]
        $Anchor = @("Name"),
        
        [Parameter(Mandatory=$true)]
        [String]
        $path
    )
    $i = 1
    $total = $ObjsSource.Count
    $DifferenceCounter = 0
    $NewObjCounter = 0
    $difference = [System.Collections.ArrayList] @()
    $newObjs = [System.Collections.ArrayList] @()
    foreach ($obj in $ObjsSource){
        $type = $obj.ObjectType
        Write-Host "`rComparing $Type objects: $i/$total...`t" -NoNewline
        $i++
        if ($Anchor.Count -eq 1) {
            $obj2 = $ObjsDestination | Where-Object{$_.($Anchor[0]) -eq $obj.($Anchor[0])}
        } elseif ($Anchor.Count -eq 2) {
            # If the Object has referentials
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") {
                # Find the corresponding object that matches the BoundAttributeType ID
                $RefToAttrSrc = $global:ReferentialList.SourceRefAttrs | Where-Object{$_.ObjectID.Value -eq $obj.BoundAttributeType.Value}
                # Find the corresponding object that matches the referenced source attribute with the destination attribute by Name
                $RefToAttrDest = $global:ReferentialList.DestRefAttrs | Where-Object{$_.Name -eq $RefToAttrSrc.Name}

                $RefToObjSrc = $global:ReferentialList.SourceRefObjs | Where-Object{$_.ObjectID.Value -eq $obj.BoundObjectType.Value}
                $RefToObjDest = $global:ReferentialList.DestRefObjs | Where-Object{$_.Name -eq $RefToObjSrc.Name}
                if ($RefToAttrDest -and $RefToObjDest) {
                    #obj2 gets the correct object that corresponds to the source object
                    $obj2 = $ObjsDestination | Where-Object {$_.BoundAttributeType -like $RefToAttrDest.ObjectID -and
                    $_.BoundObjectType -like $RefToObjDest.ObjectID}
                } else {
                    $obj2 = ""
                }
            } else {
                $obj2 = $ObjsDestination | Where-Object {$_.($Anchor[0]) -like $obj.($Anchor[0]) -and 
                $_.($Anchor[1]) -like $obj.($Anchor[1])}
            }
        } else {
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") {
                $RefToAttrSrc = $global:ReferentialList.SourceRefAttrs | Where-Object{$_.ObjectID.Value -eq $obj.BoundAttributeType.Value}
                $RefToAttrDest = $global:ReferentialList.DestRefAttrs | Where-Object{$_.Name -eq $RefToAttrSrc.Name}

                $RefToObjSrc = $global:ReferentialList.SourceRefObjs | Where-Object{$_.ObjectID.Value -eq $obj.BoundObjectType.Value}
                $RefTOObjDest = $global:ReferentialList.DestRefObjs | Where-Object{$_.Name -eq $RefToObjSrc.Name}
                if ($RefToAttrDest -and $RefToObjDest) {
                    $obj2 = $ObjsDestination | Where-Object {$_.BoundAttributeType -like $RefToAttrDest.ObjectID -and
                    $_.BoundObjectType -like $RefToObjDest.ObjectID -and $_.($Anchor[2]) -eq $obj.($Anchor[2])}
                } else {
                    $obj2 = ""
                }
            } else {
                $obj2 = $ObjsDestination | Where-Object {$_.($Anchor[0]) -like $obj.($Anchor[0]) -and 
                $_.($Anchor[1]) -like $obj.($Anchor[1]) -and $_.($Anchor[2]) -like $obj.($Anchor[2])}
            }
        }
        # If there is no match between the objects from different sources the object will be added for import
        if (!$obj2) {
            $NewObjCounter++
            if ($Anchor -contains "BoundObjectType" -and $Anchor -contains "BoundAttributeType") { 
                if ($bindingRefs -notcontains $RefToAttrSrc) {
                    $global:bindingRefs.Add($RefToAttrSrc) | Out-Null
                }
                if ($bindingRefs -notcontains $RefToObjSrc) {
                    $global:bindingRefs.Add($RefToObjSrc) | Out-Null   
                }
            }
            $newObjs.Add($obj) | Out-Null
        } else {
            # Give the object the ObjectID from the target object => comparing reasons
            $OriginId = $obj.ObjectID
            $obj.ObjectID = $obj2.ObjectID     
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") {
                $obj.BoundAttributeType = $obj2.BoundAttributeType
                $obj.BoundObjectType = $obj2.BoundObjectType
            }
            # Sort ArrayLists before compare
            if (($obj.psobject.members.TypeNameOfValue -like "*ArrayList").Count -gt 0) {
                foreach($objMem in $obj.psobject.members){
                    if ($objMem.Value -and $objMem.Value.GetType().Name -eq "ArrayList") {
                        $obj2Mem = $obj2.psobject.members | Where-Object {$_.Name -eq $objMem.Name}
                        $objMem.Value = $objMem.Value | Sort-Object
                        $obj2Mem.Value = $obj2Mem.Value | Sort-Object
                    }
                }
            }
            $compResult = Compare-Object -ReferenceObject $obj.psobject.members -DifferenceObject $obj2.psobject.members -PassThru
            # If difference found
            if ($compResult) {
                # To visually compare the differences
                #Write-Host $obj -BackgroundColor Green -ForegroundColor Black
                #Write-Host $obj2 -BackgroundColor White -ForegroundColor Black
                $compObj = $compResult | Where-Object {$_.SideIndicator -eq '<='} # Difference in source object!
                $resultComp = $compObj | Where-Object membertype -like 'noteproperty'
                $UpdatedObj = [PSCustomObject] @{}
                foreach($mem in $resultComp){
                    $UpdatedObj | Add-Member -NotePropertyName $mem.Name -NotePropertyValue $Mem.Value
                }
                $DifferenceCounter++
                $difference.Add($UpdatedObj) | Out-Null
            }
            $obj.ObjectID = $OriginId
        }
    }
    if ($difference -or $newObjs) {
        Write-Host "Differences found!" -ForegroundColor Yellow
        Write-Host "Found $NewObjCounter new $Type objects." -ForegroundColor Yellow
        Write-Host "Found $DifferenceCounter different $Type objects." -ForegroundColor Yellow
        if ($newObjs){
            Write-ToXmlFile -DifferenceObjects $newObjs -path $path -Anchor $Anchor -newObjects
        }
        if ($difference){
            Write-ToXmlFile -DifferenceObjects $Difference -path $path -Anchor $Anchor 
        }
        Write-Host "Written differences in objects to the delta xml file (ConfigurationDelta.xml)"
    } else {
        Write-Host "No differences found!" -ForegroundColor Green
    }
}

Function Write-ToXmlFile {
    <#
    .SYNOPSIS
    Writes an array of objects to a Lithnet format xml file called ConfigurationDelta.xml.
    
    .DESCRIPTION
    Writes the given array of objects to a xml file using a Lithnet format that Import-RmConfig can read and import.
    This file is saved as ConfigurationDelta.xml and can be used by either Import-Delta (from Start-Migration -ImportDelta) 
    or Start-FimDelta.
    ObjectID's from the resources are used as xml-references in the xml file. When more references are found, the
    referenced objects are added to the global variable bindings. Objects from the global bindings are written to the same
    xml file used in this function so that references can be found.
    
    .PARAMETER DifferenceObjects
    Array of found resources that are different.

    .Parameter NewObjects
    If the send resources are new objects, the flag NewObjects is called with them. This ensures that the resources
    use xml references instead of Lithnet references (to ObjectID's).
    
    .PARAMETER path
    Path to where ConfigurationDelta.xml will be saved.
    
    .PARAMETER Anchor
    Anchor used for uniquely identifying objects.
    #>
    
    param (
        [Parameter(Mandatory=$True)]
        [System.Collections.ArrayList]
        $DifferenceObjects,

        [Parameter(Mandatory = $True)]
        [String]
        $path,

        [Parameter(Mandatory=$True)]
        [Array]
        $Anchor,

        [Parameter(Mandatory=$False)]
        [Switch]
        $newObjects
    )
    # Inititalization xml file
    $FileName = "$path\configurationDelta.xml"
    # Create empty starting lithnet configuration xml file
    if (!(Test-Path -Path $FileName)) {
        [xml]$Doc = New-Object System.Xml.XmlDocument
        $initalElement = $Doc.CreateElement("Lithnet.ResourceManagement.ConfigSync")
        $operationsElement = $Doc.CreateElement("Operations")
        $declaration = $Doc.CreateXmlDeclaration("1.0","UTF-8",$null)
        $Doc.AppendChild($declaration) | Out-Null
        $startNode = $Doc.AppendChild($initalElement)
        $startNode.AppendChild($operationsElement) | Out-Null
        $Doc.Save($FileName)
    }
    if (!(Test-Path -Path $FileName)) {
        Write-Host "File not found"
        break
    }
    $XmlDoc = [System.Xml.XmlDocument] (Get-Content $FileName)
    $node = $XmlDoc.SelectSingleNode('//Operations')

    # Place objects in XML file
    # Iterate over the array of PsCustomObjects
    foreach ($obj in $DifferenceObjects) {
        # Operation description
        $xmlElement = $XmlDoc.CreateElement("ResourceOperation")
        $XmlOperation = $node.AppendChild($xmlElement)
        $XmlOperation.SetAttribute("operation", "Add Update")
        $XmlOperation.SetAttribute("resourceType", $Obj.ObjectType)
        # Anchor description
        $xmlElement = $XmlDoc.CreateElement("AnchorAttributes")
        $XmlAnchors = $XmlOperation.AppendChild($xmlElement)
        # Different anchors for Bindings (or referentials)
        foreach($anch in $Anchor){
            $xmlElement = $XmlDoc.CreateElement("AnchorAttribute")
            $xmlElement.Set_InnerText($anch)
            $XmlAnchors.AppendChild($xmlElement) | Out-Null
        }
        # Attributes of the object
        $xmlEle = $XmlDoc.CreateElement("AttributeOperations")
        $XmlAttributes = $XmlOperation.AppendChild($xmlEle)
        # Get the PsCustomObject members from the MIM service without the hidden/extra members
        $objMembers = $obj.psobject.Members | Where-Object membertype -like 'noteproperty'
        # iterate over the PsCustomObject members and append them to the AttributeOperations element
        foreach ($member in $objMembers) {
            # Skip ObjectType (already used in ResourceOperation)
            if ($member.Name -eq "ObjectType") { continue }
            # insert ArrayList values into the configuration
            if($member.Value){
                if ($member.Value.GetType().Name -eq "ArrayList") { 
                    if($member.Name -eq "ExplicitMember") {
                        continue
                    }
                    foreach ($m in $member.Value) {
                        $xmlVarElement = $XmlDoc.CreateElement("AttributeOperation")
                        if ($member.Name -eq "AllowedAttributes"){
                            $RefToAttrSrc = $Global:ReferentialList.SourceRefAttrs | Where-Object {
                                $_.ObjectID.Value -eq $m.Value
                            }
                            $xmlVarElement.Set_InnerText($RefToAttrSrc.ObjectID.Value)
                            $xmlVariable = $XmlAttributes.AppendChild($xmlVarElement)
                            $xmlVariable.SetAttribute("type", "xmlref")
                            if($bindingRefs -notcontains $RefToAttrSrc) {
                                $Global:bindingRefs.Add($RefToAttrSrc) | Out-Null
                            }
                        } else {
                            $xmlVarElement.Set_InnerText($m)
                            $xmlVariable = $XmlAttributes.AppendChild($xmlVarElement)
                        }
                        
                        $xmlVariable.SetAttribute("operation", "add")
                        $xmlVariable.SetAttribute("name", $member.Name)
                    }
                    continue
                }
            }
            # referencing purposes, no need in the attributes themselves
            if ($member.Name -eq "ObjectID") {
                # set the objectID of the object as the id of the xml node
                $XmlOperation.SetAttribute("id", $member.Value.Value)
                continue
            }
            $xmlVarElement = $XmlDoc.CreateElement("AttributeOperation")
            if ($member.Name -eq "BoundAttributeType" -or $member.Name -eq "BoundObjectType") {
                $xmlVarElement.Set_InnerText($member.Value.Value)
                $xmlVariable = $XmlAttributes.AppendChild($xmlVarElement)
                $xmlVariable.SetAttribute("name", $member.Name)
                if($newObjects){
                    $xmlVariable.SetAttribute("operation", "replace")
                    $xmlVariable.SetAttribute("type", "xmlref")
                    continue
                } else {
                    $xmlVariable.SetAttribute("operation", "add")
                    continue
                }
            }
            $xmlVarElement.Set_InnerText($member.Value)
            $xmlVariable = $XmlAttributes.AppendChild($xmlVarElement)
            $xmlVariable.SetAttribute("operation", "replace")
            $xmlVariable.SetAttribute("name", $member.Name)
        }
    }
    # Save the xml 
    $XmlDoc.Save($FileName)
}


Function Select-FolderDialog{
    <#
    .SYNOPSIS
    Prompts the user for a folder browser.
    
    .DESCRIPTION
    This function makes the user choose a destination folder to save the xml configuration delta.
    If The user aborts this, the script will stop executing.
    
    .Parameter Message
    A message that will appear in the folder browser prompt.

    .LINK
    https://stackoverflow.com/questions/11412617/get-a-folder-path-from-the-explorer-menu-to-a-powershell-variable
    #>
    param(
        [Parameter(Mandatory=$True)]
        [string]
        $Message
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null     

    $objForm = New-Object System.Windows.Forms.FolderBrowserDialog
    $objForm.Rootfolder = "Desktop"
    $objForm.Description = $Message
    $Show = $objForm.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    If ($Show -eq "OK") {
        Return $objForm.SelectedPath
    } Else {
        Write-Host "Operation cancelled by user." -ForegroundColor Red
        return ""
    }
}

Function Import-Delta {
    <#
    .SYNOPSIS
    Import a delta configuration xml file in a MIM-setup.
    
    .DESCRIPTION
    Import the differences between the source MIM setup and the target MIM setup in the target 
    MIM setup using a delta in xml. This delta is created by the Start-Migration calls to compare functions.
    
    .PARAMETER DeltaConfigFilePath
    The path to a delta of a configuration in a xml file (ConfigurationDelta.xml or ConfigurationDelta2.xml).
    #>
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $DeltaConfigFilePath
    )
        # When Preview is enabled this will not import the configuration but give a preview
        Import-RMConfig $DeltaConfigFilePath -Verbose #-Preview
}