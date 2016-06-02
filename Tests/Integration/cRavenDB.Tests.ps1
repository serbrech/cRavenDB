$Global:DSCModuleName   = 'cRavenDB'
$Global:DSCResourceName = 'cRavenDB'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
Write-Debug "ModuleRoot : $moduleRoot"
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else
{
    & git @('-C',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Integration `
    -ResourceType Class

Write-Host $env:PSModulePath -ForegroundColor Yellow
Get-Module cRavenDB -ListAvailable | Write-Host -ForegroundColor Yellow
#endregion

try
{
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($Global:DSCResourceName).config.ps1"
    . $ConfigFile

    [string] $tempName = "$($Global:DSCResourceName)_" + (Get-Date).ToString("yyyyMMdd_HHmmss")

    Describe "$($Global:DSCResourceName)_Integration" {

        $configValues = Get-DscConfiguration
        Write-Host $configValues -ForegroundColor Yellow
        #region DEFAULT TESTS
        It 'Should run without throwing' {
            {
                Invoke-Expression -Command "$($Global:DSCResourceName)_Config -OutputPath `$TestEnvironment.WorkingFolder"
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should unzip filed in install folder' {
            {
                $exists = Test-Path "$($configValues.InstallPath)\Raven.Server.exe"
                Write-Host "$($configValues.InstallPath) EXISTS!" -ForegroundColor Yellow
                "$($configValues.InstallPath)\Raven.Server.exe" | Should Exist
            }
        }

        It 'Should have installed ravendb' {
            {
                $result = Get-DscConfiguration
                $result.Ensure | Should Be "Present"
            }
        }

        It 'Should be respond to http request on given port' {
            {
                $result = Get-DscConfiguration
                $webresponse = try { Invoke-WebRequest -Uri "http://localhost:$($result.Port)/databases" -Method Get -ErrorAction SilentlyContinue } catch { $_.Exception.Response }
                $webresponse.StatusCode | Should Be 200
                $webresponse.RawContent | Should Be '[]'
            }
        }
    }
}
finally
{
    Write-Information "Entering Finally block. cleaning up."
    $configValues = Get-DscConfiguration
    $service = gsv "$($configValues.Name)*"
    if ($($configValues.Ensure) -eq 'Present') {
  		& "$($configValues.InstallPath)\Raven.Server.exe" --uninstall --service-name=$($configValues.Name)
  		$id = gwmi Win32_Service -Filter "Name LIKE '$($configValues.Name)'" | select -expand ProcessId
  		if($id -gt 0) {
  			Stop-Process -Id $id -Force -Verbose
  		}
          #tried Wait-Process -Id $id, but it seems that it's not enough.
  		sleep 1
  		rm -Recurse -Force $($configValues.InstallPath) -Verbose
   }
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
