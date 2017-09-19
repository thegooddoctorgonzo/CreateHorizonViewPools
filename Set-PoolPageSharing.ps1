 


function Set-PoolPageSharing  {  
param(
    [Parameter(Mandatory=$true)]
    [String[]]$Pool_Id,

    [Parameter(Mandatory=$true)]
    [ValidateSet("VM","POOL","POD","GLOBAL")]
    [String[]]$Flag
    )
<#  
    .SYNOPSIS  
        Sets the value of the Transparent Page Sharing Scope for the given VMware View desktop pool  
    .DESCRIPTION  
        This function sets the value of the Transparent Page Sharing Scope for a Horizon View pool.
        Clears any current values in the attribute.
        This is controlled in the ADAM DB. The attribute is pae-TransparentPageSharingScope. 
    .EXAMPLE  
        Set-PoolPageSharing -Pool_Id TESTTEST -Flag POOL    
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER Flag  
        String parameter for scope of page sharing. Values "VM","POOL","POD","GLOBAL"
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. 
        
        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. His notes follow...
        
#>  
    
   
         
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"

   
     foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($poolobj.Properties.'pae-TransparentPageSharingScope'.Value)
        {
          $poolObj.Properties.'pae-TransparentPageSharingScope'.Clear()
        }

        $poolObj.'pae-TransparentPageSharingScope'.Value = $Flag

        $poolobj.CommitChanges()
    } 
}  
  