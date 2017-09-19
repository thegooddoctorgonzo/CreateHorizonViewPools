 


function Set-PoolStorageAcceleratorDisks ([string]$Pool_id, [boolean]$OSDisk, [boolean]$UDDisk ) {  
<#  
    .SYNOPSIS  
        Set the Pool Storage Accelerator Disks for the given VMware View desktop pool  
    .DESCRIPTION  
        This function sets the Pool Storage Accelerator Disks for a Horizon View pool.
        This is controlled in the ADAM DB. The attribute is pae-CBRCCachedDiskTypes. The function will clear any current entries
    .EXAMPLE  
        Set-PoolStorageAcceleratorDisks -Pool_id TESTTEST -OSDisk $true -UDDisk $true   
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER OSDisk 
        Turns on Accelerator for OS disk 
    .PARAMETER UDDisk 
        Turns on Accelerator for the User disk. If this is true, it is also true for the OS disk. True will override the setting for OSDisk
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. To set for both disks, only need to set UDDisk to true

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. His notes follow...
 
#>  
             
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"
    
    foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($poolobj.Properties.'pae-CBRCCachedDiskTypes'.Value)
        {
          $poolObj.Properties.'pae-CBRCCachedDiskTypes'.Clear()
        }

        if($UDDisk)
        {
            $poolObj.'pae-CBRCCachedDiskTypes'.Add('OS')
            $poolObj.'pae-CBRCCachedDiskTypes'.Add('UDD')
            $OSDisk = $False
        }
        if($OSDisk)
        {
            $poolObj.'pae-CBRCCachedDiskTypes'.Add('OS')
        }

        $poolobj.CommitChanges()
    }  
}  
  