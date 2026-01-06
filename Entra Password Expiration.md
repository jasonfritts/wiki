# Entra Password Expiration

There is often some confusion about how password expiration works in Entra for users.  Writing down some notes to remember

1. Every user can have have a custom passwordPolicies attribute applied

   Ref: https://learn.microsoft.com/en-us/graph/api/user-update?view=graph-rest-1.0&tabs=http#example-3-update-the-passwordprofile-of-a-user-and-reset-their-password:~:text=sensitive%20actions.-,passwordPolicies,-String

   Possible values include: **DisablePasswordExpiration** 

2. If no per-user passwordPolicies is found on user, they default to their domain suffix's passwordValidityPeriodInDays

   Ref: https://learn.microsoft.com/en-us/graph/api/resources/domain?view=graph-rest-1.0#:~:text=days%20is%20used.-,passwordValidityPeriodInDays,-Int32

   'passwordValidityPeriodInDays' can be an integer value representing the number of days a user's password is good for if there is no per-user passwordPolicies applied to that user.

3. This means that today you can't have user@contoso.com's password expire in 90 days and user2@contoso.com's password expire in 180 days.  You can only configure password expiration at the **per-user** level to NEVER expire, or you can configure **all user's from contoso.com** to expire in X number of days.  There is no granularity option available.

   If you want ALL users from contoso.com to never expire, your options are either

      a. Set contoso.com's passwordValidityPeriodInDays to something extrodinarily large like 2 billion days
   
      b. Manually update every user under contoso.com's per-user passwordPolicies to `DisablePasswordExpiration`

## Simple example 1 (Cloud Only Users)

This user has no custom passwordPolicies set

Perform this query in Graph Explorer (https://aka.ms/ge)

* `GET https://graph.microsoft.com/beta/users/bob@contoso.com?$select=userPrincipalName,passwordPolicies,passwordProfile,lastPasswordChangeDateTime`

   ```json
   {
    "@odata.context": "https://graph.microsoft.com/beta/$metadata#users(userPrincipalName,passwordPolicies,passwordProfile,lastPasswordChangeDateTime)/$entity",
    "userPrincipalName": "bob@contoso.com",
    "passwordPolicies": null,
    "lastPasswordChangeDateTime": "2024-06-20T20:20:19Z",
    "id": "abc18d86-c6b4-49f1-99fd-7acde81cd703",
    "passwordProfile": null
   }
   ```

So it defaults to it's domain "contoso.com"'s' passwordValidityPeriodInDays as `"passwordPolicies": null`.  You can then find it's domain policy in Graph Explorer as well with this query

* `GET https://graph.microsoft.com/beta/domains/contoso.co?$select=passwordValidityPeriodInDays`

   ```json
   {
    "@odata.context": "https://graph.microsoft.com/beta/$metadata#domains(passwordValidityPeriodInDays)/$entity",
    "passwordValidityPeriodInDays": 2147483647
   }
   ```

Which is set to **5.8 million years**, so essentially it is set to NEVER expire.  Meaning all users under "contoso.com" domain don't have a password expiration.

## Simple example 2 (Hybrid Sync Users)

If I look at another user in Graph.  One that is synchned from on-premises using Entra Connect + Password Hash Sync , I find the following:

* `GET https://graph.microsoft.com/beta/users/bill@contoso.com?$select=userPrincipalName,passwordPolicies,passwordProfile,lastPasswordChangeDateTime,onPremisesSyncEnabled`

   ```json
   {
    "@odata.context": "https://graph.microsoft.com/beta/$metadata#users(userPrincipalName,passwordPolicies,passwordProfile,lastPasswordChangeDateTime,onPremisesSyncEnabled)/$entity",
    "userPrincipalName": "bill@contoso.com",
    "passwordPolicies": "DisablePasswordExpiration",
    "lastPasswordChangeDateTime": "2025-08-26T15:42:37Z",
    "onPremisesSyncEnabled": true,
    "id": "abcf7605-9e5b-4791-bc03-193084aaa495",
    "passwordProfile": null
   }
   ```

Bill has `"onPremisesSyncEnabled": true` and `"passwordPolicies": "DisablePasswordExpiration"` .  So his per-user passwordPolicy for cloud account is set to never expire.  Regardless of what his domain's password expiration policy is.  His password will not expire, not even in 6 million years.
