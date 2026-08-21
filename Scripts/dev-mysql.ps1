# dev-mysql.ps1
# Sets environment variables for running the app or EF Core CLI commands
# against the local MySQL container, from the HOST machine (not inside Docker).
#
# Usage:
#   . .\dev-mysql.ps1        (note the leading dot-space — "dot sourcing")
#
# Dot-sourcing is required, not optional — running it as `.\dev-mysql.ps1`
# (without the leading dot) sets the env vars in a child process that exits
# immediately, so your actual terminal session never sees them. Dot-sourcing
# runs the script in your CURRENT session instead.
#
# After running this, you can freely use:
#   dotnet ef migrations list
#   dotnet ef migrations add <Name>
#   dotnet ef database update
#
# This sets Server=localhost, which is correct for commands run directly on
# your machine. It is NOT correct for docker compose — that uses Server=mysql
# instead, since containers reach each other by service name, not localhost.
# Compose already gets its own values from .env, so this script doesn't touch
# docker compose at all.
 
$env:Storage__Provider = "MySql"
$env:ConnectionStrings__Default = "Server=localhost;Port=3306;Database=employeedirectory;User=appuser;Password=devpassword123;"
 
Write-Host "MySQL dev mode active for this terminal session:" -ForegroundColor Green
Write-Host "  Storage__Provider = $env:Storage__Provider"
Write-Host "  ConnectionStrings__Default = $env:ConnectionStrings__Default"
Write-Host ""
Write-Host "Reminder: this is for HOST commands (dotnet ef ...), not docker compose." -ForegroundColor Yellow
Write-Host "Make sure the MySQL container is running: docker compose --profile mysql up -d mysql"