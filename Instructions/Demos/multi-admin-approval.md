# Demo – Multi Admin Approval for a script change (Module 5)


**Duration:** 15 minutes

The trainer shows how Multi Admin Approval (MAA) holds back a change to a protected object until a second administrator approves it – first in the Intune admin center, then from PowerShell with Microsoft Graph. You follow along on the projector and read the steps here afterwards. Access policies are tenant-wide settings, so in the shared tenant only the trainer creates and removes them.

**Roles in this demo:**

| Role | Account | What it does |
|---|---|---|
| Requestor | Trainer account A | Changes the script, submits the request, completes it |
| Approver | Trainer account B, member of the approver group | Approves or rejects the request |

**Why:** A single compromised admin account can push a script to every device. With an access policy for scripts, no change goes live until a second person has looked at it – and that includes changes made by Global Administrators and by automation.

## 1. Prepare (trainer, before the module)

1. **Approver group:** a security group with **direct** members (no nesting, not mail-enabled, not a Microsoft 365 group). The group is assigned as **member group** to an Intune role that holds **Multi Admin Approval → Approval for Multi Admin Approval** and **Read** for the protected object type (for scripts: Device configurations → Read). Without that role assignment, Intune removes the members from the group again.
2. **Demo object:** Intune admin center → Devices → Scripts and remediations → **Platform scripts** → Add → Windows 10 and later. Name `MAA-Demo`, script file with one line `Write-Output "MAA demo"`, no assignment.
3. **Access policy:** Tenant administration → Multi Admin Approval → **Access policies** → Create:

   | Setting | Value |
   |---|---|
   | Name | `MAA-Demo Scripts` |
   | Profile type | **Scripts** |
   | Approvers | the approver group from step 1 |
   | Exclusions | none |

   Enter a business justification and select **Submit for approval**. The access policy itself needs approval: account B approves it under **Received requests**, then account A opens the policy and selects **Complete**.

<!-- Open detail (demo tested by Michael 2026-11-22, runs as written): does the Scripts access policy also cover remediations, or only platform scripts? Learn names "scripts to devices that run Windows" and links platform scripts only. Lab 3.1 creates remediations on Day 3 – the policy is removed in section 5 anyway. -->

## 2. Change the script in the admin center

1. **Account A:** Devices → Scripts and remediations → Platform scripts → `MAA-Demo` → **Properties** → Basics → Edit. Change the description to `Changed in the portal`.
2. On **Review + save**, a **Business justification** field appears – the sign that the object is protected. Enter `Demo: description change` and submit.
3. Tenant administration → Multi Admin Approval → **My requests**: the request shows **Needs approval**. The script itself is still unchanged.
4. **Account B:** Tenant administration → Multi Admin Approval → **Received requests** → select the **Business justification** link. Read what is requested, enter an approver note, select **Approve request**.
5. **Account A:** My requests → the request is **Approved** → select it and choose **Complete**. Status changes to **Completed**, and now the description is changed.

**What to watch:**

- Nobody approves their own request – not even a Global Administrator or Intune Administrator who is in the approver group.
- Intune sends no notification. The requestor has to tell the approver, and the approver has to look.
- While a request for an object is pending, nobody can submit a second request for the same object.
- A request that nobody processes within 3 days expires.

## 3. Change the same script from PowerShell

The Graph scripts of this course write to Intune too (for example `Rename-IntunePolicies.ps1` in Lab 1.2). With an access policy in place, they run into the same approval – delegated or app-only.

1. **Account A**, Windows PowerShell – sign in and find the script:

   ```powershell
   Connect-MgGraph -Scopes DeviceManagementScripts.ReadWrite.All, DeviceManagementRBAC.Read.All -NoWelcome
   $all    = Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri 'https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts'
   $script = $all.value | Where-Object displayName -eq 'MAA-Demo'
   $uri    = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($script.id)"
   $body   = @{ '@odata.type' = '#microsoft.graph.deviceManagementScript'; description = 'Changed from PowerShell' } | ConvertTo-Json
   ```

2. Send the change like any normal script would – without MAA headers. Reading works, writing is refused:

   ```powershell
   try   { Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $body -ContentType 'application/json' }
   catch { $_.ErrorDetails.Message; $_.Exception.Message }
   ```

   The error says that the `x-msft-approval-justification` header is required.

   <!-- Open detail (demo tested by Michael 2026-11-22, runs as written): note the HTTP status you see. Learn names 400 (Graph API article), 403 (What's new) and "header required" in different places; slide 51/52 says 403. -->

3. Send it again with a business justification. The header value must be Base64-encoded:

   ```powershell
   $justification = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('Demo: change from PowerShell'))
   try   { Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $body -ContentType 'application/json' -Headers @{ 'x-msft-approval-justification' = $justification } }
   catch { $err = "$($_.ErrorDetails.Message) $($_.Exception.Message)"; $err }
   $code = [regex]::Match($err, 'x-msft-approval-code:\s*([0-9a-fA-F-]{36})').Groups[1].Value
   $code
   ```

   This time the answer is **HTTP 412 Precondition Failed** with an **approval code**. That is not an error in the usual sense: MAA has created an approval request, and the code identifies it.

4. Check the request status with the code:

   ```powershell
   Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri "https://graph.microsoft.com/beta/deviceManagement/operationApprovalRequests?`$filter=requestId eq '$code'" |
       Select-Object -ExpandProperty value | Select-Object status, requestJustification, requestDateTime
   ```

   Status `needsApproval`. The same request also shows up in the admin center under **My requests**.

5. **Account B** approves it in the admin center (Received requests), exactly as in section 2. An application can never approve – only an interactive admin account.
6. **Account A** runs step 4 again (status `approved`) and sends the **same** request once more, now with the approval code instead of the justification:

   ```powershell
   Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $body -ContentType 'application/json' -Headers @{ 'x-msft-approval-code' = $code }
   (Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri $uri).description
   ```

   The description now reads `Changed from PowerShell`. The resubmit is the Graph equivalent of **Complete** in the portal.

<!-- Open detail (demo tested by Michael 2026-11-22, runs as written): error text format of Invoke-MgGraphRequest on 412 – does $_.ErrorDetails.Message contain the approval code? If not, use $_.Exception.Response.Headers. -->

**What to watch:**

- GET calls are never blocked – only POST, PATCH, PUT and DELETE on protected objects.
- An automation that should work with MAA needs four steps: send with justification, store the approval code, wait for `approved`, resend with the code.
- App-only automation that can't do this yet can be excluded on the **Exclusions** tab of the access policy. The exclusion applies only to app-only calls of that enterprise app – delegated calls stay protected – and adding it needs approval too.

## 4. Find the trail in the audit log

Tenant administration → **Audit logs**: filter on the last hour and look for the `MAA-Demo` entries. Request, approval and completion are separate entries with the account that did each step – for the portal and for the Graph calls. On Day 3, the Intune change audit workbook reads the same data.

## 5. Reset after the demo

1. **Account A:** Tenant administration → Multi Admin Approval → Access policies → `MAA-Demo Scripts` → **Delete**, with a business justification. Removing an access policy also needs approval.
2. **Account B:** Received requests → approve the deletion.
3. **Account A:** My requests → **Complete**. Access policies is empty again.
4. Delete the script `MAA-Demo` (no approval needed once the policy is gone).

**Note:** Never create an access policy for the **Role** profile type before the approver group's role assignment is in place. That policy protects the role assignments MAA itself needs, and Learn describes the resulting deadlock and how to get out of it (delete the Role access policy, wait 3–5 minutes, fix the role assignment).

**Sources:** Learn – Use access policies to require multi admin approval; Learn – Use Multi Admin Approval with the Microsoft Graph API; checked 2026-11-21.
