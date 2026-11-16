Create a PowerShell 5.1 GUI using XAML/WPF. (Topmost = True)

Create Buttons
- [Add Tasks]
- [Add Users]  
- [Add Clin Loc]
- [Add Prof Loc]  
- [Add SSO]
- [Launch Ivanti]
- [Launch Dr Master]
- [Launch EMOLST]
- [Load EPIC User]
- [Load EMOLST User]
- [Load Dr Master User]
- [Load Ivanti Summary]

  
Tasks (#)  
Users (#)

Button Functions
*Add Tasks*
  Accepts [string] (If value contains a comma then split() and trim() into an [array] of TaskIDs)
  Each Task will contain:
  - TaskID
  - TaskType
  - TaskNote
  - EmolstUserName
  - EmolstAdminRole
  - EmolstClinicalRole
  - EmolstTitle
  - EmolstPrefix
  - EmolstFirstName
  - EmolstMiddleName
  - EmolstLastName
  - EmolstSuffix
  - EmolstStreet
  - EmolstCity
  - EmolstState
  - EmolstZip
  - EmolstPhone
  - EmolstEmail
  - EmolstNPI
  - EmolstProvStateLic
  - EmolstSSOUsername
  - EmolstIdentityProvider
  
*Add Users*
  - Loop through each Task - Accepts [string] (Searched Active Directory for user)  
    $SearchTerm = ''
    $filter = "SamAccountName -eq '{0}' -or CN -eq '{0}' -or Name -eq '{0}' -or DisplayName -eq '{0}' -or EmailAddress -eq '{0}' -or EmployeeID -eq '{0}' -or mail -eq '{0}' -or mailNickname -eq '{0}' -or GivenName -eq '{0}' -or OtherName -eq '{0}' -or MiddleName -eq '{0}' -or sn -eq '{0}' -or surname -eq '{0}' -or UserPrincipalName -eq '{0}'" -f ($SearchTerm -replace "'", "''")
    $users = Get-ADUser -Filter $filter -Properties *

