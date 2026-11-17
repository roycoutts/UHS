


               Task ID: (Required Field) 
                  Type: (Required Field) 
				        - ("Clinical","Provider") <-- value determined by user selecting "Clinical Location" or "Provider Location"
              Username: (Required Field) 
			            - value mapped from "EMOLST User"
            Admin Role: (Required Field) 
			            - "No Admin Access" <-- Hard Coded Value 
						- NOTE: "QA/QI", "HIPAA Entity Admin", "HIPAA Entity Auditor" can only be done as a manual override
         Clinical Role: (Required Field) 
		                - If (Type = "Clinical"), Then value = "Read but no write access to Forms" 
		                - If (Type = "Provider"), Then I use (Get-ProviderCategory) to determine clinical role
						- NOTE: "Form Access, Non-Signer", "No Patient Access" can only be done as a manual override
                 Title: (Required Field) 
				        - If (Type = "Clinical"), value mapped from Active Directory "Title"
				        - If (Type = "Provider"), value mapped from Dr Master "Title"
                Prefix: (Not Required)
				        NOTE: Can be manually entered
            First Name: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Active Directory "GivenName"
						- If (Type = "Provider"), value mapped from Dr Master "First Name"
           Middle Name: (Not Required)
			            - If (Type = "Clinical"), value mapped from Active Directory "middleName" if blank check "OtherName"
						- If (Type = "Provider"), value mapped from Dr Master "Middle Name"		   
             Last Name: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Active Directory "sn" if blank check "Surname"
						- If (Type = "Provider"), value mapped from Dr Master "Last Name"		
                Suffix: (Not Required)
			            - If (Type = "Clinical"), value is blank but can be manually entered
						- If (Type = "Provider"), value mapped from Dr Master "Suffix"					
                Street: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Clinical Location "Address"
						- If (Type = "Provider"), value mapped from Dr Master "Address1 and Address2 using 'comma' and 'space' concatenation if needed"						
                  City: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Clinical Location "City"
						- If (Type = "Provider"), value mapped from Dr Master "City"	
                 State: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Clinical Location "State"
						- If (Type = "Provider"), value mapped from Dr Master "State"
                   Zip: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Clinical Location "Zip"
						- If (Type = "Provider"), value mapped from Dr Master "Zip" 
          Phone Number: (Required Field) 
			            - If (Type = "Clinical"), value mapped from Clinical Location "Phone"
						- If (Type = "Provider"), value mapped from Dr Master "Phone"
         Email Address: (Required Field) 
			            - value mapped from Active Directory "EmailAddress" if blank check "mail"
          Provider NPI: (Required Field If (Type = "Provider")) 
		                - If (Type = "Provider"), value mapped from Dr Master "NPI"
Provider State License: (Required Field If (Type = "Provider")) 
                        - If (Type = "Provider"), value mapped from Dr Master "StateLic"
          SSO Username: (Required Field) 
		                - value mapped from "SSO"
     Identity Provider: (Required Field) 
	                    - "United Health Services - Epic" <-- Hard Coded Value 
	 
	 
Language=English
Size=637,439,0,0
Columns=35,20,15,10
Sorting=0

Shortcut=`
Code=192
Text=[][][][{Copy,e26414}][][][][Ctrl + V][][][][Tab][][][][Tab][][][][][][][{Copy,No Admin Access}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Read but no write access to Forms}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Applications Analyst II}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,*prefix*}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Roy}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Lee}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Coutts}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,*suffix*}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,33-57 Harrison St}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Johnson City}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,NY}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,13790}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,607-763-6000}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,Roy.Coutts@NYUHS.org}][][][][Ctrl + V][][][][Tab][][][][Tab][][][][][][][{Copy,*npi*}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,*lic*}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,*sso*}][][][][Ctrl + V][][][][Tab][][][][][][][{Copy,United Health Services - Epic}][][][][Ctrl + V][][][][Tab][][][]
Usages=0
-
Shortcut=Ctrl + F1
Code=624
Command=\\radcalcqa3\ITShare\SCRIPTS\Launcher.exe
Directory=\\radcalcqa3\ITShare\SCRIPTS
Window=Normal
Usages=0
-
Shortcut=Ctrl + F2
Code=625
Command=\\radcalcqa3\ITShare\SCRIPTS\eMolst-Data-Collector.exe
Directory=\\radcalcqa3\ITShare\SCRIPTS
Window=Normal
Usages=0
-
	 
	 
	 
	 
	 
	 
	 
function Get-ProviderCategory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Credential
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Credential)) {
            return 'All Others'
        }

        switch ($Credential.Trim()) {
            # --- MD/DO Category (9) ---
            { $_ -in @(
                'DDS, MD',
                'DMD, MD',
                'DO',
                'MD',
                'MD, DDS',
                'MD, DMD',
                'MD, DO',
                'MD, PHD',
                'PHD, MD'
            ) } {
                'MD/DO Form Signer'
                break
            }

            # --- NP Category (31) ---
            { $_ -in @(
                'ACNP',
                'AGNP',
                'ANP',
                'ANP, NPP',
                'ANP-BC',
                'ANP-C',
                'AOCNP',
                'CNM, FNP',
                'CNM, NP',
                'CNNP',
                'CNP',
                'CPNP',
                'CRNP',
                'CRNP, PHD',
                'DNP- FNP-C',
                'FNP',
                'FNP, NPP',
                'FNP-BC',
                'FNP-C',
                'GNP',
                'NNP',
                'NP',
                'NPC',
                'NPP',
                'OGNP',
                'ONP',
                'PMHNP',
                'PNP',
                'PNP, NPP',
                'WHNP',
                'WHNP, AOCNP'
            ) } {
                'NP Form Signer'
                break
            }

            # --- PA Category (4) ---
            { $_ -in @(
                'PA',
                'PA-C',
                'RPA',
                'RPA-C'
            ) } {
                'PA Form Signer'
                break
            }

            # --- All Others Category ---
            default {
                'Read but no write access to Forms'
                break
            }
        }
    }
}
	 
	 
	 
