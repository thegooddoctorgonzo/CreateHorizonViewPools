#################################################################################################
#This script check enrollment and build or adjust VM pools for classes that are marked as Virtual (Computer Assisted Component in Xenegrade) classes
#Any enrollment in a virtual class and a pool will be built. 
#Additional enrollments and the script will adjust the pool to the proper number



Start-Transcript -Path "C:\Scripts\CreateNewPoolsFromXenDB\CreateNewPoolsFromXenDB.log" -Append -Force

$Header = (Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- INFO -- Script: " + $MyInvocation.MyCommand.Source
$NotificationLog = new-object system.collections.arraylist
. \Write-ToMasterLog.ps1
. \Collect-Errors.ps1
. \Get-CurrentLine.ps1


try{
Add-PSSnapin Vmware.view.broker
Import-Module "C:\Scripts\FunctionsModules\Set-BCPoolHTMLAccess.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Set-PoolBlackoutTimes.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Set-PoolStorageAcceleratorDisks.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Enable-PoolStorageAccelerator.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Set-PoolPageSharing.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Set-PoolReuseFlag.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Set-PoolDisplay.ps1" -Verbose -ErrorAction Stop
Import-Module "C:\Scripts\FunctionsModules\Enable-PoolHTMLAccess.ps1" -Verbose -ErrorAction Stop
Import-Module ActiveDirectory
#Import-Module NTFSSecurity
}
catch{
#$NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- FATAL -- Failed to load modules")
#$NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- FATAL -- " + $_.CategoryInfo)
Collect-Errors -LogLines $_ -Label "Failed to load modules" -Level FATAL -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
Write-ToMasterLog -Entries $NotificationLog -Header $Header
exit
}

#test for vcenter connection
if($global:defaultviserver)
{
    Disconnect-VIServer -Confirm:$false -ErrorAction Ignore
}

try{
Connect-VIServer -Server VCENTER -ErrorAction stop
}
catch [VMware.VimAutomation.Sdk.Types.V1.ErrorHandling.VimException.ViServerConnectionException]{
Collect-Errors -LogLines $_ -Label "Failed connect to vServer" -Level FATAL -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
Write-ToMasterLog -Entries $NotificationLog -Header $Header
exit
}
catch{
continue
}



####################use this to find number of VMs running on a host##########################
$vms = Get-VM -Name 'VM*' | Sort-Object -Property name

#########Holder to count number of VMs on each host
$lab3 = 0
$lab2 = 0

foreach ($vm in $vms)
{
    if($vm.Powerstate -eq "PoweredOn" -or $vm.PowerState -eq "Suspended")
    {
        switch($vm.VMHost){
        'host2'{$lab3++}
        'host3'{$lab2++}
        }
    }
}
##############Assign target host for new pool############
$targetHost = Get-VMHost -Name host3   #lab3 is default host unless it has more VMs than lab2
if($lab3 -gt $lab2)
{
    $targetHost = Get-VMHost -Name host2   
}

if($targetHost.ConnectionState -ne 'Connected')
{
    $NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- FATAL --Target host is in maintenance mode - EXITING")
    exit
}

$OU = "OU=Users" # does not change

#Collects users that are in DL IT classes that use VMs, and CR students that use VMs that are between a week before assigned start date and 2 days past end date
$DBServer="DBSERV"
$DB="DB"
$Query_SQL="SELECT  CourseID + SectionID as ID,
                    CourseID,
                    SectionID,
                    CourseTitle,
                    StartDate,
                    EndDate,
                    TotalEnroll,
                    BranchID,
                    Instructor
                    FROM vPDClassroomEnrollment 
                    WHERE (CAST(CURRENT_TIMESTAMP AS DATE) BETWEEN DATEADD(d,-7,CAST(StartDate AS DATE)) AND DATEADD(d,1,CAST(EndDate AS DATE)) AND  Virtual = 1) "   

                                      
                    

$conn_SQL=New-Object system.data.sqlclient.sqlconnection("Server=$DBServer;Database=$DB;Integrated Security=True") 
$da_SQL=New-Object system.data.sqlclient.sqldataadapter($Query_SQL,$conn_SQL)
$da_SQL.SelectCommand.CommandTimeout = 300
$dt_SQL=New-Object system.data.datatable

#try the SQL connection if error then exit the script
try
{
    $conn_SQL.Open()
    [void]$da_SQL.fill($dt_SQL)
    $conn_SQL.Close() 
}
catch
{
    $conn_SQL.Close() 
    Collect-Errors -LogLines $_ -Label "SQL Connection or Fill Failed - Closing Connection - Exiting" -Level FATAL -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
    Write-ToMasterLog -Entries $NotificationLog -Header $Header
    exit
}

#add a test class manually
<#
$newRow=$dt_SQL.NewRow()
$newRow.ID="MP2013_1C2118019"
$newRow.CourseID="MP2013_1"
$newRow.SectionID="C2118019"
$newRow.CourseTitle="MICROSOFT POWERPOINT 2013 Essentials"
$newRow.StartDate="9/13/2017"
$newRow.EndDate="9/13/2017"
$newRow.TotalEnroll="3"
$newRow.BranchID="1"
$newRow.Instructor="Susan Steinhauser"
$dt_SQL.Rows.Add($newRow)

$newRow=$dt_SQL.NewRow()
$newRow.ID="ZZTESTZZZ1234"
$newRow.CourseID="ZZTEST"
$newRow.SectionID="ZZZ1234"
$newRow.CourseTitle="MICROSOFT ACCESS TEST CLASS"
$newRow.StartDate="8/9/17"
$newRow.EndDate="8/17/17"
$newRow.TotalEnroll="3"
$newRow.BranchID="1"
$newRow.Instructor="Brian Schmid"
$dt_SQL.Rows.Add($newRow) #>


$dt_SQL.primarykey=$dt_SQL.columns[0]
#assign table of current classes to array
$Classes=$dt_SQL.Rows 

$conn_SQL.Close()

#get current pools for classes
$pools = Get-Pool -PoolType SviPersistent | Where-Object {$_.pool_id -notlike "*dl"}
Collect-Errors -LogLines $Error -Label "Error getting list of pools" -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
foreach($class in $classes)
{
    #will stay true unless class exists
    $createClassPool = $true
    $output = "`nChecking -- " + $class.CourseTitle
    Write-Output $output
    #if class has enough enrollment to create pool
    if($class.TotalEnroll -gt 1)
    {
        $output = "Students Enrolled -- " + $class.TotalEnroll
        Write-Output $output 
        #search for existing pools for classes with enrollment
        foreach($pool in $pools)
        {
            $output = "Comparing with pool -- " + $pool.displayName
            Write-Output $output
            #compare the courseID to the poolID and the title to display name
            #check on both parameters because courseIDs and titles change for Intermediate and Advanced classes for program groups
            $ErrorActionPreference = "SilentlyContinue"
            if($pool.pool_id -like ($class.CourseID.Substring(0, 2) + "*") -or $class.CourseTitle -like ("*" + $pool.displayName + "*") -or ($class.CourseTitle -like "*Oracle*" -and $pool.displayName -like "*Oracle*") -or ($class.CourseTitle.Substring(($class.CourseTitle.IndexOf("Microsoft ")), 14) -eq $pool.displayName.Substring(($pool.displayName.IndexOf("Microsoft ")), 14)))
            {
                $ErrorActionPreference = "Continue"
                $output = "Match on -- " + $pool.pool_id
                Write-Output $output
                #set to false to prevent additional pool from being created
                $createClassPool = $false
                #set new max VM count for existing class if enrollment is over VM count
                #parent VM snap path must also be updated in case previous SS has been deleted
                if(($class.TotalEnroll + 1) -gt $pool.maximumCount)
                {
                    $poolParentVM = ((Get-Pool -Pool_id $pool.pool_id).parentVMPAth).split("/")
                    $snapObj = Get-Snapshot -VM $poolParentVM[$poolParentVM.Count - 1] | Sort-Object name
                    $output = "Snapshot assigned -- " + $poolParentVM[$poolParentVM.Count - 1].name
                    Write-Output $output
                
                    #builds path to SS
                    $parentSnapPath  = ""
                    foreach($snap in $snapObj)
                    {
                        #build root path
                        #Write-Host "Snap   " $snap.ParentSnapshot.Name
                        #Write-Host "ParentsnapPath   " $parentSnapPath
                        $parentSnapPath  = $parentSnapPath +$snap.ParentSnapshot.Name + "/"
                        if($snap -eq $snapObj[$snapObj.Count - 1])
                        {
                            #add on name of SS to path
                            $parentSnapPath  = $parentSnapPath + $snap.Name
                            $output = "ParentsnapPath -- " + $parentSnapPath
                            Write-Output $output
                        }
                    }
                    $output = "Updating pool -- " + $pool.displayName + " to " + ($class.TotalEnroll + 1) + " VMs"
                    Write-Output $output
                    Update-AutomaticLinkedClonePool -Pool_id $pool.pool_id -MaximumCount ($class.TotalEnroll + 1) -MinimumCount ($class.TotalEnroll + 1) -ParentSnapshotPath $parentSnapPath -Verbose
                    $bodyText += $pool.displayName + " adjusted to " + ($class.TotalEnroll + 1) + "`n"
                }
                break
            }
            else
            {
                $output = "NON MATCH WITH -- " + $pool.pool_id
                Write-Output $output
            }
            $ErrorActionPreference = "Continue"

         }
            
            #the above loop will kick the class object to here for every non match. 
            #Condition here will stop the creation of the pool again if it has already been created in a previous iteration of the following loop or in a previous script run
            if(!(Get-Pool -DisplayName $class.CourseTitle -ErrorAction Ignore) -and $createClassPool)
            {
                #no existing pool found - create new pool
                $output = "Starting pool creation for -- " + $class.CourseID 
                Write-Output $output
                #starting point to pick correct VDG OS ver - Win10 for Office 2016, Win8.1 for Office 2013
                if($class.CourseTitle -like "*2016*")
                {
                    $poolOS = "W100"
                }
                else
                {
                    $poolOS = "W63"
                    
                }

                if($class.BranchID -eq 2)
                {
                    $VDGName = "VDGW100O16" 
                    $postSyncScript = "C:\scripts\office_prep.bat"
                    $ClassType= "OLLI"
                }
                else
                {
                    Switch -wildcard ($class.CourseTitle.ToUpper())
                    {
                        "MICROSOFT ACCESS*" {$VDGName = "VDG" + $poolOS + "O1"; $postSyncScript = "C:\scripts\access_prep.bat" ;$ClassType="Access"; break}
                        "MICROSOFT EXCEL*" {$VDGName = "VDG" + $poolOS + "O1"; $postSyncScript = "C:\scripts\excel_prep.bat" ; $ClassType="Excel"; break}
                        "MICROSOFT WORD*" {$VDGName = "VDG" + $poolOS + "O1"; $postSyncScript = "C:\scripts\word_prep.bat" ;$ClassType="Word";  break}
                        "MICROSOFT OUTLOOK*" {$VDGName = "VDG" + $poolOS + "O1"; $postSyncScript = "C:\scripts\outlook_prep.bat" ;$ClassType="Outlook"; break}
                        "MICROSOFT POWERPOINT*" {$VDGName = "VDG" + $poolOS + "O1"; $postSyncScript = "C:\scripts\powerpoint_prep.bat" ;$ClassType="PowerPoint"; break}
                        "*MICROSOFT PROJECT*" {$VDGName = "VDGW63PROJECTv11"; $postSyncScript = "C:\scripts\project_prep.bat" ; $ClassType="Project";break}
                        "USING MICROSOFT SHAREPOINT*" {$VDGName = "VDG" + $poolOS + "O1" ; $postSyncScript = "C:\scripts\sharepoint_prep.bat" ; $ClassType="Sharepoint"; break}
                        "*JAVA*" {$VDGName = "VDGW100JAVA" ;$postSyncScript = "C:\scripts\java_prep.bat" ; $ClassType="Java";  break}
                        "*HTML*" {$VDGName = "VDGW100JAVA" ;$postSyncScript = "C:\scripts\java_prep.bat" ; $ClassType="HTML";  break}
                        "*C++*" {$VDGName = "VDG" + $poolOS + "CPP" ;$postSyncScript = "C:\scripts\cpp_prep.bat" ;$ClassType="CPP";  break}
                        #"*PHOTOSHOP*" {$VDGName = "VDG" + $poolOS + "" ;$ClassType="PhotoShop"; break}
                        "*SKETCHUP*" {$VDGName = "VDG" + $poolOS + "SKETCH" ;$postSyncScript = "C:\scripts\sketchup_prep.bat" ;$ClassType="SketchUp"; break}
                        "QUICKBOOKS*" {$VDGName = "VDG" + $poolOS + "QB" ; $postSyncScript = "" ; $ClassType="QuickBooks"; break}
                        "*MATLAB*" {$VDGName = "VDGW100MATLAB" ; $postSyncScript = "C:\scripts\matlab_prep.bat" ;$ClassType="MatLab"; break}
                        "*DOORS*" {$VDGName = "VDG" + $poolOS + "DOORS" ; $postSyncScript = "" ;$ClassType="DOORS"; break}
                        "*SYSML*" {$VDGName = "VDG" + $poolOS + "CAMEO" ; $postSyncScript = "C:\scripts\cameo_prep.bat" ; $ClassType="Magic Draw"; break}
                        "Network+*" {$VDGName = "VDGW100NET" ; $postSyncScript = "" ;$ClassType="Cert"; break}
                        "Security+*" {$VDGName = "VDGW100O16" ; $postSyncScript = "C:\scripts\office_prep.bat" ;$ClassType="Cert"; break}
                        "*PYTHON*" {$VDGName = "VDG" + $poolOS + "PYTHON" ; $postSyncScript = "C:\scripts\python_prep.bat" ; $ClassType="Python"; break}
                        "*ORACLE*" {$VDGName = "VDGW100ORCL" ; $postSyncScript = "C:\scripts\office_prep.bat" ; $ClassType="ORACLE"; break}
                        default {$VDGName = "VDGW100O16" ; $postSyncScript = "C:\scripts\office_prep.bat" ;break}
                    }
                }

                #get correct VDG or group of VDGs
                $VDGObj = Get-VM -Name "VDG*" | Where-Object {$_.Name -like ($VDGName + "*") -and $_.Name -notlike "*OLD*"} | Select-Object * | Sort-Object -Property Name
                $output = "Gold Disc assigned --" + $VDGObj[$VDGObj.Count - 1].Name
                Write-Output $output

               <#  if($VDGObj.Count > 1)
                {
                    #will get the latest HW version of multiple found VDGs
                    #VDG names need v10, v11, etc appended to the end
                    $VDGObj = $VDGObj | Sort-Object -Property Name
                    $VDGObj = $VDGObj[$VDGObj.Count - 1]
                } #>

                #assign path to most current VDG - using $VDGObj[$VDGObj.Count - 1] after sort points to highest HW ver
                $parentVMPath = "/RESOURCE/vm/" + $VDGObj[$VDGObj.Count - 1].Folder + "/" + $VDGObj[$VDGObj.Count - 1].Name
                $output = "Parent VM path -- " + $parentVMPath
                Write-Output $output

                #get snapshots for VDG
                $snapObj = Get-Snapshot -VM $VDGObj[$VDGObj.Count - 1].name | Sort-Object name
                $output = "Sanpshot assigned -- " + $VDGObj[$VDGObj.Count - 1].name
                Write-Output $output
                
                #builds path to SS
                $parentSnapPath  = ""
                foreach($snap in $snapObj)
                {
                    #build root path
                    #Write-Host "Snap   " $snap.ParentSnapshot.Name
                    #Write-Host "ParentsnapPath   " $parentSnapPath
                    $parentSnapPath  = $parentSnapPath +$snap.ParentSnapshot.Name + "/"
                    if($snap -eq $snapObj[$snapObj.Count - 1])
                    {
                        #add on name of SS to path
                        $parentSnapPath  = $parentSnapPath + $snap.Name
                        $output = "ParentsnapPath -- " + $parentSnapPath
                        Write-Output $output
                    }
                }
                
                #assign resource pool - same as host
                $resourcePoolPath = "/resource/host/" + $targetHost.Name + "/Resources"
                $output = "Resources pool path -- " + $resourcePoolPath
                Write-Output $output
                #assigns datastore for OS
                $OSStorage = Get-Datastore -RelatedObject $targetHost -Name "*_OS_*"
                $output = "OS Storage Disk -- " + $OSStorage.Name
                Write-Output $output
                #datastore for persistent disc
                $persistentStorage = Get-Datastore -RelatedObject $targetHost -Name "*_Per*"
                $output = "Persistent Disk -- " + $persistentStorage.Name
                Write-Output $output
                #datastore specs
                $dataStoreSpecs = "[Aggressive,data]/RESOURCE/host/" + $targetHost.Name + "/" + $persistentStorage.name + ";[Aggressive,OS]/RESOURCE/host/" + $targetHost.Name + "/" + $OSStorage
                $output = "Data store specs -- " + $dataStoreSpecs
                Write-Output $output
                #name of clones will be the same as the CourseID
                #ORACLE VMs dont like "_" in host name - remove and "_"s from pool host name prefix
                if($class.CourseID -like "*_*")
                {
                    $namePrefix = "XXX" + $class.CourseID.split("_")[0] + "{n:fixed=2}"
                }
                else
                {
                    $namePrefix = "XXX" + $class.CourseID + "{n:fixed=2}"
                }
                $output = "Name prefix -- " + $namePrefix
                Write-Output $output
                $description = "Pool created by CreateNewPoolfromXen script on " + (Get-Date).ToString()
                $output = "Description -- " + $description
                Write-Output $output
                

                Collect-Errors -LogLines $Error -Label "Error Creating Pool" -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)

                   
                Add-AutomaticLinkedClonePool -Pool_id $class.CourseID `
                                             -DisplayName $class.CourseTitle `
                                             -Vc_id 'fa56cb89-bf14-450a-bc59-644e9872c2cd' `
                                             -FolderId 'Class pools' `
                                             -Persistence Persistent `
                                             -VmFolderPath "/RESOURCE/vm/LinkedClones" `
                                             -ResourcePoolPath $resourcePoolPath `
                                             -ParentVmPath $parentVMPath `
                                             -ParentSnapshotPath $parentSnapPath `
                                             -DatastoreSpecs $dataStoreSpecs `
                                             -Composer_ad_id 'f1b72e8f-9c63-46fa-8da0-011bfba047ab' `
                                             -OrganizationalUnit 'OU=Stuff' `
                                             -PostSyncScript $postSyncScript `
                                             -MinimumCount ($class.TotalEnroll + 1) `
                                             -MaximumCount ($class.TotalEnroll + 1) `
                                             -RefreshPolicyType Never `
                                             -NamePrefix $namePrefix `
                                             -PowerPolicy poweroff `
                                             -IsUserResetAllowed $true `
                                             -SuspendProvisioningOnError $true `
                                             -AutoLogoffTime 120 `
                                             -DefaultProtocol PCOIP `
                                             <#-AllowMultipleSessions $false #> `
                                             -AllowProtocolOverride $true `
                                             -FlashQuality NO_CONTROL `
                                             -FlashThrottling DISABLED `
                                             -IsProvisioningEnabled $false `
                                             -UseUserDataDisk $true `
                                             -DataDiskLetter P `
                                             -DataDiskSize 2048 `
                                             -UseTempDisk $true `
                                             -TempDiskSize 4096 `
                                             -Description $description `
                                             -UseSeSparseDiskFormat $true `
                                             -HeadroomCount 1 `
                                             -SeSparseThreshold 0
                                                                                        
                    if($Error.Count -gt 0)
                    {
                        Collect-Errors -LogLines $Error -Label ("Error Creating Pool" + $($class.CourseID)) -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
                    }
                    else
                    {
                        $NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- INFO -- $($class.CourseID) Pool Created")
                    }
                    Write-Output "Starting sleep 180"
                    Start-Sleep -Seconds 180 -Verbose
                    #set pool entitlement
                    #matches on substrings from first 4 and last 4 chars of instructors name to account for name differences in Xen and AD
                    $EntitleIns = Get-ADUser -Filter * -SearchBase "OU=Instructors" | Where-Object {$_.Name -like ("*" + ($class.Instructor.Substring($class.Instructor.Length - 4,4))) -and $_.Name -like (($class.Instructor.Substring(0,4)) + "*")}
                    
                    if($ClassType)#skips pool entitlement if no match on VDG disk - means it chose defualt option in switch
                    {
                        $EntitleGroup = Get-ADGroup -Filter * -SearchBase "OU=Labs" | Where-Object {$_.Name.Contains($ClassType + " Students")}
                    }
                    foreach ($grp in $EntitleGroup)
                    {
                        Add-PoolEntitlement -Pool_id $class.CourseID -Sid $grp.SID -Verbose
                    }
                    Add-PoolEntitlement -Pool_id $class.CourseID -Sid $EntitleIns.SID -Verbose
                    
                    if($Error.Count -gt 0)
                    {
                        Collect-Errors -LogLines $Error -Label ("Error Adding Entitlements to Pool" + $($class.CourseID)) -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
                    }
                    else
                    {
                        $NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- INFO -- $($class.CourseID) Entitlements Added")
                    }

                    Write-Output "Starting final config"
                    Set-BCPoolHtmlAccess -Pool_id $class.CourseID -HtmlAccess $true 
                    Set-PoolReuseFlag -Pool_id $class.CourseID -ReuseFlag $true
                    Set-PoolBlackoutTimes -Pool_id $class.CourseID -StartTime "07:00" -StopTime "23:00" -days 1,2,3,4,5
                    Set-PoolPageSharing -Pool_Id $class.CourseID -Flag GLOBAL
                    Enable-PoolStorageAccelerator -Pool_id $class.CourseID -Flag $true
                    Set-PoolStorageAcceleratorDisks -Pool_id $class.CourseID -UDDisk $true
                    Set-PoolDisplay -Pool_Id $class.CourseID -numDisplays 1
                    Enable-PoolHTMLAccess -Pool_Id $class.CourseID -HTMLAccess
                    
                    Collect-Errors -LogLines $Error -Label ("Error with final pool config" + $($class.CourseID)) -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
                    
                    #####Change all the other stuff
                    
                    ####have pool create with provisioning disabled - re-eanble after last changes are made
                    Update-AutomaticLinkedClonePool -Pool_id $class.CourseID -IsProvisioningEnabled $true -Verbose

                    $bodyText += $class.courseTitle + " CREATED---- Pool Size: " + ($class.TotalEnroll + 1) + "`n"


                                                                                
                }
            else
            {
                Write-Host "NOT CreatingPool" $class.CourseTitle
            }
     }
}
Stop-Transcript

$body = "Script: \CreatNewPoolsFromXenDB.ps1 `nTask: Create and Update VM Pools `nLog: CreateNewPoolsFromXenDB.log `nPools Created and Updated`n________________________________`n" + $bodyText

Send-MailMessage -From XXXXX -To XXXXX -SmtpServer $SMTP -Subject "Create and Update VM Pools Finished" -Body $body
Collect-Errors -LogLines $Error -Level ERROR -LineNum (Get-CurrentLine) -PassedList ([ref]$NotificationLog)
$NotificationLog.Add((Get-Date -Format yyyyMMdd-HH:mm:ss.ff).ToString() + " -- INFO -- Script EXITING normally") | Out-Null
Write-ToMasterLog -Entries $NotificationLog -Header $Header


    
