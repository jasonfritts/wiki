# Azure AD B2C Phone Based Audit Logs

1. Navigate to Azure AD B2C tenant on https://portal.azure.com
2. Navigate to Azure AD B2C blade -> Audit Logs  . See [Accessing Azure AD B2C Audit Logs](https://learn.microsoft.com/en-us/azure/active-directory-b2c/view-audit-logs#view-audit-logs-in-the-azure-portal)
3. Update log filter to see phone-based MFA logs such as `Activity = Verify phone number`

   <img width="1700" height="896" alt="image" src="https://github.com/user-attachments/assets/5a720f5a-d4ff-4e17-8619-24674bab3019" />

4. Open the audit log details to confirm the Phone Number Country code and Client IP Address

   <img width="2191" height="1229" alt="image" src="https://github.com/user-attachments/assets/b555ef03-21c5-48a7-aa6a-d59ce8931706" />

6. Other activities to inspect are `Verify email address` to check the email addresses being utilized

   <img width="1992" height="1026" alt="image" src="https://github.com/user-attachments/assets/f38a3c55-7aca-4964-9155-22c64b4a90ee" />


5. If you are [sending your Azure AD B2C audit logs to a Log Analytics SIEM](https://learn.microsoft.com/en-us/azure/active-directory-b2c/azure-monitor) you can query these details with a KQL query like

   ```kql
     AuditLogs
     | where TimeGenerated >= ago(90d)
     | where OperationName contains "verify" 
     | extend addtionalDetails = tostring(AdditionalDetails)
     | where addtionalDetails contains "VerificationMethod"
     | extend ad1=extractjson("$.[5].value", tostring(AdditionalDetails))
    | extend ad2 = extractjson("$.[4].value", tostring(AdditionalDetails))
    | extend Method=strcat(ad1, ",", ad2)
    //| where Method contains ("SMS")
    | extend x = indexof(addtionalDetails, '+')
    | extend y = indexof(addtionalDetails, '"', x)
    | extend Phone =  substring(addtionalDetails, x, y - x)
    | extend CountryCode = substring(Phone, 1, 3)
    | project TimeGenerated, OperationName, CountryCode, Method
   ```

   <img width="1323" height="632" alt="image" src="https://github.com/user-attachments/assets/d04331e4-1aff-44a6-9b9a-37fc4444aa37" />

6. You can also use [pre-built Azure AD B2C MFA Workbook](https://learn.microsoft.com/en-us/azure/active-directory-b2c/phone-based-mfa) to analyze MFA usage
  
   <img width="974" height="1004" alt="image" src="https://github.com/user-attachments/assets/c02d8f18-5745-4f39-b410-499cadcb70ea" />

7.  To prevent further unwanted phone-based MFA usage from certain country codes you can update your policy following [Mitigate fraudulent sign-ups for custom policy](https://learn.microsoft.com/en-us/azure/active-directory-b2c/phone-based-mfa#mitigate-fraudulent-sign-ups-for-custom-policy) or [Mitigate fraudulent sign-ups for user flow](https://learn.microsoft.com/en-us/azure/active-directory-b2c/phone-based-mfa#mitigate-fraudulent-sign-ups-for-user-flow)



      

   
