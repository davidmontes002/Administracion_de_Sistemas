function Eliminar-Scope {

    Get-DhcpServerv4Scope

    $scope = Read-Host "Ingrese ScopeID a eliminar"

    Remove-DhcpServerv4Scope -ScopeId $scope -Force

    Write-Host "Scope eliminado."
    Pause
}