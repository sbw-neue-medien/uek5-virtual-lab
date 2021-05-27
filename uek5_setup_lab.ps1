$LabLocation = "C:\UEK5"
$ServerImage = "17763.737.amd64fre.rs5_release_svc_refresh.190906-2324_server_serverdatacentereval_en-us_1.vhd"
$ClientImage = "19043.928.210409-1212.21h1_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_de-de.iso"
$RouterImage = "Router.vhdx"


function Write-Menu {
    param (
        [string]$Title = 'UKE5'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "C: Create Lab"
    Write-Host "1: Reset Router"
    Write-Host "2: Reset Server"
    Write-Host "3: Reset Client"
    Write-Host "G: Start Lab"
    Write-Host "v: Start HyperV Mgmt"
    Write-Host "K: Kill Lab"
    Write-Host "R: Remove Lab"
    Write-Host "Q: Press 'Q' to quit."
}

function New-Lab {
	if( !( Test-Path $LabLocation ) ) {
		Write-Host "Ordner Struktur erstellen..."
		New-Item -Path $LabLocation -ItemType Directory > $null
	}

	Write-Host "Netzwerk erstellen..."
	New-LAN
	New-Router
	Write-Host "Netzwerk fertig und gestartet."
    Write-Beep -Count 1

    Write-Host "Server Image erstellen... (kann 10 Minuten daurn)"
	New-Server
	Write-Host "Server fertig und gestartet"
    Write-Beep -Count 1
	
	Write-Host "Client erstellen..."
	New-Client1
	Write-Host "Client fertig, in HyperV console verbinden und von DVD starten."
	Write-Beep -Count 1
}

function Remove-Lab {
	Remove-Router
	Remove-Client1
	Remove-Server
	Remove-LAN
	
	Remove-Item $LabLocation
}


function New-LAN {
    New-VMSwitch -Name uek5LAN -SwitchType Internal
}

function Remove-LAN {
	Remove-VMSwitch -Name uek5LAN
}

function New-Router {
	if( !(Test-Path $LabLocation\Router) ) {
		New-Item -Path $LabLocation\Router -ItemType Directory > $null
	}
	# Create Router VM
    Copy-Item -Destination $LabLocation\Router -Path Images\$RouterImage
    Set-ItemProperty -Path $LabLocation\Router\Router.vhdx -Name IsReadOnly -Value $false
    $vm = New-VM -Name uek5Router -Path $LabLocation\Router -Generation 1 -MemoryStartupBytes 128MB -SwitchName "Default Switch" -BootDevice IDE -VHDPath $LabLocation\Router\Router.vhdx
	Set-VM -VM $vm -CheckpointType ProductionOnly
	Set-VM -VM $vm -AutomaticStartAction Nothing

    # Connect Router to LAN
    Add-VMNetworkAdapter -VM $vm -SwitchName uek5LAN
	Start-VM $vm
}

function Remove-Router {
	$vm = Get-VM -VMName uek5Router
	Stop-VM -VM $vm
	Remove-VM -VM $vm
	Remove-Item $LabLocation\Router -Force -Recurse
}

function New-Client1 {
	if( !( Test-Path $LabLocation\Client ) ) {
		New-Item -Path $LabLocation\Client -ItemType Directory > $null
	}

	# Create Client VM
    $vhd = New-VHD -Path $LabLocation\Client\Disk0.vhdx -Dynamic -SizeBytes 40GB
    $vm = New-VM -Name uek5Client1 -Path $LabLocation\Client -Generation 2 -Memory 2GB -SwitchName uek5LAN -BootDevice CD
 	Set-VM -VM $vm -CheckpointType ProductionOnly
	Set-VM -VM $vm -AutomaticStartAction Nothing

	# Attach HD
	Add-VMDisk -VM $vm -Path  $LabLocation\Client\Disk0.vhdx
    Set-VMDvdDrive -VMName uek5Client1 -Path Images\$ClientImage
	
	# Connect Client to LAN
    Get-VMNetworkAdapter -VM $vm | Connect-VMNetworkAdapter -SwitchName uek5LAN
	
	# Remove Network boot
	$old_boot_order = Get-VMFirmware -VM $vm | Select-Object -ExpandProperty BootOrder
	$new_boot_order = $old_boot_order | Where-Object { $_.BootType -ne "Network" }
	Set-VMFirmware -VM $vm -BootOrder $new_boot_order

	# Start-VM $vm In Console verbinden und manuel starten von DVD
}
function Add-VMDisk {
	param (
		[Microsoft.HyperV.PowerShell.VirtualMachine]$VM,
		[String]$Path,
		[Int]$ControllerNumber=0
	)
	$contrl = Get-VMScsiController -VM $VM -ControllerNumber $ControllerNumber
	Add-VMHardDiskDrive $contrl -Path $Path
}
function Remove-Client1 {
	Stop-VM -VMName uek5Client1
	Remove-VM -VMName uek5Client1
	Remove-Item $LabLocation\Client\* -Recurse -Force
}

function New-Server {
	if( !( Test-Path $LabLocation\Server ) ) {
		New-Item -Path $LabLocation\Server -ItemType Directory > $null
	}

    # Clone main disk
    $vhd = Mount-VHD -Path .\images\$ServerImage -ReadOnly -NoDriveLetter -Passthru
    New-VHD -Dynamic -Path $LabLocation\Server\Disk0.vhdx -SourceDisk $vhd.DiskNumber
    Dismount-VHD .\images\$ServerImage

    #Create server and connect it to our LAN
    $vm = New-VM -Name uek5Server -Path $LabLocation\Server -Generation 1 -MemoryStartupBytes 2GB -VHDPath $LabLocation\Server\Disk0.vhdx
	Set-VM -VM $vm -CheckpointType ProductionOnly
	Set-VM -VM $vm -AutomaticStartAction Nothing

	
	# Connect Server to LAN
    Get-VMNetworkAdapter -VM $vm | Connect-VMNetworkAdapter -SwitchName uek5LAN

    Write-Host "Connect two data disks to be used as mirror"
    New-VHD -Dynamic -Path $LabLocation\Server\Disk1.vhdx -SizeBytes 300GB
    New-VHD -Dynamic -Path $LabLocation\Server\Disk2.vhdx -SizeBytes 300GB
	Add-VMDisk -VM $vm -Path $LabLocation\Server\Disk1.vhdx
	Add-VMDisk -VM $vm -Path $LabLocation\Server\Disk2.vhdx

	Start-VM $vm 
}

function Remove-Server {
	Stop-VM -VMName uek5Server
	Remove-VM -VMName uek5Server
	Remove-Item -Path $LabLocation\Server\* -Recurse -Force
}

function Write-Beep {
    param ( [int]$Count=1 )
    for($i=0; $i -lt $Count; $i++) { [console]::beep(2500,120) }
}

function Start-Lab {
    Start-VM -VMName uek5Router
    Start-VM -VMName uek5Server
    Start-VM -VMName uek5Client1
}

function Stop-Lab {
    Stop-VM -VMName uek5Client1
    Stop-VM -VMName uek5Server
    Stop-VM -VMName uek5Router
}


$continue = $true
do {
    Write-Menu
    Write-Host "Selektiere:"
    $KeyPress = [System.Console]::ReadKey($true)
    $key = $KeyPress.keyChar

    switch( $key ) {
        'c' {
            New-Lab
            Read-Host "Enter"
        }
        '1' {
			Remove-Router
            New-Router   
            Read-Host "Enter"
        }
        '2' {
			Remove-Server
            New-Server
            Read-Host "Enter"
        }
        '3' {
			Remove-Client1
            New-Client1
            Read-Host "Enter"
        }
        'v' { &$Env:Windir\System32\virtmgmt.msc }
        'g' {
            Start-Lab
            Read-Host "Enter"

        }
        'k' {
            Stop-Lab
            Read-Host "Enter"

        }
        'r' {
            Stop-Lab
            Remove-Lab
            Read-Host "Enter"
        }
        'q' { $continue = $false }
    }
} until( !$continue )