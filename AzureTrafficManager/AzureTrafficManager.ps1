# Get inputs.
$resourceGroupName = Get-VstsInput -Name ResourceGroupName -Require
$profileName = Get-VstsInput -Name ProfileName -Require
$endpointName = Get-VstsInput -Name EndpointName -Require
$operationName = Get-VstsInput -Name EndpointOperations -Require
$motionValue = Get-VstsInput -Name MotionValue

Trace-VstsEnteringInvocation $MyInvocation

try {
    # Initialize the Azure authentication.
    Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers
    Initialize-Azure

    # Import the loc strings.
    Import-VstsLocStrings -LiteralPath $PSScriptRoot/Task.json

    $profile = Get-AzureRmTrafficManagerProfile -Name $profileName -ResourceGroupName $resourceGroupName
    $priorityList= $profile.Endpoints | Sort-Object -Property Priority
    $endpoint = Get-AzureRmTrafficManagerEndpoint -Name $endpointName -ProfileName $profileName -ResourceGroupName $resourceGroupName -Type AzureEndpoints

    switch ($operationName){
        "Enable" {
            Write-Host "Enabling $endpointName"
            Enable-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endpoint
        }

        "Disable" {
            Write-Host "Disabling $endpointName"
            Disable-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endpoint -Force
        }
        
        "Promote" {
            $newPriority = $endpoint.Priority - $motionValue

            if ($newPriority -eq 0) {
                Write-Host "##vso[task.logissue type=error;]0 is not a valid value for an Endpoint priority."
            }

            while ($priorityList.Priority.Contains($newPriority)) {
                if ($newPriority = 1) {
                    Write-Host "##vso[task.logissue type=error;]You cannot promote this endpoint ($endpointName) any further because there is already an Endpoint with a priority of 1."
                } else {
                    Write-Host "##vso[task.logissue type=warning;]The selected priority value is already in use for another Endpoint."
                    $newPriority--
                    Write-Host "##vso[task.logissue type=warning;]Automatically scaling down $endpointName to $newPriority"
                }
            }

            $endpoint.Priority = $newPriority
            Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endpoint
        }
        
        "Demote" {
            $newPriority = $endpoint.Priority + $motionValue

            if ($newPriority -gt 1000) {
                Write-Host "##vso[task.logissue type=error;]Values over 1000 are not valid values for an Endpoint priority."
            }

            while ($priorityList.Priority.Contains($newPriority)) {
                if ($newPriority = 1000) {
                    Write-Host "##vso[task.logissue type=error;]You cannot demote this endpoint ($endpointName) any further because there is already an Endpoint with a priority of 1000."
                } else {
                    Write-Host "##vso[task.logissue type=warning;]The selected priority value is already in use for another Endpoint."
                    $newPriority++
                    Write-Host "##vso[task.logissue type=warning;]Automatically scaling up $endpointName to $newPriority"
                }
            }

            $endpoint.Priority = $newPriority
            Set-AzureRmTrafficManagerEndpoint -TrafficManagerEndpoint $endpoint
        }
    }
} catch {
    Write-Host "##vso[task.complete result=Failed;]Execution error." 
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
