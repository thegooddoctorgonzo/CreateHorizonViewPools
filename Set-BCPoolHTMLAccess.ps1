function Set-BCPoolHtmlAccess ([string]$Pool_id, [boolean]$HtmlAccess) {  
<#  
    .SYNOPSIS  
        enables or disables HTML Access to the given VMware View desktop pool  
    .DESCRIPTION  
        This function enable or disable HTML Access to a desktop pool, by modifying  
        the "pae-ServerProtocolLevel" property of the associated object in the ADAM   
        database via LDAP. This property is a multi-valued attribute contains a array   
        of string, which designates   
        by which protocol desktops can be accessed. It valid values are "PCOIP",  
        "RDP" and "BLAST". Controlling the existance of the string "BLAST" determines  
        if the pool is accessible through HTML Access. The parameter Pool_id determines  
        which object is modified.  
    .EXAMPLE  
        Set-BCPoolHtmlAccess "W7ST620" $True     
    .PARAMETER Pool_id  
        the pool_id of the desktop pool of which to enable or disable HTML access. Wildcards are allowed!  
    .PARAMETER HtmlAccess  
        Boolean value to set the HTML Access to.  
    .OUTPUT  
        None  
    .NOTES  
        Written by Paul Wiegmans on 31-8-2014  
        "pae-ServerProtocolLevel" is a multivalued attribute, which is a little difficult to   
        write correctly to the object.  
        http://www.selfadsi.org/write.htm   
                Google "powershell ldap multi value property"  
        http://jdhitsolutions.com/blog/2011/12/updating-multi-valued-active-directory-properties-part-1/  
#>  
    $dn = "DC=vdi,DC=vmware,DC=int"   # root OU of VMware View ADAM database (CUSTOMIZE ME)   
    $domain = "LDAP://localhost:389/$dn"  # connect to the ADAM database (CUSTOMIZE ME)   
      
    $root = New-Object System.DirectoryServices.DirectoryEntry $domain  
    $query = New-Object System.DirectoryServices.DirectorySearcher  
    $query.searchroot = $root  
    $query.filter = "(&(objectCategory=pae-DesktopApplication)(cn=$pool_id))"  
    $pools = @($query.findall())  
    $propname = "pae-ServerProtocolLevel"  
      
    foreach ($pool in $pools) {      
          
        $poolobj = [ADSI]$pool.GetDirectoryEntry()  
        $protocols = $poolobj.$propname   
        $desiredprotocols = @()       
        foreach ($protocol in $protocols) {  
            if ($protocol -ne "BLAST") {  
                $desiredprotocols += $protocol  # save a list of all existing protocols   
            }  
        }    
          
        if ($HtmlAccess) {          
            $desiredprotocols += "BLAST"  
        }  
        write-verbose ("Desktop pool " + $poolobj.name + " gets protocols: "+$desiredprotocols)  
        $poolobj.$propname = $desiredprotocols     
        #$poolobj.$propname = @("PCOIP","RDP","BLAST")  # to reset to normal values  
        $poolobj.CommitChanges()  
    }       
   
}  
  
  
  
  
#$pool_id = "W7S*"                  # pool_id of pool to set protocols of   
#Set-BCPoolHtmlAccess $pool_id $false  
#Set-BCPoolHtmlAccess $pool_id $true 