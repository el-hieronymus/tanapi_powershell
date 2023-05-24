# Tanium API Test Skript in Powershell

# Konfiguration der API-Verbindung
$TaniumServer = "https://tansrv-01.wonderland.local:44310"
$TaniumUsername = "tanium"
$TaniumPassword = "P4ssw0rd_123"

# Deaktivieren der SSL-Überprüfung
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# Erstellen einer neuen API-Sitzung
$LoginApiUri = "$TaniumServer/api/v2/session/login"
$Body = @{
    username = $TaniumUsername
    password = $TaniumPassword
} | ConvertTo-Json

try {
    $LoginResponse = Invoke-WebRequest -Uri $LoginApiUri -Method Post -ContentType "application/json" -Body $Body
    if ($LoginResponse.StatusCode -eq 200) {
        Write-Host "Die Verbindung zur Tanium API wurde erfolgreich hergestellt!"
        
        # Extract the session token from the login response
        $SessionToken = (ConvertFrom-Json $LoginResponse.Content).data.token
        
        # Call the parse_question API
        $ParseQuestionApiUri = "$TaniumServer/api/v2/parse_question"
        $QuestionBody = @{
            text = "Get Computer Name from all machines"
        } | ConvertTo-Json

        $ParseQuestionResponse = Invoke-WebRequest -Uri $ParseQuestionApiUri -Method Post -ContentType "application/json" -Body $QuestionBody -Headers @{ "Authorization" = "Bearer $SessionToken" }
        
        if ($ParseQuestionResponse.StatusCode -eq 200) {
            Write-Host "Question parsed successfully!"
            $ParsedQuestion = (ConvertFrom-Json $ParseQuestionResponse.Content).data
            Write-Output $ParsedQuestion
        } else {
            Write-Host "Failed to parse the question. Error code:" $ParseQuestionResponse.StatusCode
        }
    }
} catch {
    Write-Host "Es konnte keine Verbindung zur Tanium API hergestellt werden. Fehlercode: " $_.Exception.Response.StatusCode.Value__
}
