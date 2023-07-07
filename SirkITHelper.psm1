function GetClientList{
	[CmdletBinding()]
	param(
			[Parameter(Mandatory=$false)]
			[bool]$allClients = $false,

			[Parameter(Mandatory=$false)]
			[string]$excludedClients = "",

			[Parameter(Mandatory=$false)]
			[string]$includedClients = ""
		)

	# Split the client strings into arrays
	$excludedClientArray = $excludedClients -split ','
	$includedClientArray = $includedClients -split ','
	
	Write-Output "allClients is: $allClients"
	Write-Output "excludedClientArray Count: $($excludedClientArray.Count)"
	Write-Output "includedClientArray Count: $($includedClientArray.Count)"

	#Setup Varibles to access tenent lists.
	$tenantId = $env:TenantID
	$appId = $env:ApplicationID
	$appSecret = $env:ApplicationSecret
	$refreshToken = $env:RefreshToken
	$resource = 'https://graph.microsoft.com/.default'
	$tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
	$graphApiUrl = "https://graph.microsoft.com/v1.0/tenantRelationships/delegatedAdminCustomers"
	$body = @{
		client_id     = $appId
		scope         = $resource
		client_secret = $appSecret
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
	$lighthouseResponse = Invoke-RestMethod -Uri $graphApiUrl -Method Get -Headers $headers
	$lighthouseResponseValue = $lighthouseResponse.value
	$clientList = $lighthouseResponseValue | Select-Object id, @{l = 'customerId'; e = { $_.tenantId } }, displayName | Sort-Object -Property displayName

	Write-Output"clientList Raw Count: $($clientList.Count)"

	if ($allClients) {
		$clientList = $clientList | Where-Object { $_.displayName -notin $excludedClientsArray }
	} else {
		$clientList = $clientList | Where-Object { $_.displayName -in $includedClientsArray }
	}

	Write-Output "clientList Filtered Count: $($clientList.Count)"
	#Return Client list
	return $clientList
}
