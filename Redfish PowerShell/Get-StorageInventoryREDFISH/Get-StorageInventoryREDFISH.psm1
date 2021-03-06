<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 2.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   Cmdlet used to get storage inventory using Redfish API.
.DESCRIPTION
   Cmdlet used to get storage inventory using Redfish API. It will return storage information for controllers, disks or backplanes.
.EXAMPLE
   Get-StorageInventoryREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -get_storage_controllers y 
   This example will return all storage controllers detected. It's recommended to run this first to get the controller name. This will be needed when you execute
   the cmdlet to get disks and backplane, you have to pass in controller name as an argument.
.EXAMPLE
   Get-StorageInventoryREDFISH -idrac_ip 192.168.0.120 -username root -password calvin -storage_controller RAID.Integrated.1-1 -get_disks y
   This example is going to return all drives and disks for storage controller RAID.Integrated.1-1
#>

function Get-StorageInventoryREDFISH {


param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$True)]
    [string]$idrac_username,
    [Parameter(Mandatory=$True)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$get_storage_controllers,
    [Parameter(Mandatory=$False)]
    [string]$storage_controller,
    [Parameter(Mandatory=$False)]
    [string]$get_disks
    )


function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    ## We create an instance of TrustAll and attach it to the ServicePointManager
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

Ignore-SSLCertificates

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)


if ($get_storage_controllers -eq "y")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage"
try
{
$r = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
}
catch
{
Write-Host
$RespErr
return
}
if ($r.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to get storage controller(s)",$r.StatusCode)
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}

$a=$r.Content

Write-Host
$regex = [regex] '/Storage/.+?"'
$allmatches = $regex.Matches($a)
$z=$allmatches.Value.Replace('/Storage/',"")
$controllers=$z.Replace('"',"")
Write-Host "- Server controllers detected -`n"
$controllers
Write-Host
return
}

if ($get_storage_controllers -eq "n")
{
return
}

if ($get_disks -eq "y" -and $storage_controller -ne "")
{
$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/$storage_controller"
    try
    {
    $result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
    }
    catch
    {
    Write-Host
    $RespErr
    return
    }

$z=$result.Content | ConvertFrom-Json
$count = 0
Write-Host "`n- Drives detected for controller '$storage_controller' -`n"
$raw_device_count=0
    foreach ($item in $z.Drives)
    {
    $zz=[string]$item
    $zz=$zz.Split("/")[-1]
    $drive=$zz.Replace("}","")
    $u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Storage/Drives/$drive"
    $result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing -Headers @{"Accept"="application/json"}
    $zz=$result.Content | ConvertFrom-Json
    $zz.id
    }
Write-Host
return
}
}

