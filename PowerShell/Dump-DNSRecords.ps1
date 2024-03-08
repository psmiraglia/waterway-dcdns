param (
    [Parameter(Mandatory=$false)]
    [string]$ServerName,
    [Parameter(Mandatory=$false)]
    [string]$CMDBuildServer
)

#
# Global variables
#

$Zones = @()
$Records = @()
$Registrar = "DC"

#
# Dump the DNS records and save to CSV files
#

$_Zones = $null
if ($ServerName) {
    $_Zones = $(Get-DnsServerZone -ComputerName $ServerName | Select -Property ZoneName)
} else {
    $_Zones = $(Get-DnsServerZone | Select -Property ZoneName)
}

foreach ($z in $_Zones) {
    # ZoneName
    $ZoneName = $z.ZoneName

    # ZoneCode
    $Stream = [IO.MemoryStream]::new([byte[]][char[]]$ZoneName)
    $Hash = Get-FileHash -InputStream $Stream -Algorithm SHA1
    $ZoneCode = "dc_$($Hash.Hash.ToLower())"

    # Description
    $ZoneDescription = "$($Registrar) Zone [$($ZoneName)]"

    # Save to zones.csv...
    Write-Host "$($ZoneCode) | $($ZoneDescription) | $($ZoneName) | $($Registrar)"
    $Zones += [PSCustomObject]@{
        Code = $ZoneCode
        Description = $ZoneDescription
        Name = $ZoneName
        Registrar = $Registrar
    }

    $_Records = $null
    if ($ServerName) {
        $_Records = $(Get-DnsServerResourceRecord -ZoneName $ZoneName -ComputerName $ServerName | Select -Property HostName,RecordType,RecordData)
    } else {
        $_Records = $(Get-DnsServerResourceRecord -ZoneName $ZoneName | Select -Property HostName,RecordType,RecordData)
    }
    foreach ($r in  $_Records) {
        # Hostname
        $HostName = $r.HostName
        
        # RecordType
        $RecordType = $r.RecordType
        
        # RecordData
        $RecordData = $null
        if (Get-Member -InputObject $r.RecordData -MemberType Properties -Name IPv4Address) {
            $RecordData = $r.RecorDdata.IPv4Address.ToString()
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name IPv6Address) {
            $RecordData = $r.RecordData.IPv6Address.ToString()
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name HostNameAlias) {
            $RecordData = $r.RecordData.HostNameAlias.ToString()
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name PrimaryServer) {
            $RecordData = $r.RecordData.PrimaryServer
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name MailExchange) {
            $RecordData = $r.RecordData.MailExchange
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name DescriptiveText) {
            $RecordData = $r.RecordData.DescriptiveText
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name DomainName) {
            $RecordData = $r.RecordData.DomainName
        } elseif (Get-Member -InputObject $r.RecordData -MemberType Properties -Name PtrDomainName) {
            $RecordData = $r.RecordData.PtrDomainName
        } else {
            $RecordData = $r.RecordData.NameServer
        }

        # Code
        $Stream = [IO.MemoryStream]::new([byte[]][char[]]"$($ZoneName)$($HostName)$($RecordType)$($RecordData)")
        $Hash = Get-FileHash -InputStream $Stream -Algorithm SHA1
        $RecordCode = "dc_$($Hash.Hash.ToLower())"

        # Description
        $RecordDescription = "$($Registrar) Record [$($HostName)]"

        # Save to records.csv...
        Write-Host "$($RecordCode) | $($RecordDescription) | $($HostName) | $($RecordType) | $($RecordData)| $($Registrar) | $($ZoneCode)"
        $Records += [PSCustomObject]@{
            Code = $RecordCode
            Description = $RecordDescription
            Registrar = $Registrar
            Zone = $ZoneCode
            Name = $HostName
            Type = $RecordType
            Content = $RecordData
        }
    }
}

$now = $(Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$ZonesFile = "zones.$($now).csv"
$RecordsFile = "records.$($now).csv"

$Zones | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $ZonesFile
$Records | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $RecordsFile

#
# Upload CSV files to CMDBuild server
#


#
# Invoke the gate to load data from CSV files
#