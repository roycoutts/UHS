$tests = @(
    '(sn=Kosick)'
    '(sn=Kosick*)'
    '(sn=Kosi*)'
    '(sn=Kos*)'
    '(&(objectCategory=person)(objectClass=user)(sn=Kosick*))'
)

foreach ($filter in $tests) {
    $users = @(Get-ADUser -LDAPFilter $filter)

    Write-Host "`nFilter: $filter" -ForegroundColor Cyan
    Write-Host "Results: $($users.Count)"

    $users | Select-Object Name, SamAccountName
}


Filter: (sn=Kosick)
Results: 1


Filter: (sn=Kosick*)
Results: 1

Filter: (sn=Kosi*)
Results: 1

Filter: (sn=Kos*)
Results: 4

Filter: (&(objectCategory=person)(objectClass=user)(sn=Kosick*))
Results: 1
Name     SamAccountName
----     --------------
e40823   e40823        
e40823   e40823        
e40823   e40823        
e40823   e40823        
E0D509   E0D509        
NS031859 NS031859      
e40369   e40369        
e40823   e40823        




$ldapFiltersToTry = New-Object System.Collections.Generic.List[string]

# Search all relevant AD attributes in one query.
# Supports partial names, EmployeeIDs, SAM accounts, and email.

$ldapConditions = @(
    "(employeeID=$st)"
    "(sAMAccountName=$st)"
    "(sn=$st*)"
    "(sn=*$st*)"
    "(givenName=$st*)"
    "(displayName=*$st*)"
    "(cn=*$st*)"
)

if ($stRaw -match '^\S+@\S+\.\S+$') {
    $ldapConditions += "(mail=$st)"
}
elseif ($stRaw -notmatch '\s') {
    $ldapConditions += "(sAMAccountName=$st*)"
    $ldapConditions += "(sAMAccountName=*$st*)"
}

$ldap = "(&(objectCategory=person)(objectClass=user)(|$($ldapConditions -join '')))"

$users = @(
    Get-ADUser -LDAPFilter $ldap `
        -Properties $properties `
        -ResultSetSize $MaxResults `
        -ErrorAction Stop
)



