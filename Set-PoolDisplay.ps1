function Set-PoolDisplay  {  
param(
    [Parameter(Mandatory=$true)]
    [String]$Pool_Id,

    [Parameter(Mandatory=$true)]
    [ValidateSet(1,2)]
    [int]$numDisplays,

    #[Parameter(Mandatory=$false)]
    [switch]$ThreeD
    )
<#  
    .SYNOPSIS  
        Sets the display size, vram amount, and number of dispalys for the given VMware View desktop pool  
    .DESCRIPTION  
        This function sets the display size, vram amount, and number of dispalys forr a Horizon View pool.
        This is controlled in the ADAM DB. The attribute is pae-VirtualCenterExtraConfig. The function will clear out any current entries
    .EXAMPLE  
        Set-PoolDisplay -Pool_Id TESTTEST -numDisplays 2 -ThreeD    
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable reuse. Wildcards are allowed!  
    .PARAMETER numDisplays 
        Integer for number of displays for the pool. Valid values are 1 or 2.
    .PARAMETER ThreeD 
        Switch for flag to enable/disable 3D for the pool. Only need to include this switch in command for true. 
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. ThreeD is a switch - do not need to explicitly declare as true or false. 
        The number of monitors will determine amount of vRam and width. Screen sized is based on 1280x1920

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. His notes follow...
  
#>  
    
    if($ThreeD)
    {
        $ThreeDFlag = "mks.enable3d=true"
    }
    else
    {
        $ThreeDFlag = "mks.enable3d=false"
    }

    $HeightFlag = "svga.maxHeight=2400"
    $WidthFlag = "svga.maxWidth=" + (1920 * $numDisplays).ToString()
    $vRAMFlag = "svga.vramSize=" + (18000 * $numDisplays).ToString()
    $numDisplayFlag = "svga.numDisplays=" + $numDisplays.ToString()
         
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"

    
     foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($flags =  $poolobj.Properties.'pae-VirtualCenterExtraConfig'.Value)
        {
            #erase values
            $poolobj.Properties.'pae-VirtualCenterExtraConfig'.Clear()
            
         }  
         #add values back
        $poolobj.'pae-VirtualCenterExtraConfig'.Add($HeightFlag)
        $poolobj.'pae-VirtualCenterExtraConfig'.Add($ThreeDFlag)
        $poolobj.'pae-VirtualCenterExtraConfig'.Add($WidthFlag)
        $poolobj.'pae-VirtualCenterExtraConfig'.Add($vRAMFlag)
        $poolobj.'pae-VirtualCenterExtraConfig'.Add($numDisplayFlag)
                
        $poolobj.CommitChanges()
    } 
}  
  