param(
    [string]$apiKey,
    [string]$version
)
if(!$version){
    throw "set a version carefully"
}

$modulepath = Resolve-Path "$PSScriptRoot/DSCResources/cRavenDB"
if(-not ($Env:PSModulePath.Split(";") -contains $modulepath)){
    $Env:PSModulePath = "$modulepath;$Env:PSModulePath"
}

Publish-Module -Name cRavenDB -NuGetApiKey $apiKey -RequiredVersion $version