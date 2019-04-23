#
# Module manifest for module 'IS4U.FimPortal'
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'IS4U.FimPortal.Migrate.Json.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0'
    
    # ID used to uniquely identify this module
    GUID = 'bc91736f-58f9-487f-91ea-fbb724598999'
    
    # Author of this module
    Author = 'Wim Beck'
    
    # Company or vendor of this module
    CompanyName = 'IS4U'
    
    # Copyright statement for this module
    Copyright = 'Copyright (C) 2016 by IS4U (info@is4u.be)
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation version 3.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    A full copy of the GNU General Public License can be found
    here: http://opensource.org/licenses/gpl-3.0.'
    
    # Description of the functionality provided by this module
    # Description = ''
    
    # Minimum version of the Windows PowerShell engine required by this module
    # PowerShellVersion = ''
    
    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''
    
    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''
    
    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''
    
    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''
    
    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''
    
    # Modules that must be imported into the global environment prior to importing this module
    <#RequiredModules = @(@{ModuleName = 'FimPowershellModule'; ModuleVersion = '2.2'}, @{ ModuleName = 'IS4U'; ModuleVersion = '1.0'},
    @{ModuleName = 'IS4U.FimPortal.Schema'; ModuleVersion = '1.0'}, @{ ModuleName = 'IS4U.FimPortal'; ModuleVersion = '1.0'})#>
    
    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()
    
    # Functions to export from this module
    FunctionsToExport = 'Start-Migration', 'Export-MIMSetup', 'Start-FimDelta', 'Convert-ToJson', 'Get-ObjectsFromJson', 'Compare-Objects', 'Write-ToXmlFile', 'Select-FolderDialog', 'Import-Delta'
    
    # Cmdlets to export from this module
    CmdletsToExport = ''
    
    # Variables to export from this module
    VariablesToExport = ''
    
    # Aliases to export from this module
    AliasesToExport = ''
    
    # DSC resources to export from this module
    # DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    # ModuleList = @()
    
    # List of all files packaged with this module
    FileList = @("FimDelta.exe")
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            # Tags = @()
    
            # A URL to the license for this module.
            # LicenseUri = ''
    
            # A URL to the main website for this project.
            # ProjectUri = ''
    
            # A URL to an icon representing this module.
            # IconUri = ''
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
        } # End of PSData hashtable
    
    } # End of PrivateData hashtable
    
    # HelpInfo URI of this module
    # HelpInfoURI = ''
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
    
    }
    
    