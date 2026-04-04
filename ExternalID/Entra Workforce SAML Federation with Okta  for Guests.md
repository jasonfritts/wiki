Notes for setting up Entra Workforce SAML Federation w/Okta for Guest Users

# Scenario
[Entra Workforce SAML Direct Federation ](https://learn.microsoft.com/en-us/entra/external-id/direct-federation) is a feature that allows you as a resource tenant Entra workforce admin to direct federate to 3rd party SAML idntity providers for the purposes of inviting users from the 3rd party SAML identity provider via B2B guest invitations to access resources hosted in your tenant.

# Prerequisites
## Entra Workforce Environment
An Entra Workforce tenant is the typical Entra tenant type which is most often used for M365 workloads for your employees.  It is separate from a Entra External ID tenant which is used for public\consumer facing CIAM workloads.

Validate your Entra Workforce Tenant ID and type in Entra Portal


## Okta Environment
For lab environments if you do not have an Okta deveoper account you can sign up for one @ https://developer.okta.com/signup/ , you will now have an admin portal like 'https://integrator-abc123-admin.okta.com/admin' which will act as the 3rd party identity provider in this scenario that you are inviting to your Entra workforce tenant.

# Federation Setup Steps
## Step 1. Create SAML Service Provider App In Okta
1. From your admin portal 'ex. https://integrator-abc123-admin.okta.com/admin' browse to Apps
2. Create a new SAML app with following properties
   
    * single sign-on url = `https://login.microsoftonline.com/login.srf`
    * audience = `https://login.microsoftonline.com/<entra workforce tenant guid/`
    * Name ID format = `Persistent`
    * App Username = `Email`
      
3. On the SAML app create an attribute statement with

    * Name = `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress`
    * Value Rule = `user.profile.email`

4. Once your app is created, review it's properties and locate the metadata URL it should look something like `https://integrator-abc123.okta.com/app/exk11ms6j76iX90B9698/sso/saml/metadata` , open this in your browser and copy\paste it's contents to notepad + save it locally to your desktop as `metadata.xml`  from the metadata you should also note the following properties examples for later

    * entityID = `http://www.okta.com/exk11ms6j76iX90B9698`
    * SAML:2.0:bindings:HTTP-POST Location = `https://integrator-abc123.okta.com/app/integrator-8411327_appname_1/exk11ms6j76iX90B9698/sso/saml`
    * X509Certificate = `long base64 encoded certificate that contains spaces`
  
5. For testing you should create a Okta directory user\person with an email for example `test.user@contoso.com` with a password.

6. Finally you should assign your test user to your Okta SAML app so the user is allowed to utilize the federation

## Step 2. Configuring the Entra Workforce SAML Federation


