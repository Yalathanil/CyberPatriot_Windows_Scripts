# --------------------------------------------------------------------------------------
#       Title: CIS-CAT Powershell Cmdlets
# Description: The functions contained in this script are utilized by a number of probes
#              contained within the CIS-CAT software.
#
# Author            Modification Date          Description of Modification(s)
# --------------------------------------------------------------------------------------
# Bill Munyan       April 17, 2013             Original Author
# Bill Munyan       July 3, 2014               Added dot-sourcing of library functions
# --------------------------------------------------------------------------------------

function Get-FileInformation {
    Param (
		[string]$path
    )
    $atime = (Get-ItemProperty -Path $path -Name LastAccessTime).LastAccessTime.ToFileTime()
    $ctime = (Get-ItemProperty -Path $path -Name CreationTime).CreationTime.ToFileTime()
    $mtime = (Get-ItemProperty -Path $path -Name LastWriteTime).LastWriteTime.ToFileTime()
    $owner = Get-ACL -Path $path | Select-Object Owner
    
    $stuff = Get-Item $path | Select-Object FullName, DirectoryName, Name, Length
    $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path)

    $r = New-Object PSObject -Property @{
		"filepath"   = $stuff.FullName
		"path"   = $stuff.DirectoryName
		"filename"         = $stuff.Name
		"size"       = $stuff.Length
		"owner" = $owner.Owner
		"a_time"   = $atime
		"c_time"   = $ctime
		"m_time"   = $mtime
        "ms_checksum" = "TODO"
        "version" = $version.FileVersionRaw
        "type" = "TODO"
        "development_class" = "TODO"
        "company" = $version.CompanyName
        "internal_name" = $version.InternalName
        "language" = $version.Language
        "original_filename" = $version.OriginalFilename
        "product_name" = $version.ProductName
        "product_version" = $version.ProductVersionRaw
        "windows_view" = "64_bit"
        "version_info_version" = $version.FileVersion
        "version_info_product_version" = $version.ProductVersion
	}
    #$r

    Write-Output "filepath=$($r.filepath)"
    Write-Output "version=$($r.version)"
}

#
#    Function: Wua-UpdateSearcher
# Description: Utilizing the passed in search parameter, probe the system for
#              matching Windows Update IDs
#
function Wua-UpdateSearcher {
	# Function Parameters.
	# According to the OVAL specification for WuaUpdateSearcherBehaviors, 
	#  'include_superseded_updates' is a boolean flag that when set to true 
	#  indicates that the search results should include updates that are superseded 
	#  by other updates in the search results. When set to 'false' superseded updates 
	#  should be excluded from the set of matching update items. 
	#  *** The default value is 'true'. ***
	Param (
		[string]$search_criteria, 
		[boolean]$include_superceded_updates = $true 
	)
	
	# create the windows update searcher from the update session...
	$wus = New-Object -ComObject Microsoft.Update.Searcher
	
	# execute the search query...
	$results  = $wus.Search($search_criteria)
	
	# check the return code for errors...
	if ($results.ResultCode -eq 2) {
		# create the output...
		if ($results.Updates.Count -gt 0) {
			$item_open_element  = "<wuaupdatesearcher_item status='exists'>"
			$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
			$item_close_element = "</wuaupdatesearcher_item>"

			Write-Output $item_open_element
			Write-Output $criteria_element

			# The "$results.Updates" represents the list of "Item"'s in the IUpdateCollection
			# returned from the Search method...
			foreach ($windows_update in $results.Updates) {
				# the Identity Gets an interface that contains the unique identifier of the update...
				$curr_update = "<update_id datatype='string'>" + $windows_update.Identity.UpdateId + "</update_id>"
				Write-Output $curr_update

				# output any superceded id's, if requested
				if (($include_superceded_updates) -and ($windows_update.SupercededUpdateIDs.Count -gt 0)) {
					# The "SupercededUpdateIDs" property of an IUpdate instance gets a 
					#  collection of update identifiers. This collection of identifiers 
					#  specifies the updates that are superseded by the update...
					foreach ($superceded_id in $windows_update.SupercededUpdateIDs) {
						$parent_update = "<update_id datatype='string'>" + $superceded_id + "</update_id>"
						Write-Output $parent_update
					}
				}
			}
			Write-Output $item_close_element
		} else {
			$item_open_element  = "<wuaupdatesearcher_item status='does not exist'>"
			$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
			$item_close_element = "</wuaupdatesearcher_item>"

			Write-Output $item_open_element
			Write-Output $criteria_element
			Write-Output $item_close_element
		}
	} else {
		$item_open_element  = "<wuaupdatesearcher_item status='error'>"
		$criteria_element   = "<search_criteria datatype='string'>" + $search_criteria + "</search_criteria>"
		$message_element    = "<message>Update Searcher did not return successfully</message>"
		$item_close_element = "</wuaupdatesearcher_item>"

		Write-Output $item_open_element
		Write-Output $criteria_element
		Write-Output $message_element
		Write-Output $item_close_element
	}
}

#
#    Function: Ciscat-GetPSModules
# Description: Retrieve the loaded PowerShell Module(s)
#
function Ciscat-GetPSModules {
	# Function Parameters -- None
	
	# Get Snap-ins loaded by default.  these are noted as modules which 
	#  start with "Microsoft.PowerShell.", such as:
	#	- Microsoft.PowerShell.Diagnostics
	#	- Microsoft.PowerShell.Core
	#	- Microsoft.PowerShell.Utility
	#	- Microsoft.PowerShell.Host
	#	- Microsoft.PowerShell.Management
	#	- Microsoft.PowerShell.Security, as well as
	#	- Microsoft.WSMan.Management
	$imported_snapins   = Get-PSSnapin
	
	#
	# <modules>
	#   <module name="[$name]" guid="[$guid./<none>]" version="[$vers]" loaded="[$loaded]"/>
	#   ...
	# </modules>
	#
	$modules_start = "<modules>"
	$modules_end   = "</modules>"
	
	Write-Output $modules_start
	
	#
	# Imported Snap-Ins
	#
	foreach ($imported_snapin in $imported_snapins) {
		$name   = $imported_snapin.Name
		$guid   = "[none]"
		$vers   = [string]::Concat($imported_snapin.Version.Major, ".", $imported_snapin.Version.Minor)
		$loaded = "true"
		$module =  "<module name=`"" + $name + "`" guid=`"" + $guid + "`" version=`"" + $vers + "`" loaded=`"" + $loaded + "`"/>"
		
		Write-Output $module
	}
	
	#
	# get modules that have been imported into the current session.
	#
	$imported_modules = Get-Module
	
	# get all available modules...
	$installed_modules = Get-Module -ListAvailable
	
	foreach ($installed_module in $installed_modules) {
		$name = $installed_module.Name
		$guid = $installed_module.Guid
		$vers = [string]::Concat($installed_module.Version.Major, ".", $installed_module.Version.Minor)
	
		$loaded = "false"
		foreach ($imported_module in $imported_modules) {
			if ($imported_module.Name -eq $installed_module.Name) {
				$loaded = "true"
			}
		}
		
		$module = "<module name=`"" + $name + "`" guid=`"" + $guid + "`" version=`"" + $vers + "`" loaded=`"" + $loaded + "`"/>"
				
		Write-Output $module
	}
	Write-Output $modules_end
}

#
#    Function: Ciscat-InvokeCmdlet
# Description: Invoke
#       Usage: Ciscat-InvokeCmdlet "Get-service -name lanman* | Select-Object displayname"
#
function Ciscat-InvokeCmdlet {
	# Function Parameters.
	Param (
		[string]$cmdlet_string = $(throw "Mandatory parameter -cmdlet_string"), 
		[string]$import_string = ""
	)

	if ($import_string -ne "") {
		$import_command = [string]::Concat($import_string, " -ErrorAction Stop")
		try {
			Invoke-Expression $import_command
		} catch [Exception] {
			$msg    = "Error importing module specified by '" + $import_string + "'"
			$out    = ConvertFrom-StringData -StringData $msg
			$xml    = $out | ConvertTo-XML -As String -NoTypeInformation
			$result = $xml -replace '<Object>([^<]+)</Object>', '<Object><Property Name="result">$1</Property></Object>' -replace '<([/]?)Objects>', '<$1RecordSet>' -replace '<([/]?)Object>', '<$1Record>' -replace '<([/]?)Property', '<$1Field'
			return $result
		}
	}
	
	# Output should be in the form of:
	# <Objects>
	#     <Object>
	#     ...
	#     </Object>
	# </Objects>
	
	$command = [string]::Concat($cmdlet_string, " -ErrorAction Stop")
	try {
		$out = Invoke-Expression $command
	} catch [Exception] {
		$msg = "Error=Error invoking cmdlet '" + $cmdlet_string + "'"
		$out = ConvertFrom-StringData -StringData $msg
	}
	$xml = $out | ConvertTo-XML -As String -NoTypeInformation
	return TransformTo-RecordSet($xml)
}

#
#    Function: Format-XML
# Description: Pretty-Print the XML
#       Usage: Format-XML($xml)
#
function Format-XML ([xml]$xml, $indent=2) {
	#
	# Create the objects necessary to format the output...
	#
	$StringWriter = New-Object System.IO.StringWriter 
	$XmlWriter    = New-Object System.Xml.XmlTextWriter $StringWriter
	
	#
	# Set the formatting options...
	#
	$xmlWriter.Formatting = [System.Xml.Formatting]::Indented
	$xmlWriter.Indentation = $Indent 
	
	#
	# Write the formatted XML to formatting objects...
	#
	$xml.WriteContentTo($XmlWriter) 
	$XmlWriter.Flush() 
	$StringWriter.Flush()
	
	#
	# Return the formatted content...
	#
	return $StringWriter.ToString() 
}

#
#    Function: TransformTo-RecordSet
# Description: Converts the PowerShell XML <Objects> representation to <RecordSet>
#       Usage: TransformTo-RecordSet($xml)
#
function TransformTo-RecordSet ([xml]$objectsDoc)
{
	[System.Xml.XmlDocument] $rs = new-object System.Xml.XmlDocument
	$root = $rs.CreateElement("RecordSet")
	$rs.AppendChild($root) | Out-Null

	# Perform the XPath (NOTE: XPath is case-sensitive)...
	$nodelist = $objectsDoc.selectnodes("/Objects/Object")
	foreach ($object in $nodelist) {
		$record = $rs.CreateElement("Record")

		$proplist = $object.SelectNodes("Property")
		foreach ($prop in $proplist) {
			$name_value  = $prop.getAttribute("Name")
			$field_value = $prop.get_InnerXml()

			$field = $rs.CreateElement("Field")
			$field.InnerText = $field_value

			$fieldattr = $rs.CreateAttribute("Name")
			$fieldattr.Value = $name_value
			$field.SetAttributeNode($fieldattr) | Out-Null

			$record.AppendChild($field) | Out-Null
		}
		$root.AppendChild($record) | Out-Null
	}

	Format-XML($rs)
}

#####################################################################
#  VMware Functions...
#####################################################################

#
#    Function: Test-WebServerSSL
# Description: Verifies SSL certificates
#       Usage: Test-WebServerSSL($url)
#
function Test-WebServerSSL {
# Function original location: http://en-us.sysadmins.lv/Lists/Posts/Post.aspx?List=332991f0-bfed-4143-9eea-f521167d287c&ID=60
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$VMHost,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$URL,
        [Parameter(Position = 1)]
        [ValidateRange(1,65535)]
        [int]$Port = 443,
        [Parameter(Position = 2)]
        [Net.WebProxy]$Proxy,
        [Parameter(Position = 3)]
        [int]$Timeout = 15000,
        [switch]$UseUserContext
    )
	Process {
#Add-Type @"
#using System;
#using System.Net;
#using System.Security.Cryptography.X509Certificates;
#namespace PKI {
#    namespace Web {
#        public class WebSSL {
#            public Uri OriginalURi;
#            public Uri ReturnedURi;
#            public X509Certificate2 Certificate;
#            //public X500DistinguishedName Issuer;
#            //public X500DistinguishedName Subject;
#            public string Issuer;
#            public string Subject;
#            public string[] SubjectAlternativeNames;
#            public bool CertificateIsValid;
#            //public X509ChainStatus[] ErrorInformation;
#            public string[] ErrorInformation;
#            public HttpWebResponse Response;
#        }
#    }
#}
#"@
        $ConnectString = "https://$url`:$port"
        $WebRequest = [Net.WebRequest]::Create($ConnectString)
        $WebRequest.Proxy = $Proxy
        $WebRequest.Credentials = $null
        $WebRequest.Timeout = $Timeout
        $WebRequest.AllowAutoRedirect = $true
    	
    	$Callback = [Net.ServicePointManager]::ServerCertificateValidationCallback
        [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        try {$Response = $WebRequest.GetResponse()}
        catch {}
        if ($WebRequest.ServicePoint.Certificate -ne $null) {
            $Cert = [Security.Cryptography.X509Certificates.X509Certificate2]$WebRequest.ServicePoint.Certificate.Handle
            try {$SAN = ($Cert.Extensions | Where-Object {$_.Oid.Value -eq "2.5.29.17"}).Format(0) -split ", "}
            catch {$SAN = $null}
            $chain = New-Object Security.Cryptography.X509Certificates.X509Chain -ArgumentList (!$UseUserContext)
            [void]$chain.ChainPolicy.ApplicationPolicy.Add("1.3.6.1.5.5.7.3.1")
            $Status = $chain.Build($Cert)
            #$Result = New-Object PKI.Web.WebSSL -Property @{
            #    OriginalUri = $ConnectString;
            #    ReturnedUri = $Response.ResponseUri;
            #    Certificate = $WebRequest.ServicePoint.Certificate;
            #    Issuer = $WebRequest.ServicePoint.Certificate.Issuer;
            #    Subject = $WebRequest.ServicePoint.Certificate.Subject;
            #    SubjectAlternativeNames = $SAN;
            #    CertificateIsValid = $Status;
            #    Response = $Response;
            #    ErrorInformation = $chain.ChainStatus | ForEach-Object {$_.Status}
            #}
            $chain.Reset()
            #[Net.ServicePointManager]::ServerCertificateValidationCallback = $null
    		[Net.ServicePointManager]::ServerCertificateValidationCallback = $Callback
            
            $DaysTillExpire = (New-TimeSpan -Start (Get-Date) -End ($WebRequest.ServicePoint.Certificate.NotAfter)).Days
            
            #$Result
            $Details = New-Object PsObject 
            $Details | Add-Member Noteproperty VMHost -Value $VMHost;
            $Details | Add-Member Noteproperty OriginalUri -Value $ConnectString;
            $Details | Add-Member Noteproperty CertificateIsValid -Value $Status;
            $Details | Add-Member Noteproperty Issuer -Value $WebRequest.ServicePoint.Certificate.Issuer;
            $Details | Add-Member Noteproperty Expires -Value $WebRequest.ServicePoint.Certificate.NotAfter;
            $Details | Add-Member Noteproperty DaysTillExpire -Value $DaysTillExpire;
            
            $Details
        } else {
            Write-Error $Error[0]
        }
    }
}

#
#    Function: Get-FreeVDSPort
# Description: Check for the number of free ports on all VDS PortGroups
#       Usage: Get-FreeVDSPort(vdspg)
#
Function Get-FreeVDSPort {
	Param (
		[parameter(Mandatory=$true,ValueFromPipeline=$true)]
		$VDSPG
	)
	Process {
		$nicTypes = "VirtualE1000","VirtualE1000e","VirtualPCNet32","VirtualVmxnet","VirtualVmxnet2","VirtualVmxnet3" 
		$ports = @{}

		$VDSPG.ExtensionData.PortKeys | Foreach {
			$ports.Add($_,$VDSPG.Name)
		}

		$VDSPG.ExtensionData.Vm | Foreach {
			$VMView = Get-View $_
			$nic = $VMView.Config.Hardware.Device | where {$nicTypes -contains $_.GetType().Name -and $_.Backing.GetType().Name -match "Distributed"}
			$nic | where {$_.Backing.Port.PortKey} | Foreach {$ports.Remove($_.Backing.Port.PortKey)}
		}

		($ports.Keys).Count
	}
}

Function Get-SerialPort { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        Foreach ($VMachine in $VM) { 
            $Found = $false
            Foreach ($Device in $VMachine.ExtensionData.Config.Hardware.Device) { 
                If ($Device.gettype().Name -eq "VirtualSerialPort") { 
                    $Found = $true
                    
                    $Details = New-Object PsObject 
                    $Details | Add-Member Noteproperty Parent -Value $VMachine 
                    $Details | Add-Member Noteproperty Name -Value $Device.DeviceInfo.Label 
                    If ($Device.Backing.FileName) { $Details | Add-Member Noteproperty Filename -Value $Device.Backing.FileName } 
                    If ($Device.Backing.Datastore) { $Details | Add-Member Noteproperty Datastore -Value $Device.Backing.Datastore } 
                    If ($Device.Backing.DeviceName) { $Details | Add-Member Noteproperty DeviceName -Value $Device.Backing.DeviceName } 
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $Device.Connectable.AllowGuestControl 
                    $Details | Add-Member Noteproperty Connected -Value $Device.Connectable.Connected 
                    $Details | Add-Member Noteproperty StartConnected -Value $Device.Connectable.StartConnected 
                    
                    $AllDevices += $Details
                } 
            }
            
            If (-not $Found) {
                $Details = New-Object PsObject 
                $Details | Add-Member Noteproperty Parent -Value $VMachine
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty AllowGuestControl -Value $false 
                $Details | Add-Member Noteproperty Connected -Value $false 
                $Details | Add-Member Noteproperty StartConnected -Value $false 
                
                $AllDevices += $Details
            }
        } 
        $AllDevices
    } 
}

Function Remove-SerialPort { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM, 
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)] 
        $Name 
    ) 
    Process { 
        $VMSpec = New-Object VMware.Vim.VirtualMachineConfigSpec 
        $VMSpec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec 
        $VMSpec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec 
        $VMSpec.deviceChange[0].operation = "remove" 
        $Device = $VM.ExtensionData.Config.Hardware.Device | Foreach { 
            $_ | Where {$_.gettype().Name -eq "VirtualSerialPort"} | Where { $_.DeviceInfo.Label -eq $Name } 
        } 
        $VMSpec.deviceChange[0].device = $Device 
        $VM.ExtensionData.ReconfigVM_Task($VMSpec) 
    } 
}

Function Get-ParallelPort { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        Foreach ($VMachine in $VM) { 
            $Found = $false
            Foreach ($Device in $VMachine.ExtensionData.Config.Hardware.Device) { 
                If ($Device.gettype().Name -eq "VirtualParallelPort") { 
                    $Found = $true
                    
                    $Details = New-Object PsObject 
                    $Details | Add-Member Noteproperty Parent -Value $VMachine 
                    $Details | Add-Member Noteproperty Name -Value $Device.DeviceInfo.Label 
                    If ($Device.Backing.FileName) { $Details | Add-Member Noteproperty Filename -Value $Device.Backing.FileName } 
                    If ($Device.Backing.Datastore) { $Details | Add-Member Noteproperty Datastore -Value $Device.Backing.Datastore } 
                    If ($Device.Backing.DeviceName) { $Details | Add-Member Noteproperty DeviceName -Value $Device.Backing.DeviceName } 
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $Device.Connectable.AllowGuestControl 
                    $Details | Add-Member Noteproperty Connected -Value $Device.Connectable.Connected 
                    $Details | Add-Member Noteproperty StartConnected -Value $Device.Connectable.StartConnected 
                    
                    $AllDevices += $Details
                } 
            } 
            
            If (-not $Found) {
                $Details = New-Object PsObject 
                $Details | Add-Member Noteproperty Parent -Value $VMachine
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty AllowGuestControl -Value $false 
                $Details | Add-Member Noteproperty Connected -Value $false 
                $Details | Add-Member Noteproperty StartConnected -Value $false 
                
                $AllDevices += $Details
            }
        } 
        $AllDevices
    } 
}

Function Remove-ParallelPort { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM, 
        [Parameter(Mandatory=$True,ValueFromPipelinebyPropertyName=$True)] 
        $Name 
    ) 
    Process { 
        $VMSpec = New-Object VMware.Vim.VirtualMachineConfigSpec 
        $VMSpec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec 
        $VMSpec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec 
        $VMSpec.deviceChange[0].operation = "remove" 
        $Device = $VM.ExtensionData.Config.Hardware.Device | Foreach { 
            $_ | Where {$_.gettype().Name -eq "VirtualParallelPort"} | Where { $_.DeviceInfo.Label -eq $Name } 
        } 
        $VMSpec.deviceChange[0].device = $Device 
        $VM.ExtensionData.ReconfigVM_Task($VMSpec) 
    } 
}

Function Get-CiscatFloppyDrive { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        foreach ($V in $VM) {
            $Devices = $V | Get-FloppyDrive | Select-Object Parent, Name, ConnectionState
                
            if ($Devices) {
                foreach ($Device in $Devices) {
                    $Details = New-Object PsObject
                    
                    $Details | Add-Member Noteproperty Parent -Value $V
                    $Details | Add-Member Noteproperty Name -Value $Device.Name
                    
                    $csa = $Device.ConnectionState.ToString().split(",")
                    $Details | Add-Member Noteproperty Connected -Value $csa[0].trim()
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $csa[1].trim()
                    $Details | Add-Member Noteproperty StartConnected -Value $csa[2].trim()
                    
                    $AllDevices += $Details
                }
            } else {
                $Details = New-Object PsObject
                
                $Details | Add-Member Noteproperty Parent -Value $V
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty Connected -Value "NotConnected"
                $Details | Add-Member Noteproperty AllowGuestControl -Value "NoGuestControl"
                $Details | Add-Member Noteproperty StartConnected -Value "NoStartConnected"
                
                $AllDevices += $Details
            }
            $AllDevices
        }
    }
}

Function Get-CiscatCDDrive { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        foreach ($V in $VM) {
            $Devices = $V | Get-CDDrive | Select-Object Parent, Name, ConnectionState
            
            if ($Devices) {
                foreach ($Device in $Devices) {
                    $Details = New-Object PsObject
                    
                    $Details | Add-Member Noteproperty Parent -Value $V
                    $Details | Add-Member Noteproperty Name -Value $Device.Name
                    
                    $csa = $Device.ConnectionState.ToString().split(",")
                    $Details | Add-Member Noteproperty Connected -Value $csa[0].trim()
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $csa[1].trim()
                    $Details | Add-Member Noteproperty StartConnected -Value $csa[2].trim()
                    
                    $AllDevices += $Details
                }
            } else {
                $Details = New-Object PsObject
                
                $Details | Add-Member Noteproperty Parent -Value $V
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty Connected -Value "NotConnected"
                $Details | Add-Member Noteproperty AllowGuestControl -Value "NoGuestControl"
                $Details | Add-Member Noteproperty StartConnected -Value "NoStartConnected"
                
                $AllDevices += $Details
            }
            $AllDevices
        }
    }
}

Function Get-CiscatUSBDevice { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        foreach ($V in $VM) {
            $Devices = $V | Get-USBDevice | Select-Object Parent, Name, ConnectionState
            
            
            if ($Devices) {
                $Details = New-Object PsObject
                foreach ($Device in $Devices) {
                    $Details | Add-Member Noteproperty Parent -Value $V
                    $Details | Add-Member Noteproperty Name -Value $Device.Name
                    
                    $csa = $Device.ConnectionState.ToString().split(",")
                    $Details | Add-Member Noteproperty Connected -Value $csa[0].trim()
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $csa[1].trim()
                    $Details | Add-Member Noteproperty StartConnected -Value $csa[2].trim()
                    
                    $AllDevices += $Details
                }
            } else {
                $Details = New-Object PsObject
                
                $Details | Add-Member Noteproperty Parent -Value $V
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty Connected -Value "NotConnected"
                $Details | Add-Member Noteproperty AllowGuestControl -Value "NoGuestControl"
                $Details | Add-Member Noteproperty StartConnected -Value "NoStartConnected"
                
                $AllDevices += $Details
            }
            $AllDevices
        }
    }
}

Function Get-CiscatHardDisk { 
    Param ( 
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)] 
        $VM 
    ) 
    Process { 
        $AllDevices = @()
        foreach ($V in $VM) {
            $Devices = $V | Get-HardDisk | Select-Object Parent, Name, @{N="Connected";E={"Connected"}}, @{N="AllowGuestControl";E={"NoGuestControl"}}, @{N="StartConnected";E={"StartConnected"}}, Persistence
            
            
            if ($Devices) {
                foreach ($Device in $Devices) {
                    $Details = New-Object PsObject
                
                    $Details | Add-Member Noteproperty Parent -Value $V
                    $Details | Add-Member Noteproperty Name -Value $Device.Name
                    $Details | Add-Member Noteproperty Connected -Value $Device.Connected
                    $Details | Add-Member Noteproperty AllowGuestControl -Value $Device.AllowGuestControl
                    $Details | Add-Member Noteproperty StartConnected -Value $Device.StartConnected
                    $Details | Add-Member Noteproperty Persistence -Value $Device.Persistence
                    
                    $AllDevices += $Details
                }
            } else {
                $Details = New-Object PsObject
                
                $Details | Add-Member Noteproperty Parent -Value $V
                $Details | Add-Member Noteproperty Name -Value "N/A"
                $Details | Add-Member Noteproperty Connected -Value "NotConnected"
                $Details | Add-Member Noteproperty AllowGuestControl -Value "NoGuestControl"
                $Details | Add-Member Noteproperty StartConnected -Value "NoStartConnected"
                $Details | Add-Member Noteproperty Persistence -Value "Unknown"
                
                $AllDevices += $Details
            }
            $AllDevices
        }
    }
}

#
#    Function: Get-DriveFormat
# Description: For each file system drive, get its file system format, like NTFS or FAT32
#
Function Get-DriveFormat {
    $All = @()
    Get-PSDrive -PSProvider Microsoft.PowerShell.Core\FileSystem | Foreach-Object {
        $D = New-Object PSObject
        $letter = $_.Name.ToString() + ":"
        $drive = [wmi]"Win32_LogicalDisk='$letter'"
        
        if ($drive.FileSystem) {
            $D | Add-Member Noteproperty Drive -Value $letter
            $D | Add-Member Noteproperty Format -Value $drive.FileSystem 
            $All += $D
        }
    }
    $All
}
