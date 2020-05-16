README
------
This script is intended to be able to check and take snapshots against multiple VMs in the same environment.

It uses a .csv file as input which is provided as the srcFile parameter. This file should have 1 column called "vmname", and in this should be the names of the VM that the snapshots are required for, *as they appear in vSphere*

Additionally, parameters are used to define :
* Percentage free on datastore - eg, 10%
* Free space on datastore - eg, 100GB
* Whether or not to include memory in the snapshots.
* A name for the snapshot - this will also be used in conjunction with the date, to create a description, and will be used in the output file name.
Whether to run the script as a check only - in which case, snapshots will NOT be taken.

It will then check :
1) If the VM exists by the given name.
2) If the VM has an existing snapshot.
3) If the datastore has sufficient space govenered by the the values entered for the percentrage free AND free space on the datastore.
    
If these checks fail, the VM would be marked to be skipped if the script is being run to take the snapshots.

Especially if looking to take snapshots for a lot of VMs, it's recommended to run the script with RunAsCheckOnly set to Yes in the first instance. This will allow you to review the ouput, and potentially adjust your thresholds. Eg, if it shows that snapshots wouldn't be taken because free space is less than 7%, but free space would be 500GB, then if you are comfortable with this, you may re-adjust the freespace percentage to be lower - eg, 5%.

If the snapshots are taken, a .csv file will be generated with the snapshot details for the VMs.

# Known limitations
Currently, it offers NO queisce option.
If you do take snapshots with memory, the storage check isn't taking this into account, so use with caution.

