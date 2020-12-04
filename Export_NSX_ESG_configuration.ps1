function export-nsx-dlr {
Write-Host -foregroundcolor "Green" "Script for _Export ESG & DLR configurations_ started..."
 
#If (-Not (Test-Path -LiteralPath ("DLRs-Config-Export-" + $currentDate ))){ $outputFileFolder = New-Item ("C:\Backups\NSX_ESG\backup_"+$date) -itemtype directory}
 
Write-Host "Collecting information for ESGs"
$allESGs = Get-NsxEdge
Write-Host "Found" $allESGs.count "ESGs"
 
Write-Host "Collecting the rest NSX objects"
$allLSs = Get-NsxLogicalSwitch
$VDSwitches = Get-VDSwitch
$VDPorts = $VDSwitches | Get-VDPortgroup
 
If ($allESGs.count -gt 0) {
Foreach ($ESG in $allESGs)
{
$ESGExport = ""
Write-Host "Collecting info for " -NoNewLine
Write-Host -foregroundcolor "Yellow" $ESG.name
$ESGExport += "Name = " + $ESG.name + "`n"
$ESGExport += "Hostname = " + $ESG.fqdn + "`n"
$ESGExport += "Description = " + $ESG.description + "`n"
$ESGExport += "Edge ID = " + $ESG.id + "`n"
$ESGExport += "Type = " + $ESG.type
if ($ESG.type -eq "gatewayServices"){$ESGExport += " (Edge Services Gateway)"}
$ESGExport += "`n"
$ESGExport += "Enable High Availability = " + $ESG.features.highAvailability.enabled + "`n"
$ESGExport += "CLI credentials (User Name) = " + $ESG.cliSettings.userName + "`n"
$ESGExport += "Enable SSH access = " + $ESG.cliSettings.remoteAccess + "`n"
$ESGExport += "Enable FIPS mode = " + $ESG.enableFips + "`n"
$ESGExport += "Enable Auto rule generation = " + $ESG.autoConfiguration.enabled + "`n"
$ESGExport += "Edge Control Level Logging = " + $ESG.vseLogLevel + "`n"
$ESGExport += "Datacenter = " + $ESG.datacenterName + "`n"
$ESGExport += "Appliance Size = " + $ESG.appliances.applianceSize + "`n"
$ESGExport += "`n"
 
$ESGExport += "NSX Edge Appliances: " + "`n"
Foreach($ESGappliance in $ESG.appliances.appliance){
$ESGExport += " Index: " + $ESGappliance.highAvailabilityIndex + "`n"
$ESGExport += " Name: " + $ESGappliance.vmName + "`n"
$ESGExport += " Cluster/Resource Pool: " + $ESGappliance.resourcePoolName + "`n"
$ESGExport += " Datastore: " + $ESGappliance.datastoreName + "`n"
$ESGExport += " Folder: " + $ESGappliance.vmFolderName + "`n"
$ESGExport += " Resource Reservation: "
$ESGExport += " CPU = " + $ESGappliance.cpuReservation.reservation
$ESGExport += ", Memory = " + $ESGappliance.memoryReservation.reservation + "`n"
}
$ESGExport += "Configure interfaces" + "`n"
Foreach($ESGvnic in $ESG.vnics.vnic){
$ESGExport += " Index: " + $ESGvnic.index
If ($ESGvnic.portgroupId){
$ESGExport += "`n Name: " + $ESGvnic.name + "`n"
$ESGExport += " Type: " + $ESGvnic.type + "`n"
$ESGExport += " Connectivity Status: "
If ($ESGvnic.isConnected -eq "true") {$ESGExport += "Connected`n"}
Else {$ESGExport += "Disonnected`n"}
$ESGExport += " Connected to: "
If (($ESGvnic.portgroupId -like "universalwire-*") -or ($ESGvnic.portgroupId -like "virtualwire-*")) { # Find LogicalSwitch name
$LS = $allLSs | Where-Object {$_.objectId -eq $ESGvnic.portgroupId}
$ESGExport += "Logical Switch -> " + $LS.name + "`n"
}
ElseIf ($ESGvnic.portgroupId -like "dvportgroup-*"){ # Find Distributed Virtual Portgroup name
$VDPort = $VDPorts | Where-Object {$_.Key -eq $ESGvnic.portgroupId}
$ESGExport += "DistributedVirtualPortgroup -> " + $VDPort.name + "`n"
}
Else { $ESGExport += "unknown type -> " + $ESGvnic.portgroupId + "`n" }
Foreach ($ESGvnicAddressGroup in $ESGvnic.addressGroups.addressGroup) { # find Primary and Secondary IP addresses for vNIC
$ESGExport += " Primary IP Address: " + $ESGvnicAddressGroup.primaryAddress + "`n"
Foreach ($ESGvnicAddressGroupSecondaryAddress in $ESGvnicAddressGroup.secondaryAddresses.ipAddress) {
$ESGExport += " Secondary IP Address: " + $ESGvnicAddressGroupSecondaryAddress + "`n"
}
$ESGExport += " Subnet Prefix Length: " + $ESGvnicAddressGroup.subnetPrefixLength + "`n"
}
$ESGExport += " MTU: " + $ESGvnic.mtu + "`n"
$ESGExport += " Enable Proxy Arp: " + $ESGvnic.enableProxyArp + "`n"
$ESGExport += " Enable Send Redirects: " + $ESGvnic.enableSendRedirects + "`n"
}
Else { $ESGExport += " (Not configured)`n" } # Nothing configured for this NIC
}
 
$ESGRouting = $ESG | Get-NsxEdgeRouting
If ($ESGRouting.staticRouting.defaultRoute) {
$ESGExport += "Configure default gateway: true`n"
$ESGdefaultRouteNIC = $ESG.vnics.vnic | Where-Object {$_.index -eq $ESGRouting.staticRouting.defaultRoute.vnic}
$ESGExport += " vNIC: " + $ESGdefaultRouteNIC.name + "`n"
$ESGExport += " Gateway IP: " + $ESGRouting.staticRouting.defaultRoute.gatewayAddress + "`n"
$ESGExport += " Admin distance: " + $ESGRouting.staticRouting.defaultRoute.adminDistance + "`n"
}
Else {$ESGExport += "Configure default gateway: false`n"}
 
#Configure Firewall default policy
$ESGDefaultFirewall = $ESG.features.firewall
$ESGExport += "Configure Firewall default policy: " + $ESGDefaultFirewall.enabled + "`n"
If ($ESGDefaultFirewall.enabled -eq "true") {
$ESGExport += " Firewall default action: " + $ESGDefaultFirewall.defaultPolicy.action + "`n"
$ESGExport += " Firewall default logging: " + $ESGDefaultFirewall.defaultPolicy.loggingEnabled + "`n"
}
 
#Configure HA parameters
$ESGDefaultHA = $ESG.features.highAvailability
$ESGExport += "Configure HA: " + $ESGDefaultHA.enabled + "`n"
If ($ESGDefaultHA.enabled -eq "true") {
$ESGExport += " vNIC: " + $ESGDefaultHA.vnic + "`n"
$ESGExport += " Declare Dead Time: " + $ESGDefaultHA.declareDeadTime + "`n"
$ESGExport += " Enable logging: " + $ESGDefaultHA.logging.enable + "`n"
$ESGExport += " Log level: " + $ESGDefaultHA.logging.loglevel + "`n"
}
 
### After deployment tasks
$ESGExport += "`nAfter deployment tasks`n`n"
 
# Configuration
$ESGExport += "Configuration`n"
 
# Syslog configuration
$ESGExport += " Syslog`n"
$ESGExport += " Syslog Enabled: " + $ESG.features.syslog.enabled + "`n"
Foreach ($ESGsyslogServer in $ESG.features.syslog.serverAddresses.ipAddress) {
$ESGExport += " Syslog Server: " + $ESGsyslogServer + "`n"
}
$ESGExport += " Protocol: " + $ESG.features.syslog.protocol + "`n"
 
# DNS Configuration
$ESGExport += " DNS Configuration`n"
$ESGDNS = $ESG | Get-NsxDns
$ESGExport += " Enable DNS service: " + $ESGDNS.enabled + "`n"
$ESGExport += " Interface: " + $ESGDNS.listeners.vnic + "`n"
Foreach ($ESGDNSServer in $ESGDNS.dnsViews.dnsView.forwarders.ipAddress) {
$ESGExport += " DNS Server: " + $ESGDNSServer + "`n"
}
$ESGExport += " Cache Size: " + $ESGDNS.cacheSize + "`n"
$ESGExport += " Enable Logging: " + $ESGDNS.logging.enable + "`n"
$ESGExport += " Log level: " + $ESGDNS.logging.logLevel + "`n"
 
# Global Configuration
$ESGExport += "Global Configuration`n"
$ESGExport += " ECMP: " + $ESGRouting.routingGlobalConfig.ecmp + "`n"
# Default Gateway
If ($ESGRouting.staticRouting.defaultRoute) {
$ESGExport += " Default Gateway`n"
$ESGdgwvNic = $ESG.vnics.vnic | Where-Object {$_.index -eq $ESGRouting.staticRouting.defaultRoute.vnic}
$ESGExport += " vNIC: " + $ESGRouting.staticRouting.defaultRoute.vnic + " (" + $ESGdgwvNic.name + ")" + "`n"
$ESGExport += " Gateway IP: " + $ESGRouting.staticRouting.defaultRoute.gatewayAddress + "`n"
$ESGExport += " Admin distance: " + $ESGRouting.staticRouting.defaultRoute.adminDistance + "`n"
$ESGExport += " Description: " + $ESGRouting.staticRouting.defaultRoute.description + "`n"
}
Else {$ESGExport += " Default Gateway: none`n"}
 
$ESGExport += " Dynamic Routing Configuration`n"
# Dynamic Routing Configuration
$ESGExport += " Router ID: " + $ESGRouting.routingGlobalConfig.routerId + "`n"
 
# Static Routes
$ESGRoutingStaticRoutes = $ESGRouting.staticRouting.staticRoutes.route | Where {$_.type -eq "user"}
If ($ESGRoutingStaticRoutes) {
$ESGExport += " Static Routes`n"
Foreach ($ESGRoutingStaticRoute in $ESGRoutingStaticRoutes) {
$ESGExport += " Network: " + $ESGRoutingStaticRoute.network
$ESGExport += ", Next Hop: " + $ESGRoutingStaticRoute.nextHop
If ($ESGRoutingStaticRoute.vnic) {
$ESGstaticRoutevNicName = ($ESG.vnics.vnic | Where-Object {$_.index -eq $ESGRoutingStaticRoute.vnic}).name
}
Else {$ESGstaticRoutevNicName = "none"}
$ESGExport += ", Interface: " + $ESGstaticRoutevNicName
$ESGExport += ", Admin Distance: " + $ESGRoutingStaticRoute.adminDistance
$ESGExport += ", Description: " + $ESGRoutingStaticRoute.description
$ESGExport += "`n"
}
}
Else {$ESGExport += " Static Routes: none`n"}
 
# BGP
# Get info for BGP if Enabled
If ($ESGRouting.bgp.enabled -eq "true") {
$ESGExport += " BGP Configuration`n"
$ESGExport += " Enable BGP: " + $ESGRouting.bgp.enabled + "`n"
$ESGExport += " Enable Graceful Restart: " + $ESGRouting.bgp.gracefulRestart + "`n"
$ESGExport += " Enable Default Originate: " + $ESGRouting.bgp.defaultOriginate + "`n"
$ESGExport += " Local AS: " + $ESGRouting.bgp.localASNumber + "`n"
$ESGExport += " BGP Neighbours" + "`n"
Foreach ($ESGRoutingBgpNeighbour in $ESGRouting.bgp.bgpNeighbours.bgpNeighbour) {
$ESGExport += " IP Address: " + $ESGRoutingBgpNeighbour.ipAddress + "`n"
$ESGExport += " Remote AS: " + $ESGRoutingBgpNeighbour.remoteASNumber + "`n"
$ESGExport += " Remove Private AS: " + $ESGRoutingBgpNeighbour.removePrivateAS + "`n"
$ESGExport += " Weight: " + $ESGRoutingBgpNeighbour.weight + "`n"
$ESGExport += " Keep Alive Time: " + $ESGRoutingBgpNeighbour.keepAliveTimer + "`n"
$ESGExport += " Hold Down Time: " + $ESGRoutingBgpNeighbour.holdDownTimer + "`n"
If ($ESGRoutingBgpNeighbour.password) {
$ESGExport += " Password exists: true`n" }
Else {$ESGExport += " Password exists: false`n"}
# collect BGP Filters
If ($ESGRoutingBgpNeighbour.bgpFilters.bgpFilter) {
$ESGExport += " BGP Filters`n"
Foreach ($ESGRoutingBgpNeighbourbgpFilter in $ESGRoutingBgpNeighbour.bgpFilters.bgpFilter) {
$ESGExport += " Direction: " + $ESGRoutingBgpNeighbourbgpFilter.direction + "`n"
$ESGExport += " Action: " + $ESGRoutingBgpNeighbourbgpFilter.action + "`n"
$ESGExport += " Network: " + $ESGRoutingBgpNeighbourbgpFilter.network + "`n"
$ESGExport += " IP Prefix GE: " + $ESGRoutingBgpNeighbourbgpFilter.ipPrefixGe + "`n"
$ESGExport += " IP Prefix LE: " + $ESGRoutingBgpNeighbourbgpFilter.ipPrefixLe + "`n"
}
}
Else {$ESGExport += " BGP Filters: none`n"}
}
}
Else {$ESGExport += " BGP Configuration: none`n"}
# collect Route Redistribution
$ESGExport += " Route Redistribution OSPF: " + $ESGRouting.ospf.redistribution.enabled + "`n"
If ($ESGRouting.bgp.redistribution.enabled) {$ESGExport += " Route Redistribution BGP: " + $ESGRouting.bgp.redistribution.enabled + "`n"}
Else {$ESGExport += " Route Redistribution BGP: none`n"}
# collect IP Prefixes
If ($ESGRouting.routingGlobalConfig.ipPrefixes.ipPrefix) {
$ESGExport += " IP Prefixes`n"
Foreach ($ESGroutingGlobalConfigIpPrefix in $ESGRouting.routingGlobalConfig.ipPrefixes.ipPrefix) {
$ESGExport += " Name: " + $ESGroutingGlobalConfigIpPrefix.name + "`n"
$ESGExport += " IP/Network: " + $ESGroutingGlobalConfigIpPrefix.ipAddress + "`n"
$ESGExport += " IP Prefix GE: " + $ESGroutingGlobalConfigIpPrefix.ge + "`n"
$ESGExport += " IP Prefix LE: " + $ESGroutingGlobalConfigIpPrefix.le + "`n"
}
}
# Route Redistribution Table
If ($ESGRouting.bgp.redistribution.rules.rule) {
$ESGExport += " Route Redistribution Table" + "`n"
Foreach ($ESGRoutingBgpRedistributionRule in $ESGRouting.bgp.redistribution.rules.rule) {
$ESGExport += " ID: " + $ESGRoutingBgpRedistributionRule.id + ","
$ESGExport += " Learner: BGP,"
$ESGExport += " From: "
If ($ESGRoutingBgpRedistributionRule.from.ospf -eq "true") {$ESGExport += "OSPF,"}
If ($ESGRoutingBgpRedistributionRule.from.bgp -eq "true") {$ESGExport += "BGP,"}
If ($ESGRoutingBgpRedistributionRule.from.static -eq "true") {$ESGExport += "Static Routes,"}
If ($ESGRoutingBgpRedistributionRule.from.connected -eq "true") {$ESGExport += "Connected,"}
If ($ESGRoutingBgpRedistributionRule.prefixName) {$ESGExport += " Prefix: " + $ESGRoutingBgpRedistributionRule.prefixName + ","}
Else {$ESGExport += " Prefix: Any,"}
$ESGExport += " Action: " + $ESGRoutingBgpRedistributionRule.action
$ESGExport += "`n"
}
}
 
$ESGExport += "`n"
 
$outputFileName = "Config-for-ESG_" + $ESG.name + ".txt"
$ESGExport | Out-File -filePath ("C:\Backups\NSX_ESG\backup_"+$date+ "\" + $FolderName + "\" + $outputFileFolder.Name + "\" + $outputFileName)
}
}
 
#Disconnect-NsxServer -vCenterServer $vCenterServerName
#Disconnect-VIServer -Server $vCenterServerName -Confirm:$False
 
Write-Host -foregroundcolor "Green" "`nScript completed!"
}
 
$date = $((Get-Date).ToString('yyyy-MM-dd'))
 
#If (-Not (Test-Path -LiteralPath ("DLRs-Config-Export-" + $currentDate ))){ $outputFileFolder = New-Item ("C:\Backups\NSX_ESG\backup_"+$date+"\AMS") -itemtype directory}
#If (-Not (Test-Path -LiteralPath ("DLRs-Config-Export-" + $currentDate ))){ $outputFileFolder = New-Item ("C:\Backups\NSX_ESG\backup_"+$date+"\BRU") -itemtype directory}
 
#Connect to the first vCenter
$VIServer1 = "vcenter_FQDN"
$VIUser1 = "administrator@vsphere.local"
$VIPass1 = "********"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Disconnect-VIServer -Server * -Force -Confirm:$false
Disconnect-NsxServer -vCenterServer *
Connect-NsxServer -vCenterServer $VIServer1 -user $VIUser1 -pass $VIPass1
If (-Not (Test-Path -LiteralPath ("DLRs-Config-Export-" + $currentDate ))){ $outputFileFolder = New-Item ("C:\Backups\NSX_ESG\backup_"+$date+"\AMS") -itemtype directory}
#call function
export-nsx-dlr
 
#Connect to the second vCenter
$VIServer2 = "vcenter_FQDN"
$VIUser2 = "administrator@vsphere.local"
$VIPass2 = "**********"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Disconnect-VIServer -Server * -Force -Confirm:$false
Disconnect-NsxServer -vCenterServer *
Connect-NsxServer -vCenterServer $VIServer2 -user $VIUser2 -pass $VIPass2
If (-Not (Test-Path -LiteralPath ("DLRs-Config-Export-" + $currentDate ))){ $outputFileFolder = New-Item ("C:\Backups\NSX_ESG\backup_"+$date+"\BRU") -itemtype directory}
#call function
export-nsx-dlr
