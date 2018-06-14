function Enable-PoolHTMLAccess  {  
param(
    [Parameter(Mandatory=$true)]
    [String]$Pool_Id,

    #[Parameter(Mandatory=$false)]
    [switch]$HTMLAccess
    )
<#  
    .SYNOPSIS  
        Enables HTML access for the given VMware View desktop pool  
    .DESCRIPTION  
        This function sets the HTML access key in the ADAM DB for the pool.
        T The attribute is pae-HTMLAccessEnabled.
    .EXAMPLE  
        Enable-PoolHTMLAccess -Pool_Id TESTTEST -HTMLAccess to set HTML access to true for pool    
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER HTMLAccess 
        switch - include in command for TRUE, do not include for FALSE. Does not accept $TRUE or $FALSE)
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20171025. HTMLAccess is a switch - do not need to explicitly declare as true or false. 

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. His notes follow...
  
#>  
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"

    $propname = "pae-HTMLAccessEnabled"
    
    foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
    {   
        if($HTMLAccess)
        {
            $poolobj.$propname = "1"
        }
        else
        {
            $poolobj.$propname = "0"
        }
                
        $poolobj.CommitChanges()
    } 
} 

