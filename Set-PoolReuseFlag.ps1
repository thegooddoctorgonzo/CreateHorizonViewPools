function Set-PoolReuseFlag ([string]$Pool_id, [boolean]$ReuseFlag) {  
<#  
    .SYNOPSIS  
        Enables or disables the "Reuse Computer Account" flag to the given VMware View desktop pool  
    .DESCRIPTION  
        This function enable or disable the "Reuse Computer Account" flag for a Horizon View pool.
        This is controlled in the ADAM DB. The attribute is pae-ServerPoolFlags. The function will read out all the values
        into an array, modify the ReuseComputerAccount value, and add all the values back.
    .EXAMPLE  
        Set-PoolReuseFlag -Pool_id TESTTEST -ReuseFlag $true     
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER HtmlAccess  
        Boolean value to set the Reuse Flag to.  
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. Took much longer than expected because it is not easy to set these multivalued fields
        without erasing the other entries. This is why all values are read out, cleared, the copies are modified, and added back.
        
        Reading values out has to be done in the format **$flags =  $poolobj.Properties.'pae-serverpoolflags'.Value**. Writing
        is in the format **$poolobj.'pae-serverpoolflags'.Add()**. 

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. His notes follow...
          
        "pae-ServerProtocolLevel" is a multivalued attribute, which is a little difficult to   
        write correctly to the object.  
        http://www.selfadsi.org/write.htm   
                Google "powershell ldap multi value property"  
        http://jdhitsolutions.com/blog/2011/12/updating-multi-valued-active-directory-properties-part-1/  
#>  
    
    if(!($ReuseFlag))
    {
        $desiredFlag = "ReuseComputerAccount=false"
    }
    else
    {
        $desiredFlag = "ReuseComputerAccount=true"
    }
         
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"

    $propname = "pae-ServerPoolFlags" 
    
     foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($flags =  $poolobj.Properties.'pae-serverpoolflags'.Value)
        {
            #erase values
            $poolobj.Properties.'pae-serverpoolflags'.Clear()
            #add values back
            Foreach($flag in $flags)
            {   
                #adjust value for flag
                if($flag -like "ReuseComputerAccount*")
                {
                    $flag = $desiredFlag
                }
                #add all the flag values back
                $poolobj.'pae-serverpoolflags'.Add($flag.ToString())
             }
        }
        else
        {
            #if empty of values, add the one value for reuse
            $poolobj.'pae-serverpoolflags'.Add($desiredFlag)
        }        
        $poolobj.CommitChanges()
    } 
}  
  