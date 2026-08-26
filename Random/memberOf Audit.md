# Identifying memberOf dynamic rule usage

## Dynamic Groups

```powershell
	Connect-MgGraph -Scopes 'Group.Read.All'
	$filter = "startsWith(membershipRule,'user.memberOf') or startsWith(membershipRule,'device.memberOf')"
	$memberOfGroups = Get-MgGroup -filter $filter
	$memberOfGroups | ft id, DisplayName, MembershipRule
```

## Administrative Units

```powershell
	Connect-MgGraph -Scopes 'AdministrativeUnit.Read.All'
	$allAUs = Get-MgDirectoryAdministrativeUnit -All -Property id, displayName, membershipType, membershipRule
	$memberOfAUs = $allAUs | Where-Object {
	    $_.MembershipType -eq 'Dynamic' -and
	    $_.MembershipRule -match 'memberOf'
	}
	$memberOfAUs | ft id, DisplayName, MembershipRule
```

## Entitlement Management Auto-Assignment Policies

```powershell
	Connect-MgGraph -Scopes 'EntitlementManagement.Read.All'
	
	# Get all assignment policies with their targets
	$uri = 'https://graph.microsoft.com/v1.0/identityGovernance/entitlementManagement/assignmentPolicies?$select=id,displayName,automaticRequestSettings,specificAllowedTargets'
	$policies = @()
	while ($uri) {
	    $response = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
	    $policies += @($response.value)
	    $uri = $response.'@odata.nextLink'
	}
	
	# Filter to auto-assignment policies whose rules contain memberOf
	$memberOfPolicies = $policies | Where-Object {
	    $null -ne $_.automaticRequestSettings -and
	    ($_.specificAllowedTargets | Where-Object {
	        $_.'@odata.type' -eq '#microsoft.graph.attributeRuleMembers' -and
	        $_.membershipRule -match 'memberOf'
	    })
	}
	
	$memberOfPolicies | ForEach-Object {
	    [pscustomobject]@{
	        Id             = $_.id
	        DisplayName    = $_.displayName
	        MembershipRule = ($_.specificAllowedTargets |
	            Where-Object { $_.'@odata.type' -eq '#microsoft.graph.attributeRuleMembers' } |
	            ForEach-Object { $_.membershipRule }) -join ' | '
	    }
	} | Format-List
```
