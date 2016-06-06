$sut = "iis-set-authentication.steptemplate.ps1"
. "$PSScriptRoot\$sut"

Describe 'IIS - Sets Desired Authentication State' {
    $AnonymousAuth = "True"
    $WindowsAuth = "False"
    $DigestAuth = "False"
    $IISSitePaths = "Default Web Site/MockApp"

    #WebAdministration module must be installed to run these tests.
    $cmd = (Get-Command "Get-Website" -errorAction SilentlyContinue)
    if ($null -eq $cmd) {
        Get-Module -Name WebAdministration | Remove-Module -Force
        New-Module -Name WebAdministration  -ScriptBlock {
            function Get-Website { }
            Export-ModuleMember -Function Get-Website
            function Set-WebConfigurationProperty ($Value, $Location, $Filter) { }
            Export-ModuleMember -Function Set-WebConfigurationProperty
        } | Import-Module -Force
    }

    Context "Enabling Authentication" {
        It "Enables authentication on the site" {
            Mock Get-Website {return @{Name="Default Web Site/MockApp"; ID="0"; State="Stopped"; PhysicalPath="c:\test"; Bindings="test"}}
            Mock Set-WebConfigurationProperty

            Update-IISSiteAuthentication -State ($AnonymousAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "AnonymousAuthentication"  

            Assert-MockCalled Get-website -Exactly 1
            Assert-MockCalled Set-WebConfigurationProperty -Exactly 1 `
                -ParameterFilter { ($Value -eq $true ) -and ($Location -eq "Default Web Site/MockApp") -and ($Filter -eq "/system.WebServer/security/authentication/AnonymousAuthentication") }
        }
    }

    Context "Authentication Update Failed" {
        It "Authentication fails to update" {
            Mock Get-Website {return @{Name="Default Web Site/MockApp"; ID="0"; State="Stopped"; PhysicalPath="c:\test"; Bindings="test"}}
            Mock Set-WebConfigurationProperty { throw "A fake error test message"}
                
            { Update-IISSiteAuthentication -State ($DigestAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "DigestAuthentication"  } | should throw

            Assert-MockCalled Get-website -Exactly 1
            Assert-MockCalled Set-WebConfigurationProperty -Exactly 1 `
                -ParameterFilter { ($Value -eq $false ) -and ($Location -eq "Default Web Site/MockApp") -and ($Filter -eq "/system.WebServer/security/authentication/DigestAuthentication") }
        }
    }

    Context "Incorrect SitePath" {
        $IISSitePaths = "Default Web Site/DoesNotExist"

        It "IIS Site cannot be found" {
            Mock Get-Website {return @{Name=""; ID=""; State=""; PhysicalPath=""; Bindings=""}}
            Mock Set-WebConfigurationProperty

            { Update-IISSiteAuthentication -State ($WindowsAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "WindowsAuthentication"  } | should throw

            Assert-MockCalled Get-website -Exactly 1
            Assert-MockCalled Set-WebConfigurationProperty -Exactly 0
        }
    }
}