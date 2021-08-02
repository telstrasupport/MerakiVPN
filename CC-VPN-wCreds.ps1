#
# Powershell script to create a client VPN connection to a Meraki MX.  Generated using:
# https://www.ifm.net.nz/cookbooks/meraki-client-vpn.html
#
# Alterations:
# Change the delete existing to a simple check and exit if already exists
# Add Get-Credential and Set-VPNConnectionUsernamePassword for the profile once created
# Add logging to .\TBTC-VPN.log
#
# Configuration Parameters
$ProfileName = 'Centacare VPN'
$DnsSuffix = 'centacare.local'
$ServerAddress = 'centacare-wagga-new-tqrkkgcgjj.dynamic-m.com'
$L2tpPsk = 'C@r3hous3'

#
#Check if VPN already exists
#exit script if existing VPN found
#

$VPNs = Get-VpnConnection | select Name
foreach ($v in $VPNs){
    if ($v.Name -eq $ProfileName){
        Write-Output "Centacare VPN aready exists - exiting..." | Out-File -Append .\CC-VPN.log
        exit
        }
    else{
        Write-Output "VPN Profile Found:"| Out-File -Append .\TBTC-VPN.log
        Write-Output $v.Name | Out-File -Append .\TBTC-VPN.log
        }
}

Write-Output "'Centacare VPN' not found. Creating profile..." | Out-File -Append .\CC-VPN.log

#
# Build client VPN profile
# https://docs.microsoft.com/en-us/windows/client-management/mdm/vpnv2-csp
#

# Define VPN Profile XML
$ProfileNameEscaped = $ProfileName -replace ' ', '%20'
$ProfileXML =
	'<VPNProfile>
		<RememberCredentials>true</RememberCredentials>
		<DnsSuffix>'+$dnsSuffix+'</DnsSuffix>
		<NativeProfile>
			<Servers>' + $ServerAddress + '</Servers>
			<RoutingPolicyType>ForceTunnel</RoutingPolicyType>
			<NativeProtocolType>l2tp</NativeProtocolType>
			<L2tpPsk>'+$L2tpPsk+'</L2tpPsk>
		</NativeProfile>
'

# Configure split DNS
$ProfileXML += "  <DomainNameInformation><DomainName>mtgroup.com</DomainName><DnsServers>192.168.15.190</DnsServers></DomainNameInformation>`n"

$ProfileXML += '</VPNProfile>'

# Convert ProfileXML to Escaped Format
$ProfileXML = $ProfileXML -replace '<', '&lt;'
$ProfileXML = $ProfileXML -replace '>', '&gt;'
$ProfileXML = $ProfileXML -replace '"', '&quot;'

# Define WMI-to-CSP Bridge Properties
$nodeCSPURI = './Vendor/MSFT/VPNv2'
$namespaceName = 'root\cimv2\mdm\dmmap'
$className = 'MDM_VPNv2_01'

# Define WMI Session
$session = New-CimSession

#
#Install Credential Helper
#

Install-Module VPNCredentialsHelper

#
# Create VPN Profile
#

Write-Output "Creating 'Centacare VPN' VPN profile..."

try
{
	$newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('ParentID', "$nodeCSPURI", 'String', 'Key')
	$newInstance.CimInstanceProperties.Add($property)
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('InstanceID', "$ProfileNameEscaped", 'String', 'Key')
	$newInstance.CimInstanceProperties.Add($property)
	$property = [Microsoft.Management.Infrastructure.CimProperty]::Create('ProfileXML', "$ProfileXML", 'String', 'Property')
	$newInstance.CimInstanceProperties.Add($property)

	$session.CreateInstance($namespaceName, $newInstance, $options) | Out-Null
	Write-Output "Created '$ProfileName' profile." | Out-File -Append .\CC-VPN.log

    Write-Output "Getting Credentials for the VPN connection..." | Out-File -Append .\CC-VPN.log
    #$mcvpn = Get-Credential -Message "Please enter Meraki Client VPN credentials provided by IT"
    #Write-Output "Credentials entered by user." | Out-File -Append .\CC-VPN.log
    Write-Output "Setting Credentials for the VPN connection..." | Out-File -Append .\CC-VPN.log
    Set-VpnConnectionUsernamePassword -ConnectionName $ProfileName -Username "vpn@centacareswnsw.org.au" -password "8yWtpkeh"
    Write-Output "Credentials set for the VPN connection." | Out-File -Append .\CC-VPN.log
    Write-Output "VPN Profile for 'Centacare VPN' is now complete." | Out-File -Append .\CC-VPN.log
}
catch [Exception]
{
	Write-Output "Unable to create $ProfileName profile: $_" | Out-File -Append .\CC-VPN.log
	exit
}

