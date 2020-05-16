function Set-MultiVMSnapshot {
    <#
    .Synopsis
    Check for and (optionally) take snapshots for multiple VMs.
    .DESCRIPTION
    The script will check for and (optionally) take snapshots for multiple VMs. 

    The list of VMs is supplied as a .csv file, with a single column heading "vmname". This file is provided as the srcFile parameter.

    Additionally, values are provided for :
    Percentage free on datastore - eg, 10%
    Free space on datastore - eg, 100GB
    Whether or not to include memory in the snapshots.
    A name for the snapshot - this will also be used in conjunction with the date, to create a description, and will be used in the output file name.
    Whether to run the script as a check only - in which case, snapshots will NOT be taken.

    It will check :
    1) If the VM exists by the given name.
    2) If the VM has an existing snapshot.
    3) If the datastore has sufficient space govenered by the the values entered for the percentrage free and free space on the datastore.
    
    If these checks fail, the VM would be marked to be skipped if the script is being run to take the snapshots.

    Especially if looking to take snapshots for a lot of VMs, it's recommended to run the script with RunAsCheckOnly set to Yes in the first instance. This will allow you to review the ouput, and potentially adjust your thresholds. Eg, if it shows that snapshots wouldn't be taken because free space is less than 7%, but free space would be 500GB, then if you are comfortable with this, you may re-adjust the freespace percentage to be lower - eg, 5%.

    If the snapshots are taken, a .csv file will be generated with the snapshot details for the VMs.
    .PARAMETER vCenter
     The IP/FQDN of the VC where the VMs are running
    .PARAMETER srcFile
     The .csv file with the list of the VMs. This should have a column with the label "vmname"
    .PARAMETER TargetFreeSpacePercentage
     The value (as an integer) as the free space percentage on the datastore eg 10%. If the datastore has less free space than this, then a snapshot for a VM would NOT be taken.
    .PARAMETER TargetFreeSpace
     The value (as an integer) as the free space on the datastore eg 100GB. If the datastore has less free space than this, then a snapshot for a VM would NOT be taken.
    .PARAMETER IncludeMemory
     Indicates if memory is to be included for the snapshot. Yes / No are the only acceptable values.
    .PARAMETER RunAsCheckOnly
     Indicates if the script should perform a check only, OR should perform the check AND take the snapshots. Yes / No are the only acceptable values.
    .PARAMETER SnapshotName
     This will be the name given for the snapshot on EVERY VM in the list. It will also form part of the descrption, and the resulting .csv file that will be generated.
    .EXAMPLE
     The following example will take snapshot for all VMs in the given vCenter, for VMs in the sample.csv file. The datastore must have 10% free space AND more than 100GB free. If either condition is not met, the VM would be skipped. The snapshots will include memory, and will have the snapshot name Test. The script WILL take the snapshots
     Set-MultipleVMSnapshot -vCenter 10.10.10.10 -srcFile Sample.csv -TargetFreeSpacePercentate 10 -TargetFreeSpace 100 -IncludeMemory Yes -RunAsCheckOnly No -SnapshotName Test
    .EXAMPLE
     The following example will check for all VMs in the given vCenter, for VMs in the sample.csv file. The datastore must have 20% free space AND more than 100GB free. If either condition is not met, the report will show the VM would be skipped. The script will NOT take the snapshots, simply provide a report.
     Set-MultipleVMSnapshot -vCenter 10.10.10.10 -srcFile Sample.csv -TargetFreeSpacePercentate 20 -TargetFreeSpace 100 -IncludeMemory Yes -RunAsCheckOnly No -SnapshotName Test

    .INPUTS
     A .csv file provided as the srcFile parameter. To include one column named "vmname" and the VM names as they appear in the vCenter. Wildcards should be ok here.
    .OUTPUTS
     If RunAsCheckOnly is set to No, then the snapshots will be taken, and a .csv file will be created.

    .NOTES
    Author          : Dave Lloyd
    Version         : 0.1
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$vCenter,
    
        [Parameter(Mandatory = $True)]
        [string]$srcFile,

        [Parameter(Mandatory = $True)]
        [int]$TargetFreeSpacePercentage,

        [Parameter(Mandatory = $True)]
        [int]$TargetFreeSpace,

        [Parameter(Mandatory = $True)]
        [ValidateSet('Yes', 'No')] # these are the only valid options
        [String]$IncludeMemory,

        [Parameter(Mandatory = $True)]
        [ValidateSet('Yes', 'No')] # these are the only valid options
        [String]$RunAsCheckOnly,

        [Parameter(Mandatory = $True)]
        [string]$SnapshotName
    )

    #################################################
    #
    # Variable declarations
    #
    #################################################
    # Flag - if a check fails, set this to true, and the VM will be skipped from snapshot.
    $SkipThisVM = $False

    # Get the date - this will be used in the snapshot description.
    $CurrentDate = Get-Date 
    $CurrentDate = $CurrentDate.tostring('MM-dd-yyyy')


    Clear-Host

    Write-Host "Attempting to connect to vCenter $vCenter`n" -ForegroundColor Green
    Try {
        Connect-VIServer $vCenter -ErrorAction Stop
    }
    Catch {
        Write-Host "Unable to connect to the vCenter"
        Read-Host "Press ENTER to exit - powershell console will close."
        Exit
    }

    Clear-Host

    $vmsToSnap = Import-Csv $srcFile

    If ($IncludeMemory -eq "Yes") {
        $IncMem = $True
    }
    else {
        $IncMem = $False
    }

    # Whether it should be run as a check only process, or take the actual snapshots where the VM passes the checks.
    If ($RunAsCheckOnly -eq "Yes") {
        $CheckOnly = $True
    }
    else {
        $CheckOnly = $False
    }

    # For each of the VMs
    ForEach ($vm in $vmsToSnap) {
        Write-Host "`n---Starting VM check---" 
        $CurrentVM = Get-VM $VM.vmname -ErrorAction SilentlyContinue

        # Check if the VM exists by that name
        Write-Host "`n- Checking if" $VM.vmname "exists." -ForegroundColor Green
        # If it doesn't, mark it to be skipped - actually not necessary.
        if ($CurrentVM.name -eq $null) {
            Write-Host "`nThe VM doesn't exist by that name." -ForegroundColor Red
            # Use this flag as means to determine if snapshot should be taken or not.
            $SkipThisVM = $true

        }
        else {
            Write-Host "$CurrentVM exists." -ForegroundColor Green

            # Does the VM have an existing snapshot?
            Write-Host "`n- Checking if $CurrentVM has an existing snapshot." -ForegroundColor Green
            $CheckForSnapshot = $CurrentVM | Get-Snapshot | Select-Object Name
            If ($CheckForSnapshot) {
                Write-Host "$CurrentVM has a snapshot with the snapshot name : " $CheckForSnapshot.name -ForegroundColor Red
            }
            else {
                Write-Host "$CurrentVM doesn't have a snapshot." -ForegroundColor Green
            }

            # Ok, just in case the VM has disks on multiple datastores, let's find where the primary disk is and use that only.
            $vmxLocation = $CurrentVM.ExtensionData.Summary.Config.VmPathName.Split(']')[0].TrimStart('[')
    
            # Ok VM exists, so now retrieve the datastore info
            Write-Host "`n- Checking datastore details." -ForegroundColor Green
            $CurrentVMDatastore = $CurrentVM | Get-Datastore $vmxLocation | Select-Object Name, @{n = "FreeSpace"; E = { [math]::round($_.FreeSpaceGB, 2) } }, @{name = "PercentFree"; Expression = { [math]::Round(($_.freespacegb / $_.capacitygb * 100), 2) } }

            Write-Host "$CurrentVM resides on" $CurrentVMDatastore.name "which has" $CurrentVMDatastore.FreeSpace "`bGB or" $CurrentVMDatastore.PercentFree "`b% free." -ForegroundColor Green

            # Check if the datastore has required free space based on supplied values. If not, print message, and mark the VM to be skipped.
            If (($CurrentVMDatastore.FreeSpace -le $TargetFreeSpace) -or ($CurrentVMDatastore.PercentFree -le $TargetFreeSpacePercentage)) {
                Write-Host "Datastore" $CurrentVMDatastore.name "doesn't have enough free space." -ForegroundColor Red
                $SkipThisVM = $true
            }
            else {
                Write-Host "Datastore" $CurrentVMDatastore.name "has enough free space." -ForegroundColor Green
            }
        }

        # IF the check only flag is set
        If ($CheckOnly) {
            if (!($CurrentVM.name -eq $null)) {
                Write-Host "`nRunning as a check only. Snapshots will NOT be taken." -ForegroundColor Green
            }
        }
        else {
            # If all checks have passed (and so $SkipThisVM = $False) take the snapshot, otherwise skip it.
            if ($SkipThisVM) {
                Write-Host "`nSkipping taking snapshot." -ForegroundColor Red
                # Reset the flag
                $SkipThisVM = $False
            }
            else {
                Write-Host "`nPreparing to take snapshot." -ForegroundColor Green
                Write-Host "Taking snapshot of" $CurrentVM -ForegroundColor Green
                If ($IncMem) {
                    New-Snapshot -VM $CurrentVM -Name $SnapshotName -Description "Snapshot for $CurrentVM taken $CurrentDate" -Memory:$true -Quiesce:$False | Out-Null
                }
                else {
                    New-Snapshot -VM $CurrentVM -Name $SnapshotName -Description "Snapshot for $CurrentVM taken $CurrentDate" -Memory:$False -Quiesce:$False | Out-Null                
                }
                Start-Sleep -Seconds 2
            }        
        }
        Write-Host "`n---End VM check---" 

    } # end ForEach ($vm in $vmsToSnap)


    # Only run this if the snapshots are taken, not if it was run in check/preview mode.
    If (!$CheckOnly) {
        Write-Host "`nSnapshot report." -ForegroundColor Green
        $SnapResult = ".\$SnapshotName-snapshots.csv"

        $snaplist = @()

        ForEach ($vm in $VMsToSnap) {
            $CurrentVM = Get-VM $VM.vmname -ErrorAction SilentlyContinue
            if ($CurrentVM.name -ne $null) {

                $vmxLocation = $CurrentVM.ExtensionData.Summary.Config.VmPathName.Split(']')[0].TrimStart('[')        
                $snap = Get-VM $vm.vmname | Get-Snapshot  -ErrorAction SilentlyContinue

                if ($snap) {                    
                    $ds = Get-Datastore $vmxlocation -VM $snap.vm -ErrorAction SilentlyContinue

                    $snapinfo = [PSCustomObject]@{
                        "VM"                                = $vm.vmname
                        "Snapshot Name"                     = $snap.name
                        "Description"                       = $snap.description
                        "Snapshot size (GB)"                = [math]::round($snap.sizeGB)
                        "Datastore"                         = $ds.name
                        "Datastore free space (GB)"         = [math]::round($ds.FreeSpaceGB)
                        "Powerstate - ie, memory included " = $snap.PowerState 
                    }
                    $snaplist += $snapinfo
                }

            }
        }   
        $snaplist    
        Write-Host "Snapshot report exported as $SnapResult`n" -ForegroundColor Green
        $snaplist | Export-CSV -NoTypeInformation -Path $SnapResult
    }

    Write-Host "`nScript complete.`n" -ForegroundColor Green
}
