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
