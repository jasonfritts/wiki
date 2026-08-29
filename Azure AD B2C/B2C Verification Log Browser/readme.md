# Browse-B2CVerificationLogs.ps1

A Windows Forms (GUI) PowerShell tool for browsing **Azure AD B2C email and phone verification** audit events through the Microsoft Graph **beta** `auditLogs/directoryAudits` endpoint.

## Screenshot

<!-- Add a screenshot of the tool here -->
![Browse-B2CVerificationLogs GUI](docs/screenshot.png)

## What it does

- Signs you in interactively to a tenant (optionally a specific B2C tenant).
- Queries verification activities and displays them in a sortable grid:
  - **Timestamp (UTC)**, **Activity**, **Status**, **Status Reason**, **Email / Phone Number**, **Correlation ID**.
- Lets you filter the returned rows by a case-insensitive string match on any column.
- Exports the currently displayed rows to CSV.

### Activities covered

| Type  | Activity display names |
|-------|------------------------|
| Email | `Verify email address`, `Send verification email` |
| Phone | `Verify phone number`, `Send SMS to verify phone number`, `Make phone call to verify phone number` |

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+ (the script uses Windows Forms, so run on Windows).
- The Microsoft Graph authentication module:

  ```powershell
  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
  ```

- Permission to consent to the delegated scopes **`AuditLog.Read.All`** and **`Directory.Read.All`**.

## How to use

1. Run the script:

   ```powershell
   .\Browse-B2CVerificationLogs.ps1
   ```

2. (Optional) Enter a **Tenant** (domain or GUID) to target a specific B2C tenant, then click **Sign in**.
3. Under **Query options**:
   - Choose **Email logs** or **Phone logs**.
   - (Optional) Check **Failures only** to return non-success results (`failure` / `timeout`).
   - Pick a **Preset window** (Last 24 hours / 3 days / 7 days) **or** a **Custom range (UTC)**.
4. Click **Query logs**. Progress and result counts appear in the status bar at the bottom.
5. Use **Filter column** + the text box to narrow the displayed rows; **Clear filter** resets the view.
6. Click **Export CSV** to save the currently displayed rows.

## Notes

- All timestamps are shown and filtered in **UTC**. The custom range pickers are interpreted as UTC.
- Graph requests **page** through `@odata.nextLink`, so more than 100 results are retrieved automatically.
- Requests **retry** on `429`, `500`, `503`, and `504`, honoring the `Retry-After` header and otherwise using capped exponential backoff with jitter.
