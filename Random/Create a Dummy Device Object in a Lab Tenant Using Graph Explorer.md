# Create a Dummy Test Device Object Using Graph Explorer

## Overview

This tutorial demonstrates how to use [Microsoft Graph Explorer](https://aka.ms/ge) to create a dummy Microsoft Entra device object in a lab tenant.

> [!WARNING]
> Perform this procedure only in a lab or test tenant. A `POST` request changes directory data in the tenant you are signed in to.

## Prerequisites

- Access to a Microsoft Entra lab or test tenant
- An account authorized to create device objects
- Permission to consent to the Microsoft Graph permissions required by the request

## Step 1: Open Graph Explorer

Open [Microsoft Graph Explorer](https://aka.ms/ge).

## Step 2: Sign in to the lab tenant

1. Select **Sign in**.
2. Authenticate with an account in the lab tenant.
3. Verify that Graph Explorer shows the intended test tenant before continuing.

## Step 3: Configure the request

Set the request fields as follows:

- **HTTP method:** `POST`
- **API version:** `beta`
- **Request URL:**

```http
https://graph.microsoft.com/beta/devices
```

## Step 4: Add the request body

Open the **Request body** tab and paste the following JSON:

```json
{
  "accountEnabled": true,
  "displayName": "Lab-Test-Device-01",
  "deviceId": "e4d64d8c-1234-4c8e-9b3e-1a2b3c4d5e6f",
  "operatingSystem": "Windows",
  "operatingSystemVersion": "10.0.19045.0",
  "alternativeSecurityIds": [
    {
      "type": 2,
      "identityProvider": null,
      "key": "WDUwOTo8U0hBMS1QVUtFWT5hYmNkMTIzNDU2Nzg5MGFiY2RlZjEyMzQ1Njc4OTBhYmNkZWY="
    }
  ]
}
```

> [!NOTE]
> Use a unique `deviceId` value if you repeat this test.

## Step 5: Consent to the required permissions

1. Open the **Modify permissions** tab.
2. Review the permissions Graph Explorer identifies for the request.
3. Consent to the least-privileged permission that allows the operation.
4. If administrative consent is required, use an authorized lab administrator account.

## Step 6: Run the request

Select **Run query**.

A successful create operation should return an HTTP `201 Created` response and the properties of the new device object.

## Step 7: Verify the device object

Run the following request to locate the device by its `deviceId`:

```http
GET https://graph.microsoft.com/beta/devices?$filter=deviceId eq 'e4d64d8c-1234-4c8e-9b3e-1a2b3c4d5e6f'
```

You can also search by display name:

```http
GET https://graph.microsoft.com/beta/devices?$filter=displayName eq 'Lab-Test-Device-01'
```

## Request-body properties

| Property | Purpose |
|---|---|
| `accountEnabled` | Indicates whether the device object is enabled. |
| `displayName` | Friendly name shown for the device object. |
| `deviceId` | Device identifier associated with the object. |
| `operatingSystem` | Operating system associated with the device. |
| `operatingSystemVersion` | Operating-system version associated with the device. |
| `alternativeSecurityIds` | Alternative security identifiers associated with the device. |

## Cleanup

### 1. Retrieve the directory object ID

```http
GET https://graph.microsoft.com/beta/devices?$filter=displayName eq 'Lab-Test-Device-01'
```

Copy the returned device object's `id` property. This is the directory object ID, not the `deviceId` property.

### 2. Delete the test device

```http
DELETE https://graph.microsoft.com/beta/devices/{object-id}
```

Example:

```http
DELETE https://graph.microsoft.com/beta/devices/11111111-2222-3333-4444-555555555555
```

A successful deletion should return HTTP `204 No Content`.

## Troubleshooting

### Insufficient privileges

Example error code:

```text
Authorization_RequestDenied
```

Review **Modify permissions**, consent to the required permission, and run the request again.

### Object conflict

Use a unique `deviceId`, or remove the existing test object before retrying.

### Invalid request body

If Graph returns `Request_BadRequest`:

- Validate the JSON syntax.
- Confirm that `accountEnabled` is a Boolean value, not a string.
- Confirm that `alternativeSecurityIds` is a JSON array.
- Confirm that `deviceId` is a valid GUID.

## References

- [Open Microsoft Graph Explorer](https://aka.ms/ge)
- [Use Graph Explorer to try Microsoft Graph APIs](https://learn.microsoft.com/en-us/graph/graph-explorer/graph-explorer-overview)
- [Work with Graph Explorer](https://learn.microsoft.com/en-us/graph/graph-explorer/graph-explorer-features)
