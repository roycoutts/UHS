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
