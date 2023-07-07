using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

#Setup a blank outputBody varible.
$outputBody = ""

#process input from the HTTP request and convert the allClients string value to a boolean.
if ($Request.Body -is [Hashtable]) { $body = $Request.Body  } else { $body = $Request.Body | ConvertFrom-Json }
$allClientsBool = $false
if ($Request.Query.allClients -eq 'true') { $allClientsBool = $true }

#Get a filtered client list of only clients that should have code executed.
$clientList = GetClientList -allClients $allClientsBool -excludedClients "$($body.excludedClients)" -includedClients "$($body.includedClients)"

foreach($client in $clientList){
		$outputBody += "Found client $($client.displayName) with tenant ID $($client.tenantId) .`r`n"
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $outputBody
})
