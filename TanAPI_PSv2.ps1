<#
.SYNOPSIS

# A script to interact with the Tanium API.

.DESCRIPTION
This script demonstrates how to use PowerShell to interact with the Tanium API for authentication,
asking questions, and invoking actions.
This script connects to the Tanium API and executes a question.
The question results are then displayed in the console.
You can also run an action by specifying the action name, target filters, and action parameters.
The action is then invoked to deploy the package to the targeted machines.

.PARAMETER server
The Tanium server URL.

.PARAMETER loginStyle
The login style - use 'pwd' for password-based authentication, 'api_token' for token-based authentication.

.PARAMETER username
The username for Tanium API authentication.

.PARAMETER password
The password for Tanium API authentication. If using token-based authentication, this should be the API token.

.PARAMETER question
The question to ask the Tanium server.


.EXAMPLE
.\Invoke-TaniumAction.ps1 -server "https://taniumserver" -loginStyle "pwd" -username "username" -password "password" -question "Get Computer Name from all machines"

.NOTES
Tanium API Test Skript in Powershell 
Andreas El Maghraby
last updated: 2021-03-18
andy.elmaghraby@tanium.com

#>

# Read command-line arguments
param (
    [Parameter(Mandatory=$true)]
    [string]$server,
    [Parameter(Mandatory=$true)]
    [ValidateSet('pwd', 'api_token')]
    [string]$loginStyle,
    [Parameter(Mandatory=$true)]
    [string]$username,
    [Parameter(Mandatory=$true)]
    [string]$password,
    [Parameter(Mandatory=$true)]
    [string]$question
)

# Action Parameters (Example Custom Tagging Action)
# Replace values with the appropriate values for your action, target filters, and action parameters.

$ActionName = "Add Custom Tag"
$PackageId = 73
$TargetFilters = "name:Windows"
$SourceId = 73
$ActionGroupId = 3
$ExpireSeconds = 3600
$TargetGroupId = 1

$PackageParameters = @(
    @{
        key = "$1"
        value = "TestTagForWindowsEndpoints"
    },
    @{
        key = "$2"
        value = "TestTagForLinuxEndpoints"
    }
)

# Check the login style
if ($loginStyle -eq 'pwd') {
    $TaniumUsername = $username
    $TaniumPassword = $password
} else {
    $APIToken = $password
}


# Global Default variables
# Konfiguration der API-Verbindung
$APIToken = "token-90bf430c8663bed8e28199e13002f578ba41d36588432bd69e7a727647"
$LoginStyle = "api_token"
$TaniumServer = "https://taas-test.cloud.tanium.com"
$TaniumUsername = "andy.elmaghraby@tanium.com"
$TaniumPassword = ""
$TaniumQuestion = "Get Computer Name from all machines"


# Deaktivieren der SSL-Überprüfung
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# This function connects to the Tanium API and returns a token.
# It can be used to establish a connection to the Tanium API.

function Login-User-Pwd {
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

function Login-User-Token {
    param (
        $Server,
        $Token
    )

    $LoginApiUri = "$Server/api/v2/session/login"
    $Body = @{
        token = $APIToken
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

# Create an action. An action specifies a package to deploy, the machines to target, and the deploy schedule.
# The action is then invoked to deploy the package to the targeted machines.
# For general information on actions, refer to the Tanium actions overview in the Tanium Core Platform
# User Guide at: https://docs.tanium.com/platform_user/platform_user/actions_overview.html

function Invoke-TaniumAction {
    param (
        $Server,
        $Token,
        $ActionName,
        $SourceId,
        $ActionGroupId,
        $ExpireSeconds,
        $TargetGroupId,
        $PackageParameters
    )

    $ActionsApiUri = "$Server/api/v2/actions"
    $ActionBody = @{
        action_group = @{
            id = $ActionGroupId
        }
        package_spec = @{
            source_id = $SourceId
            parameters = $PackageParameters
        }
        name = $ActionName
        expire_seconds = $ExpireSeconds
        target_group = @{
            id = $TargetGroupId
        }
    } | ConvertTo-Json

    $ActionsResponse = Invoke-WebRequest -Uri $ActionsApiUri -Method Post -ContentType "application/json" -Body $ActionBody -Headers @{ "session" = $Token }

    if ($ActionsResponse.StatusCode -eq 200) {
        Write-Host "Action invoked successfully!"
        return (ConvertFrom-Json $ActionsResponse.Content).data
    } else {
        Write-Host "Failed to invoke action. Error code:" $ActionsResponse.StatusCode
    }
}


# main script starts here ###############################################################################



# Main script
function Main {
      # Parse question
      $ParsedQuestion = Parse-Question -Server $TaniumServer -Token $SessionToken -QuestionText $QuestionText
    
      # Get questions
      $Questions = Get-Questions -Server $TaniumServer -Token $SessionToken -ParsedQuestion $ParsedQuestion
      $QuestionId = $Questions.id
      
      # Wait for the question to finish
      Start-Sleep -Seconds 5
  
      # Get result data
      $ResultData = Get-ResultData -Server $TaniumServer -Token $SessionToken -SessionId $QuestionId
      Write-Output $ResultData
  
      # Invoke action
      $ActionResponse = Invoke-TaniumAction -Server $TaniumServer -Token $SessionToken -ActionName $ActionName -SourceId $SourceId -ActionGroupId $ActionGroupId -ExpireSeconds $ExpireSeconds -TargetGroupId $TargetGroupId -PackageParameters $PackageParameters
      Write-Output $ActionResponse 
}

# Call Main function ###############################################################################

if ($LoginStyle -eq "pwd") {
    $SessionToken = Login-User-Pwd -Server $TaniumServer -Username $TaniumUsername -Password $TaniumPassword
    if ($SessionToken) {
        Main
    }
} else {
    $SessionToken = Login-User-Token -Server $TaniumServer -APIToken $APIToken
    if ($SessionToken) {
        Main
    }
}
