Import-Module IS4U.FimPortal

Describe "New-Mpr"{
    Mock Get-Resource {New-Guid} -ModuleName "IS4U.FimPortal"
    Mock New-Resource {
        $object = [PSCustomObject]@{
            DisplayName = ""
            PrincipalSet = ""
            ResourceCurrentset = ""
            ResourceFinalSet = ""
            ActionType = @()
            ActionParameter = @()
            GrantRight = ""
            ManagementPolicyRuleType = ""
            AuthenticationWorkflowDefinition = ""
            Disabled = ""
            Description = ""
        }
        return $object
    } -ModuleName "IS4U.FimPortal"
    Context "With 2 items in array parameters and parameter AuthenticationWorkflowDefinition" {
        $result = New-Mpr -DisplayName "Test" -PrincipalSet New-Guid -ResourceCurrentSet New-Guid -ActionType @("test", "test2") `
        -ActionParameter @("actP", "ActP2") -GrantRight $True -ManagementPolicyRuleType "typetest" `
        -AuthenticationWorkflowDefinition New-Guid -ResourceFinalSet New-Guid

        It "New-Resource gets called with correct parameters" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
            }
        }
        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Test"
                $AttributesToGet | Should be "ObjectID"
            }
        }
        It "Resource gets correct input (to send with Save-Resource)" {
            $result.DisplayName | Should be "Test"
            $result.ActionType[0] | Should be "Test"
            $result.ActionParameter[1] | Should be "ActP2"
            $result.GrantRight | Should be $True
            $result.ManagementPolicyRuleType | Should be "typetest"
            $result.ResourceFinalSet.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
            $result.PrincipalSet.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
            $result.Description | Should be ""
        } 
        It "New-Mpr with parameter AuthenticationWorkflowDefinition gives GUID to variable resource" {
            $result.AuthenticationWorkflowDefinition.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
        }
        It "New-Mpr without parameter ActionWorkflowDefinition does not fill ActionWorkflowDefinition on resource" {
            $result.ActionWorkflowDefinition | Should be $null
        }
    }
}

Describe "Update-Mpr"{
    Mock Get-Resource {
        $object = [PSCustomObject]@{
            DisplayName = ""
            PrincipalSet = ""
            ResourceCurrentset = ""
            ResourceFinalSet = ""
            ActionType = @()
            ActionParameter = @()
            GrantRight = ""
            ManagementPolicyRuleType = ""
            AuthenticationWorkflowDefinition = ""
            Disabled = ""
            Description = ""
        }
        return $object
    } -ModuleName "IS4U.FimPortal"
    Context "With 2 items in array parameters and parameter AuthenticationWorkflowDefinition" {
        $result = Update-Mpr -DisplayName "Test" -PrincipalSet New-Guid -ResourceCurrentSet New-Guid -ActionType @("test", "test2") `
        -ActionParameter @("actP", "ActP2") -GrantRight $True -AuthenticationWorkflowDefinition New-Guid -ResourceFinalSet New-Guid

        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                ## AttributesToGet | Should be "ID" fails, problem with Pester probably
                $ObjectType -eq "ManagementPolicyRule" -and $AttributesToGet -eq "ObjectID"  # Solution to test AttributesToGet parameter
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Test"
            }
        }
        It "Resource gets correct input (to send with Save-Resource)" {
            $result.DisplayName | Should be "Test"
            $result.ActionType[0] | Should be "Test"
            $result.ActionParameter[1] | Should be "ActP2"
            $result.GrantRight | Should be $True
            $result.ResourceFinalSet.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
            $result.PrincipalSet.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
            $result.Description | Should be ""
        } 
        It "Update-Mpr with parameter AuthenticationWorkflowDefinition gives GUID to variable resource" {
            $result.AuthenticationWorkflowDefinition.GetType() | Should be Microsoft.ResourceManagement.WebServices.UniqueIdentifier
        }
        It "Update-Mpr without parameter ActionWorkflowDefinition does not fill ActionWorkflowDefinition on resource" {
            $result.ActionWorkflowDefinition | Should be $null
        }
    }
}

Describe "Remove-Mpr" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            ObjectId = @{Value = "d86d7e83-bc58-4dd2-b4d9-6bbcf5807570"}
        }
        return $obj
     } -ModuleName "IS4U.FimPortal"
    Mock Remove-Resource -ModuleName "IS4U.FimPortal"
    Context "With parameter DisplayName" {
        Remove-Mpr -DisplayName "Testing"
        It "Get-Resource uses correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Testing"
            }
        }
        It "Remove-Resource uses correct parameter" {
            Assert-MockCalled Remove-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ID -eq "d86d7e83-bc58-4dd2-b4d9-6bbcf5807570" 
            }
        }
    }
}

Describe "Enable-Mpr" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            Disabled = ""
        }
        return $obj
    } -ModuleName "IS4U.FimPortal"
    Context "With parameter" {
        $result = Enable-Mpr -DisplayName "Administration"
        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Administration"
            }
        }
        It "variable resource gets correct input" {
            $result.Disabled | Should be $false
        }
    }
}
Describe "Disable-Mpr" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            Disabled = ""
        }
        return $obj
    } -ModuleName "IS4U.FimPortal"
    Context "With parameter" {
        $result = Disable-Mpr -DisplayName "Administration"
        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Administration"
            }
        }
        It "variable resource gets correct input" {
            $result.Disabled | Should be $true
        }
    }
}

Describe "Add-AttributeToMpr" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            ActionParameter = @()
        }
        return $obj
    } -ModuleName "IS4U.FimPortal"
    Context "With parameter" {
        $result = Add-AttributeToMpr -AttrName "Visa" -MprName "Administration"
        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Administration"
            }
        }
        It "variable resource gets correct input" {
            $result.ActionParameter[0] | Should be "Visa"
        }
    }
}

Describe "Remove-AttributeFromMpr" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            ActionParameter = @("test1", "Visa", "test2")
        }
        return $obj
    } -ModuleName "IS4U.FimPortal"
    Context "With parameters" {
        $result = Remove-AttributeFromMpr -AttrName "Visa" -MprName "Administration"
        It "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.fimPortal" -ParameterFilter {
                $ObjectType -eq "ManagementPolicyRule"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Administration"
            }
        }
        It "Variable resource gets correct input and AttrName value gets removed from array" {
            $result.ActionParameter[0] | Should be "test1"
            $result.ActionParameter[1] | Should be "test2"
        }
    }
}