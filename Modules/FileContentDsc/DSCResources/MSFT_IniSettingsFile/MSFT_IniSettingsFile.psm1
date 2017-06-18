# Suppressed as per PSSA Rule Severity guidelines for unit/integration tests:
# https://github.com/PowerShell/DscResources/blob/master/PSSARuleSeverities.md
[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
param ()

Set-StrictMode -Version 'Latest'

$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the Storage Common Modules
Import-Module -Name (Join-Path -Path $modulePath `
        -ChildPath (Join-Path -Path 'FileContentDsc.Common' `
            -ChildPath 'FileContentDsc.Common.psm1'))

# Import the Storage Resource Helper Module
Import-Module -Name (Join-Path -Path $modulePath `
        -ChildPath (Join-Path -Path 'FileContentDsc.ResourceHelper' `
            -ChildPath 'FileContentDsc.ResourceHelper.psm1'))

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_IniSettingsFile' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

<#
    .SYNOPSIS
        Retrieves the current state of the INI settings file entry.

    .PARAMETER Path
        The path to the INI settings file to set the entry in.

    .PARAMETER Section
        The section to add or set the entry in.

    .PARAMETER Key
        The name of the key to add or set in the section.
#>
function Get-TargetResource
{
    [OutputType([Hashtable])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Section,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key
    )

    Assert-ParametersValid @PSBoundParameters

    Write-Verbose -Message ($localizedData.GetIniSettingMessage -f `
            $Path, $Section, $Key)

    $text = Get-IniSettingFileValue @PSBoundParameters

    return @{
        Path    = $Path
        Section = $Section
        Key     = $Key
        Type    = 'Text'
        Text    = $text
    }
}

<#
    .SYNOPSIS
        Sets the value of an entry in an INI settings file.

    .PARAMETER Path
        The path to the INI settings file to set the entry in.

    .PARAMETER Section
        The section to add or set the entry in.

    .PARAMETER Key
        The name of the key to add or set in the section.

    .PARAMETER Type
        Specifies the value type that contains the value to set the entry to. Defaults to 'Text'.

    .PARAMETER Text
        The text to set the entry value to.
        Only used when Type is set to 'Text'.

    .PARAMETER Secret
        The secret text to set the entry value to.
        Only used when Type is set to 'Secret'.
#>
function Set-TargetResource
{
    # Should process is called in a helper functions but not directly in Set-TargetResource
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '')]
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Section,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter()]
        [ValidateSet('Text', 'Secret')]
        [String]
        $Type = 'Text',

        [Parameter()]
        [String]
        $Text,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Secret
    )

    Assert-ParametersValid @PSBoundParameters

    if ($Type -eq 'Secret')
    {
        Write-Verbose -Message ($localizedData.SetIniSettingSecretMessage -f `
                $Path, $Section, $Key)

        $Text = $Secret.GetNetworkCredential().Password
        $null = $PSBoundParameters.Remove('Secret')
    }
    else
    {
        Write-Verbose -Message ($localizedData.SetIniSettingTextMessage -f `
                $Path, $Section, $Key, $Text)
    } # if

    # Prepare the for the PSBoundParameters to be splatted
    $null = $PSBoundParameters.Remove('Type')
    $null = $PSBoundParameters.Add('Value',$Text)
    $null = $PSBoundParameters.Remove('Text')

    Set-IniSettingFileValue @PSBoundParameters
}

<#
    .SYNOPSIS
        Tests the value of an entry in an INI settings file.

    .PARAMETER Path
        The path to the INI settings file to set the entry in.

    .PARAMETER Section
        The section to add or set the entry in.

    .PARAMETER Key
        The name of the key to add or set in the section.

    .PARAMETER Type
        Specifies the value type that contains the value to set the entry to. Defaults to 'Text'.

    .PARAMETER Text
        The text to set the entry value to.
        Only used when Type is set to 'Text'.

    .PARAMETER Secret
        The secret text to set the entry value to.
        Only used when Type is set to 'Secret'.
#>
function Test-TargetResource
{
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Section,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter()]
        [ValidateSet('Text', 'Secret')]
        [String]
        $Type = 'Text',

        [Parameter()]
        [String]
        $Text,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Secret
    )

    Assert-ParametersValid @PSBoundParameters

    if ($Type -eq 'Secret')
    {
        $Text = $Secret.GetNetworkCredential().Password
    } # if

    # Prepare the PSBoundParameters for splat
    $null = $PSBoundParameters.Remove('Type')
    $null = $PSBoundParameters.Remove('Text')
    $null = $PSBoundParameters.Remove('Secret')

    if ((Get-IniSettingFileValue @PSBoundParameters) -eq $Text)
    {
        Write-Verbose -Message ($localizedData.IniSettingMatchesMessage -f `
                $Path, $Section, $Key)

        return $true
    }
    else
    {
        Write-Verbose -Message ($localizedData.IniSettingMismatchMessage -f `
                $Path, $Section, $Key)

        return $false
    } # if
}

<#
    .SYNOPSIS
        Validates the parameters that have been passed are valid.
        If they are not valid then an exception will be thrown.

    .PARAMETER Path
        The path to the INI settings file to set the entry in.

    .PARAMETER Section
        The section to add or set the entry in.

    .PARAMETER Key
        The name of the key to add or set in the section.

    .PARAMETER Type
        Specifies the value type that contains the value to set the entry to. Defaults to 'Text'.

    .PARAMETER Text
        The text to set the entry value to.
        Only used when Type is set to 'Text'.

    .PARAMETER Secret
        The secret text to set the entry value to.
        Only used when Type is set to 'Secret'.
#>
function Assert-ParametersValid
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Section,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Key,

        [Parameter()]
        [ValidateSet('Text', 'Secret')]
        [String]
        $Type = 'Text',

        [Parameter()]
        [String]
        $Text,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Secret
    )

    # Does the file in path exist?
    if (-not (Test-Path -Path $Path))
    {
        New-InvalidArgumentException `
            -Message ($localizedData.FileNotFoundError -f $Path) `
            -ArgumentName 'Path'
    } # if
}

Export-ModuleMember -Function *-TargetResource