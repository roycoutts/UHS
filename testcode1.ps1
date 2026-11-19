Clinical Task Workbench - Phase 4: Reporting & Maintenance
========================================================

CONTENTS
  Clinical_Task_Workbench.ps1       Main workbench (PowerShell 5.1/WPF)
  Update-UHSLocations.ps1          Alias-safe facility refresh helper
  Test-ClinicalTaskWorkbench.ps1   Non-interactive regression checks

INSTALLATION
  1. Back up the working Phase 3 script.
  2. Extract Clinical_Task_Workbench.ps1 and Update-UHSLocations.ps1
     to the same directory.
  3. Run in Windows PowerShell 5.1 (desktop, STA):
     powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Clinical_Task_Workbench.ps1
  4. Restore the existing session at startup as before.

NEW IN PHASE 4
  - Export Report: CSV of active tasks plus TXT completion totals.
  - Audit History: read-only viewer of the most recent 500 audit events.
  - Settings: choose an absolute report output directory.
  - Audit logs: timestamped events with operator, computer, Task ID and
    non-sensitive action label. No complete EMOLST record payload is stored
    in the audit history.
  - Excel/CSV formula injection protection for exported text fields.
  - Existing Phase 1-3 session and Clavier features remain in the script.

LOCAL DATA
  %LOCALAPPDATA%\ClinicalTaskWorkbench\ActiveSession.json
  %LOCALAPPDATA%\ClinicalTaskWorkbench\AuditHistory.jsonl
  %LOCALAPPDATA%\ClinicalTaskWorkbench\Settings.json
  %LOCALAPPDATA%\ClinicalTaskWorkbench\Reports\  (default reports folder)

REGRESSION TESTS (run without launching the GUI)
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-ClinicalTaskWorkbench.ps1

SECURITY / MAINTENANCE
  Reports and session files may contain employee and provider details. Store
  them only on authorized workstations under your organization's retention
  and access-control policies. Audit history is append-only by the application,
  but it is not a tamper-proof or centralized security audit service.

  Report export does not change task records or EMOLST completion status.
  Excel and Clavier workflows still require real-machine validation.
  Audit errors are shown in the main window status strip; review file
  permissions if you see 'AUDIT WRITE FAILED'.

  This release does not yet implement centralized log aggregation, a full
  Undo history, or a modular rewrite. Those remain possible next steps.
