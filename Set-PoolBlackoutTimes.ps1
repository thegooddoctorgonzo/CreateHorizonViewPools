 


function Set-PoolBlackoutTimes ([string]$Pool_id, [string]$StartTime, [string]$StopTime, [System.Array]$days) {  
<#  
    .SYNOPSIS  
        Sets the Cache Refresh Blackout times for the given VMware View desktop pool  
    .DESCRIPTION  
        This function sets the Cache Refresh Blackout times for a Horizon View pool. Clears any current entries.
        This is controlled in the ADAM DB. The attribute is pae-CBRCCacheRefreshBlackout. Sets the days and times
    .EXAMPLE  
        Set-PoolBlackoutTimes -Pool_id TESTTEST -StartTime "07:00" -StopTime "23:00" -days 1,2,3,4,5   
    .PARAMETER StartTime
        This is the start time of the blackout time. Use format "07:00". Default time is 07:00 AM 
    .PARAMETER StopTime
        This is the stop time of the blackout time. Use format "07:00". Default time is 23:00 PM
    .PARAMETER days
        Days to use blackout time. Input is the number of the day of the week (Mon=1, Sun=7), seperated by commas, in format 1,2,3,4,5   
    .OUTPUT  
        None  
    .NOTES  
        Written by Steve Landry 20170807. 
        
        Reading values out has to be done in the format **$flags =  $poolobj.Properties.'pae-serverpoolflags'.Value**. Writing
        is in the format **$poolobj.'pae-serverpoolflags'.Add()**. 

        Starting point for this was a function called Set-BCPoolHtmlAccess written by Paul Wiegmans on 31-8-2014. 
#>  
    
   
         
    $Searcher = New-Object DirectoryServices.DirectorySearcher
    $Searcher.SearchRoot = 'LDAP://localhost:389/dc=vdi,dc=vmware,dc=int'
    $Searcher.Filter = "(&(objectCategory=pae-ServerPool)(anr=$pool_id))"

    if(!($StartTime.Length -eq 5 -and $StartTime.Contains(":")))
    {
        $StartTime = "07:00"
        $StopTime = "23:00"
    }
    
     foreach ($poolObj in [ADSI]$Searcher.FindAll().GetDirectoryEntry())
     {   
        #if the pool has values in the property
        if($poolobj.Properties.'pae-CBRCCacheRefreshBlackout'.Value)
        {
          $poolObj.Properties.'pae-CBRCCacheRefreshBlackout'.Clear()
        }

        foreach($day in $days)
        {
            $minutes = ([int]$StopTime.Replace(":00","") - [int]$StartTime.Replace(":00","")) * 60
            [string]$value = $day.ToString() + ":" + $StartTime + ";" + $minutes.ToString()
            $poolobj.'pae-CBRCCacheRefreshBlackout'.Add($value)
        }

        $poolobj.CommitChanges()
    } 
}  
  