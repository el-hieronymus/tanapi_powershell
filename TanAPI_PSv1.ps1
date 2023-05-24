# Tanium API Test Skript in Powershell
# 
# Andreas El Maghraby
# 2021-03-18
# andy.elmaghraby@tanium.com
#
# usage:
# .\tanium_script.ps1 "server" "username" "password" "question"
# e.g.
# .\tanium_script.ps1 "your_username" "your_password" "Get Computer Name from all machines"
#

# Konfiguration der API-Verbindung
$TaniumServer = "https://tansrv-01.wonderland.local:44310"
$TaniumUsername = "tanium"
$TaniumPassword = ""

# Deaktivieren der SSL-Überprüfung
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

function Login-Tanium {
    param (
        $Server,
        $Username,
        $Password
    )

    $LoginApiUri = "$Server/api/v2/session/login"
    $Body = @{
        username = $Username
        password = $Password
    } | ConvertTo-Json

    try {
        $LoginResponse = Invoke-WebRequest -Uri $LoginApiUri -Method Post -ContentType "application/json" -Body $Body
        if ($LoginResponse.StatusCode -eq 200) {
            Write-Host "Die Verbindung zur Tanium API wurde erfolgreich hergestellt!"
            return (ConvertFrom-Json $LoginResponse.Content).data.token
        }
    } catch {
        Write-Host "Es konnte keine Verbindung zur Tanium API hergestellt werden. Fehlercode: " $_.Exception.Response.StatusCode.Value__
    }
}

function Parse-Question {
    param (
        $Server,
        $Token,
        $QuestionText
    )

    $ParseQuestionApiUri = "$Server/api/v2/parse_question"
    $QuestionBody = @{
        text = $QuestionText
    } | ConvertTo-Json

    $ParseQuestionResponse = Invoke-WebRequest -Uri $ParseQuestionApiUri -Method Post -ContentType "application/json" -Body $QuestionBody -Headers @{ "Authorization" = "Bearer $Token" }

    if ($ParseQuestionResponse.StatusCode -eq 200) {
        Write-Host "Question parsed successfully!"
        return (ConvertFrom-Json $ParseQuestionResponse.Content).data
    } else {
        Write-Host "Failed to parse the question. Error code:" $ParseQuestionResponse.StatusCode
    }
}

function Get-Questions {
    param (
        $Server,
        $Token,
        $ParsedQuestion
    )

    $QuestionsApiUri = "$Server/api/v2/questions"
    $QuestionsBody = @{
        question_text = $ParsedQuestion.question_text
        select_clauses = $ParsedQuestion.select_clauses
        from_clause = $ParsedQuestion.from_clause
        where_clause = $ParsedQuestion.where_clause
    } | ConvertTo-Json

    $QuestionsResponse = Invoke-WebRequest -Uri $QuestionsApiUri -Method Post -ContentType "application/json" -Body $QuestionsBody -Headers @{ "Authorization" = "Bearer $Token" }

    if ($QuestionsResponse.StatusCode -eq 200) {
        Write-Host "Questions retrieved successfully!"
        return (ConvertFrom-Json $QuestionsResponse.Content).data
    } else {
        Write-Host "Failed to retrieve questions. Error code:" $QuestionsResponse.StatusCode
    }
}

function Get-ResultData {
    param (
        $Server,
        $Token,
        $SessionId
    )

    $ResultDataApiUri = "$Server/api/v2/result_data/question/$SessionId?json_pretty_print=1"
    $ResultDataResponse = Invoke-WebRequest -Uri $ResultDataApiUri -Method Get -Headers @{ "Authorization" = "Bearer $Token" }

    if ($ResultDataResponse.StatusCode -eq 200) {
        Write-Host "Result data retrieved successfully!"
        return (ConvertFrom-Json $ResultDataResponse.Content).data
    } else {
        Write-Host "Failed to retrieve result data. Error code:" $ResultDataResponse.StatusCode
    }
}

# Read command-line arguments
$TaniumServer = $args[0]
$TaniumUsername = $args[1]
$TaniumPassword = $args[2]
$QuestionText = $args[3]

# Main script
$SessionToken = Login-Tanium -Server $TaniumServer -Username $TaniumUsername -Password $TaniumPassword
if ($SessionToken) {
    $ParsedQuestion = Parse-Question -Server $TaniumServer -Token $SessionToken -QuestionText $QuestionText
    $Questions = Get-Questions -Server $TaniumServer -Token $SessionToken -ParsedQuestion $ParsedQuestion
    $QuestionId = $Questions.id
    Start-Sleep -Seconds 5
    $ResultData = Get-ResultData -Server $TaniumServer -Token $SessionToken -SessionId $QuestionId
    Write-Output $ResultData
}

