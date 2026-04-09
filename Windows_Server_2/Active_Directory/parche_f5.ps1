Get-ADGroup -Filter "Name -like '*eventos*' -or Name -like '*Event Log*'" | Add-ADGroupMember -Members "admin_auditoria"
Get-ADGroup -Filter "Name -like '*directivas de grupo*' -or Name -like '*Policy Creator*'" | Add-ADGroupMember -Members "admin_politicas"
Get-ADGroup -Identity "S-1-5-32-544" | Add-ADGroupMember -Members "admin_storage"
