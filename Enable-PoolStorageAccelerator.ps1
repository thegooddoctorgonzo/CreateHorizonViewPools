 


function Enable-PoolStorageAccelerator ([string]$Pool_id, [boolean]$Flag = $true) {  
<#  
    .SYNOPSIS  
        Enables or disables the View Storage Accelerator for the given VMware View desktop pool  
    .DESCRIPTION  
        This function enable or disable the View Storage Accelerator flag for a Horizon View pool.
        This is controlled in the ADAM DB. The attribute is pae-CBRCEnable. 
    .EXAMPLE  
        Enable-PoolStorageAccelerator -Pool_id TESTTEST -Flag $true     
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER HtmlAccess  
        Boolean value to set the Pool Storage accelerator Flag to.  
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. .
      

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. 
#>  
    
   
         
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"
    
     foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($poolobj.Properties.'pae-CBRCEnable'.Value)
        {
          $poolObj.Properties.'pae-CBRCEnable'.Clear()
        }

        if($Flag -eq $false)
        {
            $Value = "0"
        }
        else
        {
            $Value = "1"
        }

        $poolObj.'pae-CBRCEnable'.Value = $Value

        $poolobj.CommitChanges()
    } 
}  
  