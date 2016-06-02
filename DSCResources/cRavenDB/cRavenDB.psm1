
enum Ensure {
    Present
    Absent
}

function Set-AppSettings {
    param($config, $key, $value)

    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($config)
    $node = $doc.SelectSingleNode('configuration/appSettings/add[@key="' + $key + '"]')
    $node.Attributes['value'].Value = $value
    $doc.Save($config)
}

function Unzip {
    param([string]$zipfile,[string]$filePattern, [string]$outpath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $ziparchive = [System.IO.Compression.ZipFile]::OpenRead($zipfile)
    $ziparchive.Entries | 
    Where-Object { $_.FullName -like $filePattern } |
    % { [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$outpath/$($_.Name)") }
    $ziparchive.Dispose()
}

[DscResource()] 
class cRavenDB {

    [DSCProperty(Key)] 
    [string] $Name

    [DSCProperty(Mandatory)]
    [string] $Version

    [DSCProperty()]
    [string] $PackagePath = ''

    [DSCProperty(Mandatory)]
    [string] $InstallPath

    [DSCProperty(Mandatory)]
    [string] $DataDir

    [DSCProperty()]
    [Ensure] $Ensure

    [DSCProperty(Mandatory)]
    [string] $Port

    [DSCProperty()]
    [bool] $DeleteFilesAndData

    [cRavenDB] Get() 
    {
        $serviceFound = @(gsv $($this.Name) -ErrorAction SilentlyContinue).count -gt 0
        if($serviceFound){
            $this.Ensure = [Ensure]::Present
        }
        else{
            $this.Ensure = [Ensure]::Absent
        }
        return $this
    }


    [bool] Test()
    {
        $serviceFound = @(gsv $this.Name -ErrorAction SilentlyContinue).count -gt 0
        return $serviceFound -and ($this.Ensure -eq "Present")
    }

    [void] Set() 
    {
        if($this.Ensure -eq [Ensure]::Present) {
		    $this.InstallRavenDB()
        }
	    else {
		    Remove-RavenDb -Name $this.Name -InstallPath $this.InstallPath -DeleteFilesAndData $this.DeleteFilesAndData -DataDir $this.DataDir 
        }
    }

    [void] InstallRavenDb() 
    {
	    Write-Information "Ensure Present, begin installation"

        if(!(Test-Path $this.InstallPath)) {
            Write-Debug "InstallPath not found, creating directory"
            New-Item -ItemType Directory $this.InstallPath
        }
        if($this.PackagePath -ne ''){
            Copy-Item -Path $this.PackagePath -Destination "$($this.InstallPath)\RavenDB.Server.$($this.Version).nupkg" -Force
        }
        else {
            Save-Package RavenDB.Server -RequiredVersion $this.Version -Path $this.InstallPath -Source "https://www.nuget.org/api/v2/"
        }
        Unzip -zipfile "$($this.InstallPath)\RavenDB.Server.$($this.Version).nupkg" -filePattern "tools*" -outpath $this.InstallPath

        $appSettingsPath = "$($this.InstallPath)\Raven.Server.exe.config"
        Set-AppSettings $appSettingsPath "Raven/Port" $this.Port
        Set-AppSettings $appSettingsPath "Raven/DataDir/Legacy" $this.DataDir
        Set-AppSettings $appSettingsPath "Raven/DataDir" $this.DataDir

        & "$($this.InstallPath)\Raven.Server.exe" --install --service-name="$($this.Name)"
    }

}


########################################################


Function Remove-RavenDb {
	param(
        [string]
        $Name,
        [string]
        $InstallPath,
        [string]
        $DataDir,
		[bool]
        $DeleteFilesAndData
	)

	Write-Verbose "Ensure Absent, Uninstalling RavenDB service"

    $serviceCount = @(gsv $Name -ErrorAction SilentlyContinue).count -gt 0

    if($serviceCount -eq 0){
        Write-Verbose "No ravendb service found running on this machine"
        return
    }

    $exePath = "$InstallPath\Raven.Server.exe"
    if(Test-Path $exePath){
        & $exePath --uninstall --service-name $Name

		#make sure the process is gone. if not kill it now.
		
		$id = gwmi Win32_Service -Filter "Name LIKE '$Name'" | select -expand ProcessId
		if($id -gt 0) {
			Stop-Process -Id $id -Force -Verbose
			Wait-Process $id
		}

		
        Write-Verbose "RavenDB service uninstalled"
    }

    if(-not (Test-Path $InstallPath)) {
        Write-Warning "InstallPath not found"
    }
    else {
        if($DeleteFilesAndData){
            Remove-Item -Path $InstallPath -Recurse -Force
        }
    }

    if(-not (Test-Path $DataDir)) {
        Write-Warning "Data directory not found or already deleted"
    }
    else {
        if($DeleteFilesAndData) {
            Remove-Item -Path $DataDir -Recurse -Force
        }
    }
}





Export-ModuleMember -Function *-TargetResource

