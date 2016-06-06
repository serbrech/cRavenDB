# cRavenDB
Powershell DSCResource to install ravenDB

## Usage
```
cRavenDB installRavenDB
{
    Name = "RavenDB-test" #windows service name
    Version = "3.5.35113-Unstable"
    InstallPath = "C:\ravendb\" 
    DataDir = "C:\ravendb\data"
    Ensure = "Present"
    Port = 1234
}
```
