
function Test-PingStatus {
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,mandatory=$false,ValueFromPipeline=$true)]
        [string]$ComputerName,
        [switch]$TimeToLive, [switch]$ResponseTimeToLive, [switch]$StatusCode, [switch]$ReplyInconsistency,
        [switch]$BufferSize, [switch]$ReplySize, [switch]$ProtocolAddress, [switch]$ResolveAddressNames,
        [switch]$PrimaryAddressResolutionStatus, [switch]$IPV4Address,
        [int]$Timeout = 1000
    )#param
        $Filter = 'Address="{0}" and Timeout={1}' -f $ComputerName, $Timeout
        $pingStatus = Get-WmiObject -Class Win32_PingStatus -Filter $Filter
        if($pingStatus.PrimaryAddressResolutionStatus -ne 0){
            switch ($pingStatus.PrimaryAddressResolutionStatus){
                11001 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Buffer Too Small (11001)'}}
                11002 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Destination Net Unreachable (11002)'}}
                11003 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Destination Host Unreachable (11003)'}}
                11004 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Destination Protocol Unreachable (11004)'}}
                11005 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Destination Port Unreachable (11005)'}}
                11006 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'No Resources (11006)'}}
                11007 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Bad Option (11007)'}}
                11008 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Hardware Error (11008)'}}
                11009 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Packet Too Big (11009'}}
                11010 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Request Timed Out (11010)'}}
                11011 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Bad Request (11011)'}}
                11012 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Bad Route (11012)'}}
                11013 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'TimeToLive Expired Transit (11013)'}}
                11014 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'TimeToLive Expired Reassembly (11014)'}}
                11015 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Parameter Problem (11015)'}}
                11016 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Source Quench (11016)'}}
                11017 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Option Too Big (11017)'}}
                11018 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Bad Destination (11018)'}}
                11032 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'Negotiating IPSEC (11032)'}}
                11050 {[pscustomobject]@{'PrimaryAddressResolutionStatus' = 'General Failure (11050)'}}
            }#switch

        }else{
            $customObj = [pscustomobject]@{
                        Address = $pingStatus.Address
                        Timeout = $pingStatus.TimeOut
                        ResponseTime = $pingStatus.ResponseTime
            }#custobj

            switch -Exact ($PSBoundParameters.GetEnumerator().Where({$_.Value -eq $true}).Key){
                
                'TimeToLive' {$customObj | Add-Member 'TimeToLive' $pingStatus.TimeToLive}
                'ResponseTimeToLive' {$customObj | Add-Member 'ResponseTimeToLive' $pingStatus.ResponseTimeToLive}
                'StatusCode' {$customObj | Add-Member 'StatusCode' $pingStatus.StatusCode}
                'ReplyInconsistency' {$customObj | Add-Member 'ReplyInconsistency' $pingStatus.ReplyInconsistency}
                'BufferSize' {$customObj | Add-Member 'BufferSize' $pingStatus.BufferSize}
                'ReplySize' {$customObj | Add-Member 'ReplySize' $pingStatus.ReplySize}
                'ProtocolAddress' {$customObj | Add-Member 'ProtocolAddress' $pingStatus.ProtocolAddress}
                'ResolveAddressNames' {$customObj | Add-Member 'ResolveAddressNames' $pingStatus.ResolveAddressNames}
                'PrimaryAddressResolutionStatus' {$customObj | Add-Member 'PrimaryAddressResolutionStatus' $pingStatus.PrimaryAddressResolutionStatus}
                'IPV4Address' {$customObj | Add-Member 'IPV4Address' $pingStatus.IPV4Address}

            }#switch
                
            $customObj

        }#else
}
    Test-PingStatus -ComputerName $ComputerName -Timeout 2000
    $ComputerName = 'powershellmagazine.com'
    Test-PingStatus -ComputerName $ComputerName -TimeToLive -ResponseTimeToLive -StatusCode `
    -ReplyInconsistency -BufferSize -ReplySize -ProtocolAddress -ResolveAddressNames `
    -PrimaryAddressResolutionStatus -IPV4Address -Timeout 3000
