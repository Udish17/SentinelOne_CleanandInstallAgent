# SentinelOne
The script CleanandInstallAgent.ps1 helps you to remove the SentinelOne Windows Agent and Install it at one execution (even it needs a reboot after removal).
# Pre-Requisistes
1. Copy any SOI.exe version (like SentinelOneInstaller_windows_64bit_v24_1_3_232.exe) to a remote location (to which the endpoints have access) or a local location.
2. From the SentinelOne console on the endpoint run th task 'Confirm Local Upgrade'. Altrnatively, 'Site Wide Authorization' can also be enabled for bulk removal and reinstall.
3. Fetch the 'Passphrase' for the endpoint. 'Uninstall/Master Passphrase' can also be used for bulk removal and reinstall.
# Instructions
1. Download the latest version of the script from the 'Release' section.
2. Copy it to the affected endpoint.
3. Open PowerShell and run the script with various options give below:


