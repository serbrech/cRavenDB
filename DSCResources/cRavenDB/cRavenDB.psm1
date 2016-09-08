enum Ensure {
    Present
    Absent
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
		    $this.RemoveRavenDb()
        }
    }

##############
 
    [void] InstallRavenDb()
    {
	    Write-Information "Ensure Present, begin installation"

        if(!(Test-Path $this.InstallPath)) {
            Write-Debug "InstallPath not found, creating directory"
            New-Item -ItemType Directory $this.InstallPath
        }
        if($this.PackagePath -and $this.PackagePath -ne ''){
            Copy-Item -Path $this.PackagePath -Destination "$($this.InstallPath)\RavenDB.Server.$($this.Version).nupkg" -Force
        } else {
            $location = 'https://www.nuget.org/api/v2/';
        
            if(-not (Get-PackageProvider NuGet -ErrorAction SilentlyContinue)){ 
                Write-Verbose "Installing Nuget package provider";
                Find-PackageProvider NuGet|Install-PackageProvider -Force 
            }

            if(-not (Get-PackgageSource -ProviderName NuGet -Location $location -ErrorAction SilentlyContinue)){
                Write-Verbose "Registrering Nuget package source";
                Register-PackageSource -Name $location -Location $location -ProviderName NuGet -Force;
            }
            Save-Package RavenDB.Server -RequiredVersion $this.Version -Path $this.InstallPath -Source "https://www.nuget.org/api/v2/"
        }                
        $this.Unzip("$($this.InstallPath)\RavenDB.Server.$($this.Version).nupkg", "tools*", $this.InstallPath)
        $appSettingsPath = "$($this.InstallPath)\Raven.Server.exe.config"
        $this.SetAppSettings($appSettingsPath, "Raven/Port", $this.Port)
        $this.SetAppSettings($appSettingsPath, "Raven/DataDir/Legacy", $this.DataDir)
        $this.SetAppSettings($appSettingsPath, "Raven/DataDir", $this.DataDir)

        & "$($this.InstallPath)\Raven.Server.exe" --install --service-name="$($this.Name)"
    }

    [void] RemoveRavenDb() 
    {
	    Write-Verbose "Ensure Absent, Uninstalling RavenDB service"

        $serviceCount = @(gsv $this.Name -ErrorAction SilentlyContinue).count -gt 0

        if($serviceCount -eq 0){
            Write-Verbose "No ravendb service found running on this machine"
            return
        }

        $exePath = "$($this.InstallPath)\Raven.Server.exe"
        if(Test-Path $exePath) {
            & $exePath --uninstall --service-name $this.Name

		    #make sure the process is gone. if not kill it now.
		
		    $id = gwmi Win32_Service -Filter "Name LIKE '$($this.Name)'" | select -expand ProcessId
		    if($id -gt 0) {
			    Stop-Process -Id $id -Force -Verbose
			    Wait-Process $id
		    }
		
            Write-Verbose "RavenDB service uninstalled"
        }

        if(-not (Test-Path $this.InstallPath)) {
            Write-Warning "InstallPath not found"
        }
        else {
            if($this.DeleteFilesAndData){
                Remove-Item -Path $this.InstallPath -Recurse -Force
            }
        }

        if(-not (Test-Path $this.DataDir)) {
            Write-Warning "Data directory not found or already deleted"
        }
        else {
            if($this.DeleteFilesAndData) {
                Remove-Item -Path $this.DataDir -Recurse -Force
            }
        }
    }

    [void] SetAppSettings([string]$config, [string]$key, [string]$value) 
    {
        $doc = New-Object System.Xml.XmlDocument
        $doc.Load($config)
        $node = $doc.SelectSingleNode('configuration/appSettings/add[@key="' + $key + '"]')
        $node.Attributes['value'].Value = $value
        $doc.Save($config)
    }

    [void] Unzip ([string]$zipfile, [string]$filePattern, [string]$outpath)
    {
        $tmpFolder = join-path $env:TEMP ("RavenInstallTmp{0}" -f (Get-Date).ToString("dd.MM.yyyy"))
        if((Test-Path $tmpFolder )){
            Remove-Item $tmpFolder -Force;
        }
        new-item -Path $tmpFolder -ItemType Directory -Force|out-null;
        $dest = (Join-Path $tmpFolder (Split-path $zipfile -Leaf).Replace('.nupkg','.zip'));
        Write-Verbose "Copying $zipfile to destination $dest";
        Copy-Item $zipfile $dest|out-null;
        
        Write-Verbose "Unzipping $dest to $outpath "
        Expand-Archive $dest -DestinationPath $tmpFolder -Force;         
        
        Get-ChildItem -File (Join-path $tmpFolder "tools")|ForEach-Object {
            Copy-Item $_.FullName -Destination $outpath -Force
        }

        Write-Verbose 'Removing temp files';
        Remove-Item $tmpFolder -Force;
    }

}

