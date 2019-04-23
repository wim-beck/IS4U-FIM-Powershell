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
if (!(Get-Module -Name LithnetRMA)) {
    Import-Module LithnetRMA
}

#Set-ResourceManagementClient -BaseAddress http://localhost:5725;
#endregion Lithnet

<#
To do:
- Installeren van Wall automatisch
#>
$Global:path = ""
$Global:PathToConfig = ""

Function Start-Migration {
    <#
    .SYNOPSIS
    tarts the migration of a MIM-Setup by either comparing certain configurations between a source MIM-Setup and a
    target MIM-Setup or importing the delta in a target MIM-Setup.
    
    .DESCRIPTION
    The source MIM-Setup json files are acquired by calling Export-MIMConfig in the source environment.
    Start-Migration will serialize the target MIM setup resources to json and deserialize them
    so they can be compared with the resources from the source json files.
    The differences that are found are writen to a Lithnet-format xml file called ConfigurationDelta.xml.
    When Start-Migration is called with -ImportDelta, the FimDelta.exe program is 
    called and the user can choose which resources get imported from the configuration delta.
    The final (or total) configuration then gets imported in the target MIM-Setup.  

    .PARAMETER All
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
    created. The ConfigurationDelta.xml or ConfigurationDelta2.xml then gets imported in the target MIM-Setup.

    .PARAMETER PathToConfigFiles
    Optional parameter to declare a path where the resources in xml files are located. If this parameter is not declared
    a folder browser prompt will appear where the user can choose this path.

    .PARAMETER PathForDelta
    Optional parameter to declare a path where the ConfigurationDelta(2).xml will be saved. If this parameter is not declared
    a folder browser prompt will appear where the user can choose this path.
    
    .EXAMPLE
    Start-Migration -All -PathForDelta "C:\" -PathToConfigFiles "C:\Program Files\MIMExportFiles"
    Start-Migration -ComparePolicy -CompareSchema
    Start-Migration -ImportDelta

    .Notes
    IMPORTANT:
    This module has been designed to only use Start-Migration and Export-MIMSetup functions.
    When other functions are called there is no guarantee the desired effect will be accomplished.
    #>
    param(
        
        [Parameter(Mandatory=$False)]
        [Switch]
        $All=$False,

        [Parameter(Mandatory=$False)]
        [Switch]
        $CompareSchema=$False,
        
        [Parameter(Mandatory=$FAlse)]
        [Switch]
        $ComparePolicy = $False,
        
        [Parameter(Mandatory=$False)]
        [Switch]
        $ComparePortal = $False,

        [Parameter(Mandatory=$False)]
        [Switch]
        $ImportDelta = $False,

        [Parameter(Mandatory=$False)]
        [String]
        $PathToConfigFiles,

        [Parameter(Mandatory=$False)]
        [String]
        $PathForDelta
    )
    if (!($All.IsPresent -or $CompareSchema.IsPresent -or $ComparePolicy.IsPresent -or $ComparePortal.IsPresent -or $ImportDelta.IsPresent)) {
        Write-Host "Use Start-Migration with flag(s) (-All, -CompareSchema, -ComparePolicy, -ComparePortal or -ImportDelta)" -ForegroundColor Red
        return
    }
    if ($PathToConfigFiles) {
        if (Test-Path -path $PathToConfigFiles) {
            $Global:PathToConfig = $PathToConfigFiles
        } else {
            Write-Host "$PathToConfigFiles was not found!" -ForegroundColor Red
            $Global:PathToConfig = Select-FolderDialog -Message "Select folder where Development Config files are stored"
            if (!$PathToConfig) {
                return
            }
        }
    } elseif(!$PathToConfig) {
        $Global:PathToConfig = Select-FolderDialog -Message "Select folder where Development Config files are stored"
        if(!$PathToConfig) {
            return
        }
    }
    if ($PathForDelta) {
        if (Test-Path -path $PathForDelta) {
            $Global:path = $PathForDelta
        } else {
            Write-Host "No $PathForDelta path found!" -ForegroundColor Red
            $Global:path = Select-FolderDialog -Message "Select folder where the ConfigurationDelta.xml will be saved"
            if (!$PathForDelta) {
                return
            }
        }
    } elseif (!$path) {
        $Global:path = Select-FolderDialog "Select folder to save the ConfigurationDelta.xml"
        if (!$path) {
            return
        }
    }
    # Force the path for the ExePath to IS4U.MigrateJson
    #$ExePath = $PSScriptRoot
    # ReferentialList to store Objects and Attributes in memory for reference of bindings
    $Global:ReferentialList = @{SourceRefAttrs = [System.Collections.ArrayList]@(); DestRefAttrs = [System.Collections.ArrayList]@() 
    SourceRefObjs = [System.Collections.ArrayList]@(); DestRefObjs = [System.Collections.ArrayList]@();}
    $Global:bindings = [System.Collections.ArrayList] @()
    if ($CompareSchema -or $ComparePolicy -or $ComparePortal -or $ImportDelta) {
        $All = $False
    }
    if ($All) {
        Compare-Schema -path $path -PathToConfig $PathToConfig
        Compare-Policy -path $path -PathToConfig $PathToConfig
        Compare-Portal -path $path -PathToConfig $PathToConfig
        #$ImportDelta = $True
    } else {
        if ($CompareSchema) {
            Compare-Schema -path $path -PathToConfig $PathToConfig
        }
        if ($ComparePolicy) {
            $attrsSource = Get-ObjectsFromJson -XmlFilePath "ConfigAttributes.json"
            foreach($objt in $attrsSource) {
                if(!($Global:ReferentialList.SourceRefAttrs -contains $objt)) {
                    $Global:ReferentialList.SourceRefAttrs.Add($objt) | Out-Null
                }
            }
            $attrsDest = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
            foreach($objt in $attrsDest) {
                if(!($Global:ReferentialList.DestRefAttrs -contains $objt)) {
                    $Global:ReferentialList.DestRefAttrs.Add($objt) | Out-Null
                }
            }
            Compare-Policy -path $path -PathToConfig $PathToConfig
        }
        if ($ComparePortal) {
            Compare-Portal -path $path -PathToConfig $PathToConfig
        }
        }
    if ($bindings) {
        Write-ToXmlFile -DifferenceObjects $bindings -path $path -Anchor @("Name")
    }

    if ($ImportDelta) {
        Remove-Variable ReferentialList -Scope Global
        Remove-Variable bindings -Scope Global
        if (Test-Path -Path "$Path\ConfigurationDelta.xml") {
            Write-Host "Select objects to be imported." -ForegroundColor "Green"
            #$exeFile = "$ExePath\FimDelta.exe"
            Start-FimDelta -Path $Path
            #Start-Process $exeFile "$Path\ConfigurationDelta.xml" -Wait
            if (Test-Path -Path "$Path\ConfigurationDelta2.xml") {
                Import-Delta -DeltaConfigFilePath "$path\ConfigurationDelta2.xml"
            } else {
                Import-Delta -DeltaConfigFilePath "$path\ConfigurationDelta.xml"
            }
        } else {
            Write-Host "No configurationDelta file found: Not created or no differences."
        }
        Remove-Variable path -Scope Global
        Remove-Variable PathToConfig -Scope Global
    }
}

Function Export-MIMSetup {
    <#
    .SYNOPSIS
    Export the source resources from a MIM-Setup to json files in a json format.
    
    .DESCRIPTION
    Export the source resources from a MIM-Setup to json files in a json format.
    The created files are used with the function Start-Migration so resources can be compared
    between the two setups.

    .Parameter ExportAll
    Ensure all the resources found in the source MIM-Setup are exported and converted to json files in a json format.
    For every object type (that has resources) a json file will be created and saved to a certain path.

    .Parameter ExportSchema
    Ensure all the Schema resources found in the source MIM-Setup are exported and converted to json files in a json format.
    For every object type (that has resources) a json file will be created and saved to a certain path. 

    .Parameter ExportPolicy
    Ensure all the Policy resources found in the source MIM-Setup are exported and converted to json files in a json format.
    For every object type (that has resources) a json file will be created and saved to a certain path.
    Schema resources are also automatically retrieved and saved to json files, certain resources require references 
    to attributes from the Schema-configuration.

    .Parameter ExportPortal
    Ensure all the Portal resources found in the source MIM-Setup are exported and converted to json files in a json format.
    For every object type (that has resources) a json file will be created and saved to a certain path.

    .Parameter PathForExport
    Optional parameter to declare a path where the folder, containing the configuration json files, is saved.
    If this path is not declared, the folder will be saved in the Documents (MyDocuments) folder.

    .Parameter XpathToSet
    Give the xpath to a custom Set object. This will be created in a seperate json file to be 
    imported in the target MIM-Setup.

    .Example
    Export-MIMSetup -ExportAll
    #>
    param(
        [Parameter(Mandatory=$False)]
        [Switch]
        $ExportAll,

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
        $XpathToSet,

        [Parameter(Mandatory=$False)]
        [String]
        $PathToExport
    )
    if (!($ExportAll.IsPresent -or $ExportSchema.IsPresent -or $ExportPolicy.IsPresent -or $ExportPortal.IsPresent)) {
        Write-Host "Use Export-MIMSetup with flag(s) (-All, -ExportSchema, -ExportPolicy, -ExportPortal)" -ForegroundColor Red
        return
    }
    if (Test-Path -path $PathToExport) {
        if ($PathToExport) {
            $Global:PathToConfig = $PathToExport
        } else {
            Write-Host "$PathToExport folder does not exist. Choose a valid folder!" -ForegroundColor Red
            $Global:PathToConfig = Select-FolderDialog -Message "Select the folder where export files are saved" | Out-Null
        }
    } else {
        $DefaultPath = [environment]::GetFolderPath("MyDocuments")
        $Global:PathToConfig = $DefaultPath
    }
    Write-Host "Starting export of the MIM configuration to json files."
    if ($ExportAll) {
        Get-SchemaConfig
        Get-PolicyConfig -xPathToSet $XpathToSet
        Get-PortalConfig
    }
    if ($ExportSchema) {
        Get-SchemaConfig
    }
    if ($ExportPolicy) {
        Get-SchemaConfig
        Get-PolicyConfig -xPathToSet $XpathToSet
    }
    if ($ExportPortal) {
        Get-SchemaConfig
        Get-PortalConfig
    }
    Write-Host "Export saved towards $PathToConfig!" -ForegroundColor Green
    Remove-Variable PathToConfig -Scope Global
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
    param (
        [Parameter(Mandatory=$True)]
        [string]
        $Path
    )

    if(!$Path) {
        $Path = Select-FolderDialog -Message "Select the folder where the ConfigurationDelta.xml is saved"
    }
    $ExeFile = "$PSScriptRoot\FimDelta.exe"
    if(Test-Path -Path "$Path\ConfigurationDelta.xml") {
        Start-Process $ExeFile "$Path\ConfigurationDelta.xml" -Wait
    }
    else {
        Write-Host "No ConfigurationDelta.xml file was found in this location, try again select the correct location!"
    }
}

Function Get-SchemaConfig {
    <#
    .SYNOPSIS
    Collect Schema resources from the MIM-Setup and writes them to a json file in json format.
    
    .DESCRIPTION
    Collect Schema resources from the MIM-Setup and writes them to a json file in json format.
    These json files are used at the target MIM-Setup for importing the differences.
    #>
    param(
        [Parameter(Mandatory=$False)]
        [Bool]
        $Source = $False
    )

    $attrs = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
    $objs = Get-ObjectsFromConfig -ObjectType ObjectTypeDescription
    $binds = Get-ObjectsFromConfig -ObjectType BindingDescription
    $constSpec = Get-ObjectsFromConfig -ObjectType ConstantSpecifier

    Convert-ToJson -Objects $attrs -JsonName Attributes
    Convert-ToJson -Objects $objs -JsonName objectTypes
    Convert-ToJson -Objects $binds -JsonName Bindings
    Convert-ToJson -Objects $constSpec -JsonName ConstantSpecifiers
}

Function Compare-Schema {
    <#
    .SYNOPSIS
    Get the Schema resources from both the source and target MIM-Setup (by Get-ObjectsFromJson or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Schema resources from the source (Get-ObjectsFromJson) and target MIM-Setup (Get-ObjectsFromConfig). 
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
        $path,

        [Parameter(Mandatory=$False)]
        [String]
        $PathToConfig
    )
    Write-Host "Starting compare of Schema configuration..."
    # Source of objects to be imported
    $attrsSource = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigAttributes.json"
    foreach($obj in $attrsSource) {
        $Global:ReferentialList.SourceRefAttrs.Add($obj) | Out-Null
    }
    $objsSource = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigObjectTypes.json"
    foreach($obj in $objsSource) {
        $Global:ReferentialList.SourceRefObjs.Add($obj) | Out-Null
    }
    $bindingsSource = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigBindings.json"
    $constSpecsSource = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigConstantSpecifiers.json"
    
    # Target Setup objects, comparing purposes
    # Makes target a json and then converts it to an object
    $attrsDest = Get-ObjectsFromConfig -ObjectType AttributeTypeDescription
    foreach($obj in $attrsDest) {
        $Global:ReferentialList.DestRefAttrs.Add($obj) | Out-Null
    }
    $objsDest = Get-ObjectsFromConfig -ObjectType ObjectTypeDescription
    foreach($obj in $objsDest) {
        $Global:ReferentialList.DestRefObjs.Add($obj) | Out-Null
    }
    $bindingsDest = Get-ObjectsFromConfig -ObjectType BindingDescription
    $constSpecsDest = Get-ObjectsFromConfig -ObjectType ConstantSpecifier

    # Comparing of the Source and Target Setup to create delta xml file
    Write-Host "Starting compare of Schema configuration..."
    Compare-Objects -ObjsSource $attrsSource -ObjsDestination $attrsDest -path $path
    Compare-Objects -ObjsSource $objsSource -ObjsDestination $objsDest -path $path
    Compare-Objects -ObjsSource $bindingsSource -ObjsDestination $bindingsDest -Anchor @("BoundAttributeType", "BoundObjectType") -path $path
    Compare-Objects -ObjsSource $constSpecsSource -ObjsDestination $constSpecsDest -Anchor @("BoundAttributeType", "BoundObjectType", "ConstantValueKey") -path $path
    Write-Host "Compare of Schema configuration completed."
}

Function Get-PolicyConfig {
    <#
    .SYNOPSIS
    Collect Policy resources from the MIM-Setup and writes them to a json file in json format.
    
    .DESCRIPTION
    Collect Policy resources from the MIM-Setup and writes them to a json file in json format.
    These json files are used at the target MIM-Setup for importing the differences.
    
    .PARAMETER xPathToSet
    Xpath to a custom Set of objects in the MIM-Setup.
    #>
    param(
        [Parameter(Mandatory=$False)]
        [String]
        $xPathToSet
    )

    $manPol = Get-ObjectsFromConfig -ObjectType ManagementPolicyRule
    $sets = Get-ObjectsFromConfig -ObjectType Set
    $CustomSets = $null
    if ($xPathToSet) {
        $xPathToSet -replace '[/]', ''
        $CustomSets = Get-ObjectsFromConfig -ObjectType $xPathToSet
    }
    $workFlowDef = Get-ObjectsFromConfig -ObjectType WorkflowDefinition
    $emailTem = Get-ObjectsFromConfig -ObjectType EmailTemplate
    $filterScope = Get-ObjectsFromConfig -ObjectType FilterScope
    $actInfConf = Get-ObjectsFromConfig -ObjectType ActivityInformationConfiguration
    $function = Get-ObjectsFromConfig -ObjectType Function
    $syncRule = Get-ObjectsFromConfig -ObjectType SynchronizationRule
    $syncFilter = Get-ObjectsFromConfig -ObjectType SynchronizationFilter

    Convert-ToJson -Objects $manPol -JsonName ManagementPolicyRules
    Convert-ToJson -Objects $sets -JsonName Sets
    Convert-ToJson -Objects $workFlowDef -JsonName WorkflowDefinitions
    Convert-ToJson -Objects $emailTem -JsonName EmailTemplates
    Convert-ToJson -Objects $filterScope -JsonName FilterScopes
    Convert-ToJson -Objects $actInfConf -JsonName ActivityInformationConfigurations
    Convert-ToJson -Objects $function -JsonName Functions
    if ($CustomSets) {
        Convert-ToJson -Objects $CustomSets -JsonName CustomSets   
    }
    if($syncRule){
        Convert-ToJson -Objects $syncRule -JsonName SynchronizationRules
    }
    Convert-ToJson -Objects $syncFilter -JsonName SynchronizationFilters
}

Function Compare-Policy {
    <#
    .SYNOPSIS
    Get the Policy resources from both the source and target MIM-Setup (by Get-ObjectsFromJson or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Policy resources from the source (Get-ObjectsFromJson) and target MIM-Setup (Get-ObjectsFromConfig). 
    Each object type in the Policy configuration calls the function Compare-MimObjects using the found objects of
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
        $PathToConfig
    )
    Write-Host "Starting compare of Policy configuration..."
    # Source of objects to be imported
    $mgmntPlciesSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigManagementPolicyRules.json"
    $setsSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigSets.json"
    if (Test-Path("ConfigCustomSets.xml")) {
        $CustomSetsSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigCustomSets.json"
        Write-ToXmlFile -DifferenceObjects $CustomSetsSrc -path $Path -Anchor @("DisplayName")
    }
    $workflowSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigWorkflowDefinitions.json"
    $emailSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigEmailTemplates.json"
    $filtersSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigFilterScopes.json"
    $activitySrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigActivityInformationConfigurations.json"
    $funcSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigFunctions.json"
    $syncRSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigSynchronizationRules.json"
    $syncFSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigSynchronizationFilters.json"

    # Target Setup objects, comparing purposes
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
    Compare-Objects -ObjsSource $mgmntPlciesSrc -ObjsDestination $mgmntPlciesDest -Anchor @("DisplayName") -path $path
    # Only import sets if policy grants permission for all the attributes from sets
    Compare-Objects -ObjsSource $setsSrc -ObjsDestination $setsDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $workflowSrc -ObjsDestination $workflowDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $emailSrc -ObjsDestination $emailDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $filtersSrc -ObjsDestination $filtersDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $activitySrc -ObjsDestination $activityDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $funcSrc -ObjsDestination $funcDest -Anchor @("DisplayName") -path $path
    if ($syncRSrc) {
        Compare-Objects -ObjsSource $syncRSrc -ObjsDestination $syncRDest -Anchor @("DisplayName") -path $path
    }
    Compare-Objects -ObjsSource $syncFSrc -ObjsDestination $syncFDest -Anchor @("DisplayName") -path $path
    Write-Host "Compare of Policy configuration completed."
}

Function Get-PortalConfig {
    <#
    .SYNOPSIS
    Collect Portal resources from the MIM-Setup and writes them to a json file in json format.
    
    .DESCRIPTION
    Collect Portal resources from the MIM-Setup and writes them to a json file in json format.
    These json files are used at the target MIM-Setup for importing the differences.
    #>
    param(
        [Parameter(Mandatory=$False)]
        [Bool]
        $Source = $False
    )

    $homeConf = Get-ObjectsFromConfig -ObjectType HomepageConfiguration
    $portalUIConf = Get-ObjectsFromConfig -ObjectType PortalUIConfiguration
    $conf = Get-ObjectsFromConfig -ObjectType Configuration
    $naviBarConf = Get-ObjectsFromConfig -ObjectType NavigationBarConfiguration
    $searchScopeConf = Get-ObjectsFromConfig -ObjectType SearchScopeConfiguration
    $objectVisualConf = Get-ObjectsFromConfig -ObjectType ObjectVisualizationConfiguration

    Convert-ToJson -Objects $homeConf -JsonName HomepageConfigurations
    Convert-ToJson -Objects $portalUIConf -JsonName PortalUIConfigurations
    if($conf){
        Convert-ToJson -Objects $conf -JsonName Configurations
    }
    Convert-ToJson -Objects $naviBarConf -JsonName NavigationBarConfigurations
    Convert-ToJson -Objects $searchScopeConf -JsonName SearchScopeConfigurations
    Convert-ToJson -Objects $objectVisualConf -JsonName ObjectVisualizationConfigurations
}

Function Compare-Portal {
    <#
    .SYNOPSIS
    Get the Portal resources from both the source and target MIM-Setup (by Get-ObjectsFromJson or Get-ObjectsFromConfig).
    Send the found resources to Compare-MimObjects.
    
    .DESCRIPTION
    Gets the Portal resources from the source (Get-ObjectsFromJson) and target MIM-Setup (Get-ObjectsFromConfig). 
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
        $PathToConfig
    )
    Write-Host "Starting compare of Portal configuration..."
    # Source of objects to be imported
    $UISrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigPortalUIConfigurations.json"
    $navSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigNavigationBarConfigurations.json"
    $srchScopeSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigSearchScopeConfigurations.json"
    $objVisSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigObjectVisualizationConfigurations.json"
    $homePSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigHomepageConfigurations.json"
    $confSrc = Get-ObjectsFromJson -JsonFilePath "$PathToConfig\ConfigConfigurations.json"

    # Target Setup objects, comparing purposes
    $UIDest = Get-ObjectsFromConfig -ObjectType PortalUIConfiguration
    $navDest = Get-ObjectsFromConfig -ObjectType NavigationBarConfiguration
    $srchScopeDest = Get-ObjectsFromConfig -ObjectType SearchScopeConfiguration
    $objVisDest = Get-ObjectsFromConfig -ObjectType ObjectVisualizationConfiguration
    $homePDest = Get-ObjectsFromConfig -ObjectType HomepageConfiguration
    $confDest = Get-ObjectsFromConfig -ObjectType Configuration

    # Comparing of the Source and Target Setup to create delta xml file
    Compare-Objects -ObjsSource $UISrc -ObjsDestination $UIDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $navSrc -ObjsDestination $navDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $srchScopeSrc -ObjsDestination $srchScopeDest -Anchor @("DisplayName", "Order") -path $path
    Compare-Objects -ObjsSource $objVisSrc -ObjsDestination $objVisDest -Anchor @("DisplayName") -path $path
    Compare-Objects -ObjsSource $homePSrc -ObjsDestination $homePDest -Anchor @("DisplayName") -path $path
    # Could be empty
    if ($confSrc -and $confDest) {
        Compare-MimObjects -ObjsSource $confSrc -ObjsDestination $confDest -Anchor @("DisplayName") -path $path 
    }
    Write-Host "Compare of Portal configuration completed."
}

Function Get-ObjectsFromConfig {
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
    # This looks for objectTypes and expects objects with the type ObjectType
    $objects = Search-Resources -Xpath "/$ObjectType" -ExpectedObjectType $ObjectType
    # Read only members, not needed for import (are generated in the MIM-Setup)
    $illegalMembers = @("CreatedTime", "Creator", "DeletedTime", "DetectedRulesList",
    "ExpectedRulesList", "ResourceTime", "ComputedMember")
    # Makes target a json and then converts it to an object
    if ($objects) {
        foreach($obj in $objects){
            foreach($illMem in $illegalMembers){
                $obj.psobject.properties.Remove("$illMem")
            }
        }
        $updatedObjs = ConvertTo-Json -InputObject $objects -Depth 4
        $objects = ConvertFrom-Json -InputObject $updatedObjs
    } else {
        Write-Host "No $ObjectType found to write to json"
    }
    return $objects
}

Function Convert-ToJson {
    <#
    .SYNOPSIS
    Converts objects to a json file using the json format.
    
    .DESCRIPTION
    Converts objects to a json file using the json format. The files are saved in a folder called MIMExportFiles.
    This folder is saved in the declared path from Export-MIMObjects.

    .PARAMETER Objects
    Array of objects that will be converted to a json file in a json format.

    .Parameter JsonName
    The name of the json file. The name will be placed between 'Config' and '.json'.
    #>
    param(
        [Parameter(Mandatory=$False)]
        [Array]
        $Objects,

        [Parameter(Mandatory=$True)]
        [String]
        $JsonName
    )
    
    if($Objects) {
        if (Test-Path -path "$path\MIMExportFiles") {
            foreach ($obj in $objects) {
                $objMembers = $obj.psobject.members | Where-Object membertype -Like 'noteproperty'
                $obj = $objMembers
            }
        } else {
            ConvertTo-Json -InputObject $Objects -Depth 4 -Compress | Out-File "$PathToConfig\Config$JsonName.json"
        }
    }
}

Function Get-ObjectsFromJson {
    <#
    .SYNOPSIS
    Retrieve resources from a json file.
    
    .DESCRIPTION
    Retrieve resources from a json file that has been created by Export-MimConfig. This file contains
    resources from a MIM-Setup that have been serialized and deserialized by using the json format.
    
    .EXAMPLE
    Get-ObjectsFromJson -JsonFilePath "ConfigPortalUI.json"
    #>
    param(
        [Parameter(Mandatory=$True)]
        [String]
        $JsonFilePath
    )

    if (Test-Path $JsonFilePath) {
        $objs = Get-Content $JsonFilePath | ConvertFrom-Json
        return $objs
    } else {
        Write-Host "$JsonFilePath not found (no objects from source or not created)." -ForegroundColor Red
    }
}

Function Compare-Objects {
    <#
    .SYNOPSIS
    Compares two arrays of MIM-object type resources and sends the differences to Write-ToXmlFile.
    
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
        #Write-Progress -Activity "Comparing objects" -Status "Completed compares out of $total" -PercentComplete ($i/$total*100)
        Write-Host "`rComparing $type objects: $i/$total... `t" -NoNewline
        $i++
        if ($Anchor.Count -eq 1) {
            $obj2 = $ObjsDestination | Where-Object{$_.($Anchor[0]) -eq $obj.($Anchor[0])}
        } elseif ($Anchor.Count -eq 2) { 
            # When ObjectType is BindingDescription or needs two anchors to find one object
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") { 
                # Find the corresponding object that matches the BoundAttributeType ID
                $RefToAttrSrc = $Global:ReferentialList.SourceRefAttrs | Where-Object{$_.ObjectID.Value -eq $obj.BoundAttributeType.Value}
                # Find the corresponding object that matches the source binded attribute with the destination attibute by Name
                $RefToAttrDest = $Global:ReferentialList.DestRefAttrs | Where-Object{$_.Name -eq $RefToAttrSrc.Name}

                $RefToObjSrc = $Global:ReferentialList.SourceRefObjs | Where-Object{$_.ObjectID.Value -eq $obj.BoundObjectType.Value}
                $RefToObjDest = $Global:ReferentialList.DestRefObjs | Where-Object{$_.Name -eq $RefToObjSrc.Name}

                if ($RefToAttrDest -and $RefToObjDest) {
                    #obj2 gets the correct object that corresponds to the source object
                    $obj2 = $ObjsDestination | Where-Object {$_.BoundAttributeType -like $RefToAttrDest.ObjectID -and 
                    $_.BoundObjectType -like $RefToObjDest.ObjectID}
                } else {
                    $obj2 = ""
                }

            } else {
                $obj2 = $ObjsDestination | Where-Object {$_.($Anchor[0]) -like $obj.($Anchor[0]) -and `
                $_.($Anchor[1]) -like $obj.($Anchor[1])}
            }
        } else { 
            # When ObjectType needs multiple anchors to find unique object
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") {
                $RefToAttrSrc = $Global:ReferentialList.SourceRefAttrs | Where-Object{$_.ObjectID.Value -eq $obj.BoundAttributeType.Value}
                $RefToAttrDest = $Global:ReferentialList.DestRefAttrs | Where-Object{$_.Name -eq $RefToAttrSrc.Name}

                $RefToObjSrc = $Global:ReferentialList.SourceRefObjs | Where-Object{$_.ObjectID.Value -eq $obj.BoundObjectType.Value}
                $RefToObjDest = $Global:ReferentialList.DestRefObjs | Where-Object{$_.Name -eq $RefToObjSrc.Name}

                if ($RefToAttrDest -and $RefToObjDest) {
                    #obj2 gets the correct object that corresponds to the source object
                    $obj2 = $ObjsDestination | Where-Object {$_.BoundAttributeType -like $RefToAttrDest.ObjectID -and 
                    $_.BoundObjectType -like $RefToObjDest.ObjectID}
                } else {
                    $obj2 = ""
                }

            } else {
                $obj2 = $ObjsDestination | Where-Object {$_.($Anchor[0]) -like $obj.($Anchor[0]) -and `
                $_.($Anchor[1]) -like $obj.($Anchor[1]) -and $_.($Anchor[2]) -eq $obj.($Anchor[2])}
            }
        }   
        # If there is no match between the objects from different sources, the not found object will be added for import
        if (!$obj2) {
            $NewObjCounter++
            if ($Anchor -contains "BoundAttributeType" -and $Anchor -contains "BoundObjectType") {
                if ($bindings -notcontains $RefToAttrSrc) {
                    $global:bindings.Add($RefToAttrSrc) | Out-Null
                }
                if ($bindings -notcontains $RefToObjSrc) {
                    $global:bindings.Add($RefToObjSrc) | Out-Null   
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
            # Sorts arrayLists befor compare
            if (($obj.psobject.members.TypeNameOfValue -like "*ArrayList").Count -gt 0) {
                foreach($objMem in $obj.psobject.members) {
                    if($objMem.Value -and $objMem.Value.GetType().Name -eq "ArrayList") {
                        $obj2Mem = $obj2.psobject.members | Where-Object {$_.Name -eq $objMem.Name}
                        $objMem.Value = $objMem.Value | Sort-Object
                        $obj2Mem.Value = $obj2Mem.Value | Sort-Object
                    }
                }
            }
            
            $compResult = Compare-Object -ReferenceObject $obj.psobject.members -DifferenceObject $obj2.psobject.members -PassThru
            # If difference found
            if ($compResult) {
                # To visually compare the differences yourself
                #Write-Host $obj -BackgroundColor Green -ForegroundColor Black
                #Write-Host $obj2 -BackgroundColor White -ForegroundColor Black
                $compObj = $compResult | Where-Object {$_.SideIndicator -eq '<='} # Difference in original!
                $resultComp = $compObj | Where-Object membertype -Like 'noteproperty'
                $updatedObj = [PSCustomObject]@{}
                foreach ($mem in $resultComp) {
                    $updatedObj | Add-Member -NotePropertyName $mem.Name -NotePropertyValue $mem.Value
                }
                $DifferenceCounter++
                $difference.Add($updatedObj) | Out-Null
            }
            $obj.ObjectID = $OriginId
        }
    }
    if ($difference -or $newObjs) {
        Write-Host "Differences found!" -ForegroundColor Yellow
        Write-Host "Found $NewObjCounter new $Type objects." -ForegroundColor Yellow
        Write-Host "Found $DifferenceCounter different $Type objects." -ForegroundColor Yellow
        if ($newObjs) {
            Write-ToXmlFile -DifferenceObjects $newObjs -path $path -Anchor $Anchor -newObjects
        }
        if ($difference) {
            Write-ToXmlFile -DifferenceObjects $difference -path $path -Anchor $Anchor
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
                            if($bindings -notcontains $RefToAttrSrc) {
                                $Global:bindings.Add($RefToAttrSrc) | Out-Null
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
                if($newObjects) {
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

    .PARAMETER Message
    A message that will appear in the folder browser prompt.
    
    .LINK
    https://stackoverflow.com/questions/11412617/get-a-folder-path-from-the-explorer-menu-to-a-powershell-variable
    #>
    param (
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