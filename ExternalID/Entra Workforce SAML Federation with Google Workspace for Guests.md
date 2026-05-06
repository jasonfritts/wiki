# Entra Workforce SAML Federation with Google Workspace for Guests Lab

Notes for setting up Entra Workforce SAML Federation w/Google Workspace aka GSuite for Guest Users

# Scenario
[Entra Workforce SAML Direct Federation ](https://learn.microsoft.com/en-us/entra/external-id/direct-federation) is a feature that allows you as a resource tenant Entra workforce admin to direct federate to 3rd party SAML identity providers for the purposes of inviting users from the 3rd party SAML identity provider via B2B guest invitations to access resources hosted in your tenant.  This would typically be done if the invited users do not have their own Entra work\school accounts in their own Entra tenant.

<mark>**Important:** This feature requires you as resource tenant administrator to <a href="https://learn.microsoft.com/en-us/entra/external-id/add-users-administrator">manually create B2B invited user objects</a> in your tenant.  During [invite redemption, which is also required](https://learn.microsoft.com/en-us/entra/external-id/redemption-experience) the invited user will utilize this federation configuration for authentication.  If you do not want users to have to redeem invites, AND you own the Google Workspace environment you should instead look into setting up an internal federation config see: [Configure Internal Federation Between Google Workspace and Entra ID](https://learn.microsoft.com/en-us/education/windows/configure-aad-google-trust) + [Google user provisioning](https://support.google.com/a/answer/7365072) and [Google SAML federation](https://support.google.com/a/answer/6363817) </mark>

# Prerequisites
## Entra Workforce Environment
An Entra Workforce tenant is the typical Entra tenant type which is most often used for M365 workloads for your employees.  It is separate from a Entra External ID tenant which is used for public\consumer facing CIAM workloads.

Validate your Entra Workforce Tenant ID and type in Entra Portal


## Google Workspace Environment
For lab environments if you do not have an Google Workspace account you can sign up for a free Cloud Identity Free Plan @ https://workspace.google.com/gcpidentity/signup?sku=identitybasic , you will now have an admin portal like `https://admin.google.com` which will act as the 3rd party identity provider in this scenario that you are inviting to your Entra workforce tenant.

# Federation Setup Steps
## Step 1. Create SAML Service Provider App In Google Workspace
1. From your admin portal ex. `https://admin.google.con` browse to Apps -> Web and mobile apps
2. Create a new SAML app via Add App -> Add custom SAML app 
3. When given the option, Download Metadata XML file `GoogleIDPMetadata.xml` to your desktop and note down the `SSO URL` + `Entity ID` + `Certificate` contents to a Notepad for later
4. Continue with app creation and update the following properties

    * ACS URL = `https://login.microsoftonline.com/login.srf`
       * NOTE: If you are federating with an Entra External ID (not workforce) the ACS URL should be `https://<tenantID>.ciamlogin.com/login.srf` instead 
    * Entity Id = `https://login.microsoftonline.com/<tenant guid>/`  
    * Name ID Format = `Persistent`
    * Name ID = `Basic Information > Primary email`

      <img width="1717" height="828" alt="image" src="https://github.com/user-attachments/assets/8df28a2a-a86b-4dec-a618-96e6cef8d131" />


      
4. On the Attribute mapping step configure the following attribute mapping

    * Google Directory attributes = `Primary email`
    * App attributes = `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`
  
      <img width="1117" height="431" alt="image" src="https://github.com/user-attachments/assets/60a7f5e4-a7f5-4a34-93ab-d21a5ed3aacf" />



5. Once the new App has been saved, open it's properties and ensure that it has been enabled and under `User access` it shows `ON for everyone` otherwise update it to be enabled for all users which you wish to utilize the federation.  Additionally confirm the ACS \ Entity ID \ and Attribute mapping matches what it should per previous steps

     <img width="1521" height="582" alt="image" src="https://github.com/user-attachments/assets/47b10e20-3011-4780-926b-c5df9d74b379" />


     
  
7. For testing you should create a Google workspace directory user\person with an email for example `test.user@contoso.com` with a password from Admin menu -> Directory -> Users -> Add new user and ensure you populate the Primary email address

    <img width="1105" height="535" alt="image" src="https://github.com/user-attachments/assets/cc4d7fab-566a-4f48-8e09-be7de697aff2" />

  
8. Finally if you did not enable the app for ALL users you should enable the user to use the SAML federation app

## Step 2. Configuring the Entra Workforce SAML Federation

1. From your Entra Workforce tenant, In Entra Portal -> External identities -> Identity providers -> New Custom SAML Identity Provider

	1. Domain = the test domain suffix your Google Workspace user is using ex. `contoso.com`
	2. Use parse metadata file option and upload the `GoogleIDPMetadata.xml` file you downloaded from Google Workspace App configuration
   3. The XML should be parsed to locate the following details 
	     * Issuer Uri = `https://accounts.google.com/o/saml2?idpid=abc12345`
	     * Passive auth endpoint = `https://accounts.google.com/o/saml2/idp?idpid=abc12345`
        * Cert = `long based64 cert value`
          	     
		* Metadata url = leave this blank, Google Workspace doesnt seem to publish their metadata via URL only download

  4. Save the config and you may get an error like: `Invalid domain contoso.com. Domain should match the passiveSignInUri. Otherwise, please add the passiveSignInUri in the domain DNS TXT record like this DirectFedAuthUrl=https://accounts.google.com/o/saml2/idp?idpid=abc12345` which is expected if using Google Workspace lab and you will need to follow the error recommendation and create a DNS TXT record in your domain's namespace 

  5. In domain DNS registrar for `contoso.com` add a TXT record 

	DirectFedAuthUrl=https://accounts.google.com/o/saml2/idp?idpid=abc12345

  6. Now go back to Entra steps and save identity provider where you should not have same error

## Step 3. Testing 

1. From Entra Workforce tenant, you must create a new invited user from Users blade -> Invite User and invite the Google Workspace user's email address `test.user@contoso.com`

     <img width="590" height="293" alt="image" src="https://github.com/user-attachments/assets/8d338d2a-5b26-4c81-bd6f-83b3cf0578f9" />

	 <img width="917" height="464" alt="image" src="https://github.com/user-attachments/assets/82587771-b18b-4d8a-91bf-ef027ae00cef" />




3. Once invited user has been created in Entra workforce you can test the federation by opening your incognito browser and visiting `http://portal.azure.com/resourcetenant.onmicrosoft.com` where `resourcetenant.onmicrosoft.com` is the tenant name or guid of the Entra tenant you have invited this guest to.
4. Type in the `test.user@contoso.com` user you invited \ created in Google Workspace 

   <img width="455" height="346" alt="image" src="https://github.com/user-attachments/assets/a851b825-2a21-493f-ae15-5c52748dc513" />

   And confirm when hitting next you are redirected to your Google Workspace sign on-url to sign in:

   <img width="904" height="446" alt="image" src="https://github.com/user-attachments/assets/662deeed-5838-41bb-b5dc-7d63a602fa1e" />


5. Signing in succesfully with your Google Workspace account for first time should prompt you to Accept the conditions of the invitation and subsequently sign you into the target URL of the resource tenant

   <img width="750" height="586" alt="image" src="https://github.com/user-attachments/assets/62f2a17e-b1a2-42e1-82e1-190cf0f34185" />

# Troubleshooting

## **AADSTS5000819**: SAML Assertion is invalid. Email address claim is missing or does not match domain from an external realm. or<br> **AADSTS500089:**  SAML 2.0 assertion validation failed: SAML token is invalid.

This error indicates that the external SAML IDP sent Entra a SAML token but it either

1. The IDP sent the `SAMLResponse` to the incorrect destination\AssertionConsumerURL for an Entra Workforce or Entra External ID tenant:


   |**Resource Tenant Type**  | **Expected Target\AssertionConsumerUrl**  |
   |--|--|
   |Entra Workforce Resource Tenant  | `https://login.microsoftonline.com/login.srf`  |
   |Entra External ID Tenant  | `https://<tenantID>.ciamlogin.com/login.srf`  |

    

1. The IDP's `SAMLResponse` did not contain the required attribute statements as per [Required SAML 2.0 attributes and claims](https://learn.microsoft.com/en-us/entra/external-id/direct-federation#required-saml-20-attributes-and-claims) 
2. The `SAMLResponse` contains a `AudienceRestriction` element that does not match [the required audience format](https://learn.microsoft.com/en-us/entra/external-id/direct-federation#to-configure-a-saml-20-identity-provider) of `https://login.microsoftonline.com/<tenant ID>/` where <tenant ID> is the resource tenant ID. 
3. `SAMLResponse` Had the required claims, but the domain name of the email address was not found as a Entra SAML federated identity provider.


**Troubleshooting**: 

1. Capture a Fiddler or HAR of the sign in failure
2. Locate the `SAMLResponse` value sent to `https://login.microsoftonline.com/login.srf` for Entra Workforce Tenants OR `https://<tenantID>.ciamlogin.com/login.srf` for Entra External ID tenants (any other target URL is not valid) and decode it using Fiddler Text Wizard:

   <img width="1067" height="723" alt="image" src="https://github.com/user-attachments/assets/72ff693a-2350-41a5-a818-dd733aa2cdd0" />


5. Confirm the presence of these **four** required attributes
   * For a Entra Workforce Resource Tenant :
       ```xml
         <saml2p:Response Destination="https://login.microsoftonline.com/<resource tenant guid>/saml2"
       ```
     For a Entra External ID Resource Tenant :
        ```xml
         <saml2p:Response Destination="https://<tenantID>.ciamlogin.com/login.srf"
   * ```xml
       <saml2:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent">email@domain.com</saml2:NameID>
     ```
   * ```xml 
      <saml2:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress">
         <saml2:AttributeValue xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="xsd:anyType">email@domain.com</saml2:AttributeValue>
      </saml2:Attribute>
   * ```xml
     <saml2:AudienceRestriction>
        <saml2:Audience>https://login.microsoftonline.com/<resource tenant guid>/</saml2:Audience>
     </saml2:AudienceRestriction>
     ```

6. If these exact attribute names are not found in the SAMLResponse, then the SAML IDP needs to be reconfigured to emit them.  These steps will be different depending on the IDP.
7. Additionally the value of `email@domain.com` in the SAML response should be found in the resource tenant as an invited external guest.

## **AADSTS5000811**: Unable to verify token signature. The signing key identifier does not match any valid registered keys.
This error indicates that the SAML Response from the external IDP was signed using a certificate which Entra cannot find in the Entra External ID SAML Federation configuration.  To diagnose this issue
1. Capture a Fiddler trace of the SAML sign in
2. Locate the SAMLResponse sent to `login.microsoftonline.com/login.srf` and decode it using Fiddler Text Wizard (right click -> Send to Text Wizard ) to find the **X509Certificate** value

   <img width="1263" height="659" alt="image" src="https://github.com/user-attachments/assets/3b040efc-24bb-475a-b800-a07b11a58545" />

3. This value in-between <X509Certificate> value </X509Certificate>is the Base64 Encoded version of the SSL Signing Cert used to sign the SAMLResponse.  You can copy and paste it's contents into a Base64 Certificate decoder Powershell script example below to see it's properties such as start\end date and thumbprint to confirm it matches expected values. 

      ```powershell
      #Update this variable to contain certificate base64 value you wish to convert
      $certraw = "MIIDdDCCAlygAwIBAg....."
      
      #Run to view certificate properties such as start\end dates , thumbprint etc.
      [System.Security.Cryptography.X509Certificates.X509Certificate2]([System.Convert]::FromBase64String($certraw)) | fl *
     ```

3. Now compare this value with the Signing Certificate found in your Graph Explorer (https://aka.ms/ge) -> GET `/directory/federationConfigurations/graph.samlOrWsFedExternalDomainFederation` -> `signingCertificate` value and verify they match.



4. If these certs don't match then you will need to contact SAML IDP for an updated metadata XML and reconfigure Entra SAML Federation to update the Signing Certificate to match.  Reference [How do I update the certificate or configuration details?-](https://learn.microsoft.com/en-us/entra/external-id/direct-federation#how-do-i-update-the-certificate-or-configuration-details)
