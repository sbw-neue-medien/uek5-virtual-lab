# uek5-virtual-lab
A small Hyper-V based lab to 
* configure an internet router
* configure a Windows Server based AD DC and DHCP Server
* one or more clients

## LAN
A private LAN switch is used to prevent network troubles with the host. The WAN is connected to the Default Switch wich will forward to the uplink. 
## Router
As router a Mikrotik CHR (Cloud Hoster Router) can be used: https://mikrotik.com/download#chr
The VM is connect to the two switches and normally should find out on which to configure WAN (the only one with a DHCP).

## Server
The Windows Server images (vhd) can be downloaded from https://www.microsoft.com/en-us/evalcenter/ Make sure to get the preinstalled VHD image; installation. Ths script will build vhdx with the VHD as source
Two additional vh disks are added to simulation a RAID setup

## Client
The client is a windows 10 workstation installed from ISO als from the https://www.microsoft.com/en-us/evalcenter/. On first boot make sure to tap a key to get the VM starting from DVD.

# Configure
## Client
Setup at least one client. This has at this stage no working connection to the internet so use a local account. Copy Winbox from the host to the client's desktop for the next step.

## Router
As the router has no IP-address ootb use something like winbox to connect to the router on network(3) layer, as opposed to transport(4) layer. After this the router should get an 
* IP address and
* Setup as proxy gateway (NAT).
* Setup device name, and admin password.
* Setup DNS to accept remote requests and
* Setup firewall rules to allow forwarding to tcp protocoll (6) and DNS port(53) to whatever IP-address the router has on LAN

## Server
Minimally:
* Set a name and fix IP-Adress, using the router as both gateway and DNS
* Add roles AD-DC and DHCP and DNS. 
* DHCP needs configuration for the DHCP - Scope

## Client(s)
After the the client or clients can be setup with DHCP enabled as is the standard. 
