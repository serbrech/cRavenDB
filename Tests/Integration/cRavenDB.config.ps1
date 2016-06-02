configuration cRavenDB_Config
{

    Import-DscResource -ModuleName cRavenDB

    cRavenDB installRavenDB
    {
        Name = "RavenDB-test"
        Version = "3.5.35113-Unstable"
        #PackagePath = "C:\gitwp\AzureResourceTemplates\src\RavenDb\DSC\cRavenDB\Tests\Integration\packagesource\RavenDB.Server.3.0.30115.nupkg"
        InstallPath = "$env:temp\ravendb\test"
        DataDir = "$env:temp\ravendb\test\dbdata"
        Ensure = "Present"
        Port = 1234
    }

    <# cRavenDB removeRavenDB
    {
        Name = "RavenDB-test_notexist"
        Version = "3.0.30115"
        InstallPath = "$env:temp\ravendb\test"
        DataDir = "$env:temp\ravendb\test\dbdata"
        Ensure = "Absent"
        Port = 1234
    } #>
}
