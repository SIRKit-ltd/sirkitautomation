using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

function ConnectToTenantsTeams($ClientID, $AppID, $AppSecret, $rToken){
    $ClientSecret   = $AppSecret
    $ApplicationID = $AppID
    $TenantID = $ClientID
    $RefreshToken = $rToken

    $graphtokenBody = @{   
    Grant_Type    = 'refresh_token' 
    Scope         = "https://graph.microsoft.com/.default"   
    Client_Id     = $ApplicationID   
    Client_Secret = $ClientSecret
    refresh_token = $RefreshToken
    }  

    $graphToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method POST -Body $graphtokenBody | Select-Object -ExpandProperty Access_Token 

    $teamstokenBody = @{   
    Grant_Type    = 'refresh_token'
    Scope         = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239/.default"   
    Client_Id     = $ApplicationID   
    Client_Secret = $ClientSecret
    refresh_token = $RefreshToken
    } 

    $teamsToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token" -Method POST -Body $teamstokenBody | Select-Object -ExpandProperty Access_Token 
    Disconnect-MicrosoftTeams
    Connect-MicrosoftTeams -AccessTokens @("$graphToken", "$teamsToken")
    $TeamsPolicy = Get-CsTeamsUpdateManagementPolicy
    return $TeamsPolicy
}

#Interact with query parameters or the body of the request.
if ($Request.Body -is [Hashtable]) { $body = $Request.Body  } else { $body = $Request.Body | ConvertFrom-Json }
$allClients = 'false'
$allClients = $Request.Query.allClients
$excludedClients = $body.excludedClients -split ','
$includedClients = $body.includedClients -split ','
$outputBody = ""

#Setup Varibles to access tenent lists.
$tenantId = $env:TenantID
$clientId = $env:ApplicationID
$clientSecret = $env:ApplicationSecret
$refreshToken = $env:RefreshToken
$resource = 'https://graph.microsoft.com/.default'
$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$graphApiUrl = "https://graph.microsoft.com/v1.0/tenantRelationships/delegatedAdminCustomers"
$body = @{
    client_id     = $clientId
    scope         = $resource
    client_secret = $clientSecret
    refresh_token = $refreshToken
    grant_type    = 'refresh_token'
}

#Get the Graph Access Token 
$tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body
$graphAccessToken = $tokenResponse.access_token

# Use the Graph access token for Authorization
$headers = @{
    'Authorization' = "Bearer $graphAccessToken"
}
$headerAuthorization = $headers.Authorization
$lighthouseResponse = Invoke-RestMethod -Uri $graphApiUrl -Method Get -Headers $headers
$lighthouseResponseValue = $lighthouseResponse.value
$lighthouseResponseValueSO = $lighthouseResponseValue | Select-Object id, @{l = 'customerId'; e = { $_.tenantId } }, displayName | Sort-Object -Property displayName

if ($allClients -eq 'true') {
    $outputBody += "Executing script on all clients.`r`n"
    foreach($client in $lighthouseResponseValueSO) {
        if ($excludedClients -contains $client.displayName) {
            $outputBody += "Skipping excluded client $($client.displayName).`r`n"
        } else {
            Write-Host "Trying to connect to cleint $($client.displayName)"
            $TeamsPolicy = ConnectToTenantsTeams -ClientID $client.id -AppID $clientId -AppSecret $clientSecret -rToken $refreshToken
            $outputBody += "$($client.displayName) Teams Default Policy name $($TeamsPolicy.Identity) has new teams $($TeamsPolicy.UseNewTeamsClient) `r`n"
        }
    }
} else {
    if ($includedClients -ne $null) {
		$outputBody += "Executing script on specific clients only.`r`n"
		foreach($client in $includedClients){
			$selectedClient = $lighthouseResponseValueSO | Where-Object { $_.displayName -eq $client }
            if ($selectedClient) {
                $outputBody += "Found client $client. Executing script on this client.`r`n"
        
                # Pass the information into your function.
                $TeamsPolicy = ConnectToTenantsTeams -ClientID $selectedClient.id -AppID $clientId -AppSecret $clientSecret -rToken $refreshToken

                #Add your logic here to process $TeamsPolicy
                $outputBody += "$client Teams Default Policy name $($TeamsPolicy.Identity) has new teams $($TeamsPolicy.UseNewTeamsClient) `r`n"
            } else {
                $outputBody += "Client $client not found.`r`n"
            }
        }
    } else {
		$outputBody += "No clients listed in the include list and not set to run on all clients. Please include a list of clients.`r`n"
	}
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $outputBody
})
