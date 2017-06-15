﻿[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

Import-Module -Name (Join-Path -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers') -ChildPath 'CommonTestHelper.psm1')

$script:testEnvironment = Enter-DscResourceTestEnvironment `
    -DscResourceModuleName 'FileContentDsc' `
    -DscResourceName 'MSFT_ReplaceText' `
    -TestType 'Integration'

$script:testText = 'TestText'

$script:testPassword = 'TestPassword'

$script:testSearch = "Setting\.Two='(.)*'"

$script:testTextReplace = "Setting.Two='$($script:testText)'"

$script:testPasswordReplace = "Setting.Two='$($script:testPassword)'"

$script:testFileContent = @"
Setting1=Value1
Setting.Two='Value2'
Setting.Two='Value3'
Setting.Two='$($script:testText)'
Setting3.Test=Value4
"@

$script:testFileExpectedTextContent = @"
Setting1=Value1
Setting.Two='$($script:testText)'
Setting.Two='$($script:testText)'
Setting.Two='$($script:testText)'
Setting3.Test=Value4
"@

$script:testFileExpectedPasswordContent = @"
Setting1=Value1
Setting.Two='$($script:testPassword)'
Setting.Two='$($script:testPassword)'
Setting.Two='$($script:testPassword)'
Setting3.Test=Value4
"@

try
{
    Describe 'ReplaceText Integration Tests' {
        BeforeAll {
            $script:confgurationFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'MSFT_ReplaceText.config.ps1'
        }

        Context 'A text file being replaced with a text string' {
            It 'Should update the test text file' {
                $configurationName = 'ReplaceText'
                $testTextFile = Join-Path -Path $TestDrive -ChildPath 'TestFile.txt'

                Set-Content `
                    -Path $testTextFile `
                    -Value $script:testFileContent `
                    -Force

                $resourceParameters = @{
                    Path     = $testTextFile
                    Search   = $script:testSearch
                    Type     = 'Text'
                    Text     = $script:testTextReplace
                }

                try
                {
                    {
                        . $script:confgurationFilePath -ConfigurationName $configurationName
                        & $configurationName -OutputPath $TestDrive @resourceParameters
                        Start-DscConfiguration -Path $TestDrive -ErrorAction 'Stop' -Wait -Force -Verbose
                    } | Should Not Throw

                    { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw

                    $current = Get-DscConfiguration | Where-Object {
                        $_.ConfigurationName -eq $configurationName
                    }
                    $current.Path             | Should Be $resourceParameters.Path
                    $current.Search           | Should Be $resourceParameters.Search
                    $current.Type             | Should Be 'Text'
                    $current.Text             | Should Be "$($script:testTextReplace),$($script:testTextReplace),$($script:testTextReplace)"
                }
                finally
                {
                    if (Test-Path -Path $testTextFile)
                    {
                        Remove-Item -Path $testTextFile -Force
                    }
                }
            }
        }
    }
}
finally
{
    Exit-DscResourceTestEnvironment -TestEnvironment $script:testEnvironment
    Remove-Module -Name CommonTestHelper
}