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

Function Enable-Sspr
{
<#
.SYNOPSIS
Enables all MPR's required for SSPR.

.DESCRIPTION
Enables all MPR's required for SSPR.
#>
	Enable-Mpr "Anonymous users can reset their password"
	Enable-Mpr "Password reset users can read password reset objects"
	Enable-Mpr "Password Reset Users can update the lockout attributes of themselves"
	Enable-Mpr "User management: Users can read attributes of their own"
	Enable-Mpr "General: Users can read non-administrative configuration resources"
	Enable-Mpr "Administration: Administrators can read and update Users"
}

Function Disable-Sspr
{
<#
.SYNOPSIS
Disables some MPR's required for SSPR.

.DESCRIPTION
Disables some MPR's required for SSPR.
#>
	Disable-Mpr "Anonymous users can reset their password"
	Disable-Mpr "Password reset users can read password reset objects"
	Disable-Mpr "Password Reset Users can update the lockout attributes of themselves"
	Disable-Mpr "General: Users can read non-administrative configuration resources"
}

Function Install-LocalizedSspr
{
<#
.SYNOPSIS
Installs a Q&A SSPR configuration for other languages than the default based on the configuration in
workflow "Password Reset AuthN Workflow".

.DESCRIPTION
Installs a Q&A SSPR configuration for other languages than the default based on the configuration in
workflow "Password Reset AuthN Workflow".
More detailed configuration info is delivered by an xml configuration file.

.EXAMPLE
Install-LocalizedSspr -ConfigFile .\sspr.xml
#>	
	param(
		[Parameter(Mandatory=$True)]
		[String]
		$ConfigFile
	)
	Add-TypeAccelerators -Assembly System.Xml.Linq -Class XAttribute
	$config = [XDocument]::Load((Join-Path $pwd $ConfigFile))
	$root = [XElement] $config.Root
	
	$wf = Get-FimObject -Value "Password Reset AuthN Workflow" -Attribute DisplayName -ObjectType WorkflowDefinition
	$mpr = Get-FimObject -Value "Anonymous users can reset their password" -Attribute DisplayName -ObjectType ManagementPolicyRule
    [UniqueIdentifier] $actionWfId = Get-FimObjectID -ObjectType WorkflowDefinition -AttributeName DisplayName -AttributeValue "Password Reset Action Workflow"
    [UniqueIdentifier] $principalSetId = Get-FimObjectID -ObjectType Set -AttributeName DisplayName -AttributeValue "Anonymous users"

	foreach($language in $root.Elements("Language")) {
		[UniqueIdentifier] $setId = [Guid]::Empty
		[UniqueIdentifier] $wfId = [Guid]::Empty
		[UniqueIdentifier] $mprId = [Guid]::Empty

		$setConfig = $language.Element("Set")
		$setName = $setConfig.Attribute("DisplayName").Value
		$condition = $setConfig.Element("Filter").Value
		$setExists = Test-ObjectExists -Value $setName -Attribute DisplayName -ObjectType Set
		if($setExists){
			Write-Host "Update existing set '$setName'"
			$setId = Update-Set -DisplayName $setName -Condition $condition
		} else {
			Write-Host "Create set '$setName'"
			$setId = New-Set -DisplayName $setName -Condition $condition
		}

		$wfConfig = $language.Element("Workflow")
		$wfName = $wfConfig.Attribute("DisplayName").Value
		$constraint = $wfConfig.Element("Constraint").Value
		$errorText = $wfConfig.Element("Error").Value

		$xoml = $wf.XOML
		$i = 1
		foreach ($question in $wfConfig.Elements("Question")){
			$xoml = $xoml.Replace("Question $i</ns1:String>", $question.Value + "</ns1:String>")
			$i ++
		}
		$xoml = $xoml.Replace("=`"Constraint`"", "=`"$constraint`"")
		$xoml = $xoml.Replace("=`"Error`"", "=`"$errorText`"")

		$wfExists = Test-ObjectExists -Value $wfName -Attribute DisplayName -ObjectType WorkflowDefinition
		if($wfExists){
			Write-Host "Update existing wf '$wfName'"
			$wfId = Update-Workflow -DisplayName $wfName -Xoml $xoml
		} else {
			Write-Host "Create wf '$wfName'"
			$wfId = New-Workflow -DisplayName $wfName -RequestPhase Authentication -Xoml $xoml
		}

		$mprName = $language.Element("MPR").Attribute("DisplayName").Value
		$mprExists = Test-ObjectExists -Value $mprName -Attribute DisplayName -ObjectType ManagementPolicyRule
		if($mprExists){
			Write-Host "Update existing MPR '$mprName'"
			$mprId = Update-Mpr -DisplayName $mprName -ActionWfId $actionWfId -PrincipalSetId $principalSetId -SetId $setId -AuthWfId $wfId
		} else {
			Write-Host "Create MPR '$mprName'"
			$mprId = New-Mpr -DisplayName $mprName -ActionWfId $actionWfId -PrincipalSetId $principalSetId -SetId $setId -AuthWfId $wfId
		}
		
		Add-ObjectToSet "Password Reset Objects Set" $setId
		Add-ObjectToSet "Password Reset Objects Set" $wfId
		Add-ObjectToSet "Password Reset Objects Set" $mprId
	}
	Disable-Mpr "Anonymous users can reset their password"
}