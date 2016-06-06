#requires -version 3

$StepTemplateName = "IIS - Enable or Disable Authentication Methods"
$StepTemplateDescription = "Step template to set the desired IIS Authentication (Anonymous, Windows, Digest) State for IIS site(s)"
$StepTemplateParameters = @(
    @{
        "Name" = "AnonymousAuth";
        "Label" = "Anonymous Authentication";
        "HelpText" = "Enable Anonymous Authentication.";
        "DefaultValue" = "False";
        "DisplaySettings" = @{
            "Octopus.ControlType" = "Checkbox";
        }
    },
    @{
        "Name" = "WindowsAuth";
        "Label" = "Windows Authentication";
        "HelpText" = "Enable Windows Authentication.";
        "DefaultValue" = "False";
        "DisplaySettings" = @{
            "Octopus.ControlType" = "Checkbox";
        }
    },
    @{
        "Name" = "DigestAuth";
        "Label" = "Digest Authentication";
        "HelpText" = "Enable Digest Authentication.";
        "DefaultValue" = "False";
        "DisplaySettings" = @{
            "Octopus.ControlType" = "Checkbox";
        }
    },
    @{
      "Name" = "IISSitePaths";
      "Label" = "IIS Site name(s)";
      "HelpText" = "The IIS site(s) which will have security permissions transformed. Multiple values are to be new-line separated.";
      "DefaultValue" = $null;
      "DisplaySettings" = @{
          "Octopus.ControlType"= "MultiLineText";
      } 
    }
)

function Update-IISSiteAuthentication {
    param
    (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [boolean]$State,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$SitePath,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory = $true)]
        [string]$AuthMethod
    )
    
    # check if WebAdministration module exists on the server
    $cmd = (Get-Command "Get-Website" -errorAction SilentlyContinue)
    if ($null -eq $cmd) {
        throw "The Windows PowerShell snap-in 'WebAdministration' is not installed on this server. Details can be found at https://technet.microsoft.com/en-us/library/ee790599.aspx."
    }
    
    $IISSecurityPath = "/system.WebServer/security/authentication/$AuthMethod"
    $separator = "`r","`n",","
    $IISSites = $sitepath.split($separator, [System.StringSplitOptions]::RemoveEmptyEntries).Trim(' ')

    $IISValidSites = Get-Website
    $IISValidSiteNames = $IISValidSites.Name -join ', '

    foreach($Site in $IISSites) {
        $IISSiteAvailable = $IISValidSites | Where-Object { $_.Name -eq $Site }

        if ($IISSiteAvailable) {
            Set-WebConfigurationProperty -Filter $IISSecurityPath -Name Enabled -Value $State -PSPath IIS:\ -Location $Site
            Write-Output "$AuthMethod for site '$Site' set successfully to '$State'."
        }
        else {
            Write-Output "The IISSitePath '$Site' cannot be found. The valid sites are $IISValidSiteNames"
            throw "The IISSitePath '$Site' cannot be found. The valid sites are $IISValidSiteNames"
        }
    }
}

if (Test-Path Variable:OctopusParameters) {
    Update-IISSiteAuthentication -State ($AnonymousAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "AnonymousAuthentication"
    Update-IISSiteAuthentication -State ($WindowsAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "WindowsAuthentication"
    Update-IISSiteAuthentication -State ($DigestAuth -eq "True") -SitePath $IISSitePaths -AuthMethod "DigestAuthentication"
}
