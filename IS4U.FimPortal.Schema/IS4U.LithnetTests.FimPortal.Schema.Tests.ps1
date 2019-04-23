Import-Module IS4U.FimPortal.Schema
<#
Navigate to the "/IS4U.FimPortal.Schema" folder
If testing while connected to a MIM-Environment:
Make sure Save-Resource calls in functions are in comment so no new objects are actually created
Start tests with: PS > Invoke-Pester
#>

Describe "New-Person" {
    Mock New-Resource {
        $obj = [PSCustomObject]@{
            Address = ""
            City = ""
            Country = ""
            Department = ""
            DisplayName = ""
            Domain = ""
            EmailAlias = ""
            EmployeeId = ""
            EmployeeType = ""
            FirstName = ""
            JobTitle = ""
            LastName = ""
            OfficePhone = ""
            PostalCode = ""
            RasAccessPermission = ""
        }
    return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = New-Person -Address "Street lane" -City Edegem -Country BE -Department Sec -DisplayName MSamson `
        -Domain FIM -EmailAlias msamson -EmployeeID 6555 -EmployeeType Intern -FirstName Mark -JobTitle Engineer -LastName Samson `
        -OfficePhone 045578461 -PostalCode 2650
        It "New-Resource gets called" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -Exactly 1
        }
        It "New-Resource uses correct parameters" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                #$ObjectType -eq "User"     ## User is DisplayName, Person is ObjectType
                $ObjectType -eq "Person"
            }
        }
        It "Save-Resource should get correct object input (using return from New-Person with variable resource)" {
            $result.FirstName | Should be "Mark"
            $result.RasAccessPermission | Should be $False
            $result.EmployeeId | Should be 6555
            $result.OfficePhone.GetType() | Should be int
        }
    }
}

Describe "Update-Person" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            Address = ""
            City = ""
            Country = ""
            Department = ""
            DisplayName = ""
            Domain = ""
            EmailAlias = ""
            EmployeeId = ""
            EmployeeType = ""
            FirstName = ""
            JobTitle = ""
            LastName = ""
            OfficePhone = ""
            PostalCode = ""
            RasAccessPermission = ""
        }
    return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = Update-Person -DisplayName "Test" -FirstName "VV" -LastName "PP"
        it "Get-Resource gets called with correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                #$ObjectType -eq "User" ##Is DisplayName
                $ObjectType -eq "Person"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "Test"
            }
        }

        it "Correct parameters from Update-Person get used to update the person" {
            $result.DisplayName | Should be "Test"
            $result.FirstName | Should be "VV"
            $result.LastName | Should be "PP"
        }
    }
}

Describe "Remove-Person" {
    Mock Get-Resource {
        #return [Guid]"9a096ed2-825b-43ae-9bb6-86045293c67e" ## Previous
        $obj = [PSCustomObject]@{
            ObjectId = @{Value = [Guid]"9a096ed2-825b-43ae-9bb6-86045293c67e"}
        }
        return $obj
    }-ModuleName "IS4U.FimPortal.Schema"
    Mock Remove-Resource -ModuleName "IS4U.fimPortal.Schema"
    Context "With parameter" {
        Remove-Person -DisplayName MSamson
        It "Get-Resource uses correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter{
                #$ObjectType -eq "User"
                $ObjectType -eq "Person"
                $AttributeName | Should be "DisplayName"
                $AttributeValue | Should be "MSamson"
                $AttributesToGet | Should be "ObjectID"
            }
        }
        It "Remove-Resource uses correct ID type" {
            Assert-MockCalled Remove-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ID -eq "9a096ed2-825b-43ae-9bb6-86045293c67e"
            }
        }
    }
}

Describe "New-Attribute" {
    Mock New-Resource {
        <#
            PSCustomObject is used here instead of New-MockObject.
            This is because New-MockObject only accepts the parameter -Type.
            A request for parameters in New-MockObject has been made but not yet implemented (limitations and practicality):
            https://github.com/pester/Pester/issues/694
            PSCustomObject lets us return an object with variables that can be filled and tested.
        #>
        $test = [PSCustomObject]@{
                DisplayName = ""    # Empty values (not null) because Hashtable requires Keys that are set
                Name = ""           # These get filled in the tested function
                Description = ""
                DataType = "" 
                MultiValued = ""
            }
        return $test
    } -ModuleName "IS4U.FimPortal.Schema"
    # Save-Resource can not be mocked when the required parameter is not of RmaObject type.
    # If this type is forced it will not accept the PsCustomObject that gets used as variable in RmaObject
    #Mock Save-Resource -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = New-Attribute -Name Visa -DisplayName Visa -Type String -MultiValued "False"
        It "New-Resource gets called" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -Exactly 1
        }
        It "New-Resource gets correct parameters" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                # At least one -eq comparison has to be entered for the ParameterFilter work
                $ObjectType -eq "AttributeTypeDescription" 
            }
        }
        It "obj gets filled and should be send to Save-Resource" {
            $result.DisplayName | Should be "Visa"
            $result.Name | Should be "Visa"
            $result.DataType | Should be "String"
            $result.MultiValued | Should be "False"
            $result.Description | Should beNullOrEmpty
        }
    }
}

Describe "Update-Attribute" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            Name = ""
            DisplayName = "" 
            Description = ""
        }
        # psTypeNames does not work here, only correct variables of a specific type can be inserted in a RmaObject
        #$obj.psTypeNames.Insert(0, "Lithnet.ResourceManagement.Automation.RmaObject[]")
        return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Mock Save-Resource -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = Update-Attribute -Name "Visa" -DisplayName "Visa" -Description "Test"
        It "New-Resource gets correct parameters when called" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "AttributeTypeDescription" -and $AttributeName -eq "Name"
                $AttributeValue | Should be "Visa"
            }
        }
        It "obj gets filled and should be send to Save-Resource" {
                $result.DisplayName | Should be "Visa"
                $result.Description | Should be "Test"
        }
    }
}

Describe "Remove-Attribute" {
    Mock Get-Resource { 
        $obj = [PSCustomObject]@{
            ObjectId = @{Value = [Guid]"2527a08a-2158-4bac-96a1-ca0c16400beb"}
        }
        return $obj
     } -ModuleName "IS4U.FimPortal.Schema"
    Mock Remove-Resource -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        Remove-Attribute -Name "Visa"
        It "Get-Resource sends correct parameters" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "AttributeTypeDescription"
                $AttributeName | Should be "Name"
                $AttributeValue | Should be "Visa"
            }
        }
        It "Remove-Resource gets called With correct parameter" {
            Assert-MockCalled Remove-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ID -eq "2527a08a-2158-4bac-96a1-ca0c16400beb"
            }
        }
    }
}

Describe "New-Binding" {
    Mock Get-Resource {New-Guid} -ModuleName "IS4U.FimPortal.Schema"
    Mock New-Resource {
        $obj = [PSCustomObject]@{
            Required = ""
            DisplayName = "" 
            Description = ""
            BoundAttributeType = ""
            BoundObjectType = ""
            id = ""
        }
        return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters (Get-Resource returns a Guid)" {
        $result = New-Binding -AttributeName "Visa" -DisplayName "Visa Card Number"
        It "Get-Resource gets called 3 times" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -Exactly 3
        }
        It "obj uses correct parameter for New-Resource" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "BindingDescription"
            }
        }
        It "attrId and objId get a Guid from Get-Resource" {
            $result.BoundAttributeType.GetType() -eq [guid] | Should be $True
            $result.BoundObjectType.GetType() -eq [guid] | Should be $True
        }
        It "attrId uses correct parameters for Get-Resource" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "AttributeTypeDescription" -and $AttributeValue -eq "Visa"
            } -Exactly 1
        }
        It "objId uses correct parameters for Get-Resource" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription" -and $AttributeValue -eq "Person"
            } -Exactly 1
        }
        It "obj.id (id) uses correct parameters for Get-Resource" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "BindingDescription" -and $AttributeValue -eq "Visa Card Number"
            }
        }
    }
}

Describe "Update-Binding" {
    Context "With parameters; Get-Resource returns a guid 3 times and then an object"{
        <#  In Update-Binding (with Lithnet) the Get-Resource function gets called 4 times and
            requires 2 different returns (2 mocks would mean that the second mock will be
            ignored). For this we need a counter that gives a different return after so many calls  #>
<#
        $global:mockCounter = 0                 # global variable so that it can be accessed in $mockTest
        $mockTest = {
            $global:mockCounter++               # Without global this variable would have not been set
            if ($mockCounter -lt 3) {           # Get-Resource gets called 4 times (counter starts at 1) 
                return New-Guid                 # First 2 times Get-Resource returns a New-Guid (testing purposes)
            } elseif ($mockCounter -eq 3) {     # When counter = 3 Get-Resource returns a PsCustomObject with only ObjectID attribute
                $obj = [PSCustomObject]@{
                    ObjectId = @{Value = New-Guid}
                }
                return $obj
            } 
            else {
                $obj = [PSCustomObject]@{
                    Required = ""
                    DisplayName = ""
                    Description = ""
                }
                return $obj                     # After the 3rd call, Get-Resource returns a PsCustomObject
            }
        }
        #>
        <# Use -MockWith on Get-Resource without {}, we want to return the return of the variable $mockTest.
        If {} is used the Mock will give a "variable not set" error. #>
        Mock Get-Resource {
            $obj = [PSCustomObject]@{
                Required = ""
                DisplayName = ""
                Description = ""
                ObjectID = @{Value = [Guid]"111dc7af-bbf3-4d51-b294-c26c874fc8cc"}
            }
            return $obj
        } -ModuleName "IS4U.fimPortal.Schema"# -MockWith $mockTest 
        $result = Update-Binding -AttributeName "Visa" -DisplayName "Visa Card Number"
        It "Get-Resource gets called 4 times" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -Exactly 4
        }
        It "Get-Resource uses correct parameters for variable attrId" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "AttributeTypeDescription" -and $AttributeValue -eq "Visa" -and $AttributesToGet -eq "ObjectID"
                                                                                                ## previously: -eq "ID"
            } -Exactly 1
        }
        It "Get-Resource uses correct parameters for variable objId" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription" -and $AttributeValue -eq "Person" -and $AttributesToGet -eq "ObjectID"
            } -Exactly 1
        }
        It "Get-Resource uses correct parameters for variable id" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "BindingDescription" -and $AttributeValuePairs.BoundAttributeType `
                -eq "111dc7af-bbf3-4d51-b294-c26c874fc8cc" -and $AttributesToGet -eq "ObjectID"
            } -Exactly 1
        }
        It "Get-Resource uses correct parameters for variable obj" {
            # Not possible to check if a New-Guid return is equal to an existing Guid
            # So check if the type is the same (should be if a Guid is returned)
            $result.GetType() -eq [Guid] | Should be $True
        }
    }
}
Describe "Remove-Binding" {
    Mock Get-Resource { 
        # Fixed Guid gets returned from Get-Resource only to check if variable $ID gets correct variable
        $obj = [PSCustomObject]@{
            ObjectID = @{Value = [Guid]"111dc7af-bbf3-4d51-b294-c26c874fc8cc"}
        }
        return $obj
     } -ModuleName "IS4U.FimPortal.Schema"
    Mock Remove-Resource -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameter" {
        Remove-Binding -AttributeName Visa
        It "Get-Resource uses correct parameters for variable attrId" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "AttributeTypeDescription" -and $AttributeValue -eq "Visa" -and $AttributesToGet -eq "ObjectID"
            } -Exactly 1
        }
        It "Get-Resource uses correct parameters for variable objId" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription" -and $AttributeValue -eq "Person" -and $AttributesToGet -eq "ObjectID"
            } -Exactly 1
        }
        It "Get-Resource uses correct parameters for variable id" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "BindingDescription" -and $AttributeValuePairs.BoundAttributeType -and $AttributesToGet -eq "ObjectID"
            } -Exactly 1
        }
        It "Remove-Resource uses correct parameters" {
            Assert-MockCalled Remove-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ID -eq "111dc7af-bbf3-4d51-b294-c26c874fc8cc"
            }
        }
    }
}
Describe "Import-SchemaBindings" {
    Mock New-Binding -ModuleName "IS4U.FimPortal.Schema"
    Context "With PesterTesting.csv file"{
        Import-SchemaBindings -CsvFile ".\PesterTesting.csv"
        It "New-Binding gets called 3 times (3 records in csv)" {
            Assert-MockCalled New-Binding -ModuleName "IS4U.FimPortal.Schema" -Exactly 3
        }
        It "New-Binding uses correct parameters (from first record)" {
            Assert-MockCalled New-Binding -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $AttributeName -eq "BirthDay" -and $DisplayName -eq "Birth date" -and $ObjectType -eq "Person"
            } -Exactly 1
        }
        It "New-Binding uses correct parameters (from third record)" {
            Assert-MockCalled New-Binding -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $AttributeName -eq "RoleDistributionList" -and $DisplayName -eq "Role gets a distribution list" -and $ObjectType -eq "Group"
            } -Exactly 1
        }
    }
}

Describe "New-ObjectType" {
    Mock New-Resource {
        [PSCustomObject]@{
            Name = ""
            DisplayName = ""
            Description = ""
        }
    } -ModuleName "IS4U.FimPortal.Schema"
    Mock Get-Resource { 
        $obj = [PSCustomObject]@{
            ObjectId = @{Value = "111dc7af-bbf3-4d51-b294-c26c874fc8cc"}
        }
        return $obj
     } -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = New-ObjectType -Name Department -DisplayName Departmen -Description Depart
        It "New-Resource uses correct parameters for variable obj" {
            Assert-MockCalled New-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription"
            }
        }
        It "Get-Resource uses correct parameters for variable obj" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription"
                $AttributeName | Should be "Name"
                $AttributeValue | Should be "Department"
                $AttributesToGet | Should be "ObjectID"     ##Previously ID
            }
        }
        It "New-ObjectType returns a GUID" {
            $result | Should be "111dc7af-bbf3-4d51-b294-c26c874fc8cc"
        }
    }
}

Describe "Update-ObjectType" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            Name = ""
            DisplayName = ""
            Description = ""
            ObjectID = @{Value = "111dc7af-bbf3-4d51-b294-c26c874fc8cc"}
        }
        return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameters" {
        $result = Update-ObjectType -Name Department -DisplayName Departme -Description Department
        It "Get-Resource uses correct parameters for variable obj" {
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription"
                $AttributeName | Should be "Name"
                $AttributeValue | Should be "department"
            } -Exactly 1    #-Exactly 1 to be sure it only gets called once with these parameters
        }
        It "Update-ObjectType returns a GUID" {
            $result | Should be "111dc7af-bbf3-4d51-b294-c26c874fc8cc"
        }
    }
}

Describe "Remove-ObjectType" {
    Mock Get-Resource {
        $obj = [PSCustomObject]@{
            ObjectID = @{Value = "111dc7af-bbf3-4d51-b294-c26c874fc8cc"}
        }
        return $obj
    } -ModuleName "IS4U.FimPortal.Schema"
    Mock Remove-Resource -ModuleName "IS4U.FimPortal.Schema"
    Context "With parameter" {
        It "Get-Resource uses the correct parameters" {
            Remove-ObjectType -Name Department
            Assert-MockCalled Get-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ObjectType -eq "ObjectTypeDescription"
                $AttributeName | Should be "Name"
                $AttributeValue | Should be "Department"
            }
        }
        It "Remove-Resource gets called with correct parameters" {
            Assert-MockCalled Remove-Resource -ModuleName "IS4U.FimPortal.Schema" -ParameterFilter {
                $ID -eq "111dc7af-bbf3-4d51-b294-c26c874fc8cc"
            }
        }
    }
}
#Set-ExecutionPolicy -Scope Process Unrestricted