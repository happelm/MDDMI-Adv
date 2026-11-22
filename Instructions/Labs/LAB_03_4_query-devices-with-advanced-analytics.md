---
title: 'Lab 3.4 – Query devices with Advanced Analytics'
lab:
    title: 'Lab 3.4 – Query devices with Advanced Analytics'
    module: 'Day 3 – Insights, automation, platforms'
---

# Lab 3.4 – Query devices with Advanced Analytics

**Estimated time:** 35 minutes

**Goal:** Answer support questions about CL3 live with device query, and then ask the same kind of question across all course devices with device query for multiple devices.

**Why:** Many tickets need one fact from the device: is a service running, is a registry value set, which version of an app is installed. Device query gets that fact in seconds without a remote session. Device query for multiple devices answers inventory questions for the whole fleet from collected data.

| | Device query (single device) | Device query for multiple devices |
|---|---|---|
| Where | Devices → Windows → device → Monitor → **Device query** | Devices → **Device query** |
| Data | Live from the device, while it is online | Collected inventory, refreshed once a day |
| Windows needs | Corporate-owned, Entra joined or hybrid joined | A properties catalog policy – in the course tenant `Win Hardware Inventory`, assigned to all devices |
| Entities | Also registry, files, services, processes, events | Hardware, OS, encryption, TPM – no registry, files or services |

Both use Kusto Query Language (KQL). Write strings in single quotes: some operators, for example `contains` and `startswith`, accept only single quotes.

## Part A – Live on CL3

1. Intune admin center → Devices → Windows → **CL3-yourname** → Monitor → **Device query**. Run each query below and read the result.
2. Is the Intune Management Extension running, and how does it start?

   ```kusto
   WindowsService
   | where ServiceName == 'IntuneManagementExtension'
   | project ServiceName, DisplayName, State, StartMode, WindowsUserAccount
   ```

3. Is the registry value from Lab 3.1 set? Replace `etcX` with your prefix before you run the query:

   ```kusto
   WindowsRegistry('HKEY_LOCAL_MACHINE\\SOFTWARE\\etcX\\Lab')
   | project RegistryKey, ValueName, ValueType, ValueData
   ```

   You see `Enforced` with the data `1`.
4. Which version of VLC from Lab 1.5 is installed?

   ```kusto
   FileInfo('C:\\Program Files\\VideoLAN\\VLC\\vlc.exe')
   | project FileName, FileVersion, ProductVersion, LastModifiedDateTime
   ```

5. Which local accounts exist? Find the account that Windows LAPS manages from Lab 2.2:

   ```kusto
   LocalUserAccount
   | project Username, UserDescription, WindowsSid
   ```

6. Which processes use the most memory, and who runs them?

   ```kusto
   Process
   | top 5 by WorkingSetSizeBytes
   | project ProcessName, WindowsUserAccount, WorkingSetMB = WorkingSetSizeBytes / 1048576
   ```

7. Which device certificates does CL3 have, and when do they expire? Find the SCEP certificate from Lab 2.4:

   ```kusto
   Certificate
   | where IsCa == false
   | project CommonName, Issuer, ValidToDateTime, StoreName
   ```

8. What did the Application log record today? Read the **Level** column:

    ```kusto
    WindowsEvent('Application', 1d)
    | project LoggedDateTime, Level, ProviderName, EventId, Message
    | take 10
    ```

## Part B – Cached across all course devices

9. Intune admin center → Devices → **Device query**. Expand the entity list on the left: compare it with Part A. Registry, files, services, processes and events are missing.
10. Which Windows versions run in the course?

    ```kusto
    OsVersion
    | summarize Devices = count() by OsName, OsVersion
    ```

11. How much memory do the devices have?

    ```kusto
    MemoryInfo
    | project Device, PhysicalMemoryGB = PhysicalMemoryTotalBytes / (1024 * 1024 * 1024)
    | order by PhysicalMemoryGB asc
    ```

12. Which devices have a volume without BitLocker protection, and which drive is it?

    ```kusto
    EncryptableVolume
    | where ProtectionStatus != 'PROTECTED'
    | join LogicalDrive on Device
    ```

13. Which CPU architectures and TPM versions are in use?

    ```kusto
    Cpu
    | summarize Devices = count() by Architecture
    ```

    ```kusto
    Tpm
    | summarize Devices = count() by Manufacturer, SpecVersion
    ```

### Checkpoint

- [ ] The registry value from Lab 3.1 read from CL3 with device query
- [ ] VLC version and the LAPS-managed account read from CL3 without a remote session
- [ ] At least three multi-device queries run
- [ ] You can explain why the multi-device query can't answer the registry question from step 3

**Note:** Device query needs an Advanced Analytics license (included in Microsoft 365 E3 and E5 since July 2026, see Module 1) and the Intune permission **Managed devices → Query** for single devices. Single device query reaches the device through Windows push notifications, so CL3 must be online. You can send up to 15 queries per minute.

**Note:** Device query for multiple devices returns up to 50,000 rows and allows 10 queries per minute and 1,000 per month in the tenant. For Windows, data appears only after a properties catalog policy has collected it – the first collection can take up to 24 hours. iOS/iPadOS, Android and macOS corporate devices are collected without a policy.

**Note:** A user with local admin rights on a device can change client-side data such as the registry or the OS version. Device query reports what the device says.

Sources: [Device query](https://learn.microsoft.com/intune/advanced-analytics/device-query) · [Device query for multiple devices](https://learn.microsoft.com/intune/advanced-analytics/device-query-multiple-devices) · [Intune data platform schema](https://learn.microsoft.com/intune/advanced-analytics/ref-data-platform-schema) · [Properties catalog](https://learn.microsoft.com/intune/device-configuration/collect-device-properties)

<!-- Sources checked 2026-11-22: Learn Device query (entities, single quotes for contains/startswith, 15 queries/min, remote device actions from results, admin users can change client data), Device query for multiple devices (Devices > Device query, export 50,000, add all items to a group, properties catalog for Windows), Intune data platform schema (property names used above, WindowsRegistry/FileInfo/WindowsEvent syntax). -->
<!-- Course tenant: properties catalog policy "Win Hardware Inventory" already applies to all devices, so inventory data is there (Michael 2026-11-22). Participant roles already include Managed devices/Query (Lokka 2026-11-22). -->
<!-- Michael 2026-11-22: WindowsRegistry with double backslashes works. WindowsEvent needs the log name in quotes ('Application'; Learn sample without quotes fails); filter Level == 'ERROR' returned nothing on CL3, so the step shows the Level column instead. -->
<!-- Tested by Michael 2026-11-22: all queries run as written. -->
