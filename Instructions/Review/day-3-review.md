# Review – Day 3

For the end of the course or for later: think each question through before you open the answer. There is rarely one right sentence; the answer shows the reasoning behind it.

<details markdown="1">
<summary><strong>1. A manager asks: "Can't we just use a remediation to make sure BitLocker is on, and drop the compliance policy?" What do you lose?</strong></summary>

A remediation changes the device, but nothing reads its result – Conditional Access can't block a device because a remediation failed. Compliance changes nothing on the device, but its state feeds Conditional Access. So the remediation fixes what it can, and compliance makes sure a device that still isn't fixed can't reach company data. Many settings need both: detect, enforce, prove. (Lab 3.1)

</details>

<details markdown="1">
<summary><strong>2. Your custom compliance script reads a registry value. A user with local admin rights changes that value. What does this tell you about the limits of compliance – and of device query?</strong></summary>

Both report what the device says. Whoever controls the device can make it say something else. Compliance and device query are good for detecting drift and mistakes, not for proving the absence of a determined local admin. That is one more reason to keep users out of the local Administrators group (EPM instead) and to combine compliance with signals the user can't change, such as Defender for Endpoint risk. (Labs 3.1, 3.4)

</details>

<details markdown="1">
<summary><strong>3. You answered the same compliance question with a Graph export, the Data Warehouse in Power BI and the dashboard. When would you pick which?</strong></summary>

**Graph export:** current state, any report Intune offers, easy to automate in a script – good for "what is the situation right now?" and for lists you act on. **Data Warehouse:** history and trends, refreshed once a day, and the one Power BI and Excel can read as a data source (Graph can't be a Power Query source) – good for "how has it developed?". **Dashboard:** a quick visual snapshot for people who don't open the admin center. The question decides the tool, not the other way round. (Lab 3.2)

</details>

<details markdown="1">
<summary><strong>4. You publish your Power BI report and share it with your manager. Your manager sees all devices, although they have no Intune role. Why, and is that a problem?</strong></summary>

The report refreshes with the publisher's credentials. Viewers see what the publisher can see, not what their own Intune role would allow. Whether that's a problem depends on the data and the audience – but it's a decision, not a side effect: think about it before you share, and use a dedicated account or row-level security if different audiences need different views. (Power BI demo)

</details>

<details markdown="1">
<summary><strong>5. Intune has no software metering, but you still found unused licenses. How – and what are the blind spots of that number?</strong></summary>

Defender for Endpoint records every process start, so a KQL query counts how many devices and users start a licensed app. The blind spots: it counts launches, not minutes of use; it sees only devices onboarded to Defender for Endpoint; it looks back only 30 days; and new events can take a while to arrive. "Not started in 30 days" is a strong hint to talk to the user, not proof to take the license away overnight. (Lab 3.3)

</details>

<details markdown="1">
<summary><strong>6. The metering script counted users but showed no user names by default. Why is that a sensible default?</strong></summary>

For a license decision you need numbers, not names. User names in a usage report are personal data, and a list of "who uses which app how often" quickly turns into performance monitoring – a works council and data protection topic in many companies. Show names only when there is a reason and the agreement for it. (Lab 3.3)

</details>

<details markdown="1">
<summary><strong>7. The comparison of Intune and Entra ID found devices that exist in only one of them. How can that happen, and why can't the admin center show it to you?</strong></summary>

Intune and Entra ID keep separate device objects. A device deleted in Intune can stay in Entra ID, a device removed in Entra ID can stay in Intune, and a re-enrolled or reinstalled device gets new objects while the old ones remain. Each admin center shows only its own list – only a comparison of both lists shows the orphans and stale objects. (Lab 3.3)

</details>

<details markdown="1">
<summary><strong>8. Device query for a single device answered your registry question in seconds. The multi-device query could not. Why the difference?</strong></summary>

Single device query asks the device live, through a push notification – it can read anything the query language offers, but the device must be online. Device query for multiple devices doesn't ask devices; it searches data that was collected earlier, and for Windows only what a properties catalog policy collects. A registry value you never told the policy to collect simply isn't there. Live and precise for one, collected and limited for many. (Lab 3.4)

</details>

<details markdown="1">
<summary><strong>9. A support engineer asks: "Why should I use device query when I can just start a Remote Help session?" Give them two good reasons.</strong></summary>

Device query doesn't interrupt the user – no session request, no screen sharing, no waiting for the user to accept. And it answers in seconds for facts like "is the service running?", "which version is installed?", "is the value set?". Remote Help remains the tool when you have to see or do something on the screen. (Lab 3.4)

</details>

<details markdown="1">
<summary><strong>10. On the Linux VM, your custom compliance script couldn't read a value that needs root. Why is it built that way, and how does that change what you check on Linux?</strong></summary>

Linux discovery scripts run in the signed-in user's context, not as root. So compliance on Linux can only check what a normal user can see. Checks that need root have to be designed around that – for example by checking a result that is readable by everyone, or by leaving them to other tools. (Lab 3.5)

</details>

<details markdown="1">
<summary><strong>11. After an update of the Microsoft Identity Broker, a Linux device suddenly no longer receives a policy that is assigned to a group. What happened?</strong></summary>

From broker version 2.0.2, Intune re-enrolls the device with new Intune and Entra device IDs. Anything that refers to the old device ID – a static group membership, a filter or a script that uses the ID – no longer matches. Dynamic groups evaluate the new device object again; static memberships and anything else that names the old ID have to be fixed. (Lab 3.5)

</details>

<details markdown="1">
<summary><strong>12. Looking back at all three days: which tasks did you do with a script that you used to do by clicking – and which would you still rather click?</strong></summary>

There is no single answer. A rule of thumb from the course: script what you do **often**, what has to be **the same every time** or what needs a **before/after proof** (packaging, bulk renames, reports, compliance checks). Click what you do once and need to understand first. And everything you click in the admin center is a Graph request you can look up with F12 when it turns into a routine. (All days)

</details>
