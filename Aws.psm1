function Get-ProfileNames {
    $config = Get-Content "$HOME/.aws/config"
    $profileSectionHeaderPattern = [Regex]"\[(\s*profile\s+){0,1}(?<name>[^\s]+)\]"
    $sourcePattern = [Regex]"\s*[S|s]ource_profile\s*=\s*(?<name>[^\s]+)"
    $sectionHeaders = New-Object System.Collections.ArrayList
    $sourceProfileNames = New-Object System.Collections.ArrayList
    $config | 
        ForEach-Object { 
        $profileSectionHeaderMatch = $profileSectionHeaderPattern.Match($_)
        if ( $profileSectionHeaderMatch.Success ) {
            $sectionHeaders.Add($profileSectionHeaderMatch.Groups['name'].Value)|Out-Null;
        }
    
        $sourceMatch = $sourcePattern.Match($_)
        if ($sourceMatch.Success) {
            $sourceProfileName = $sourceMatch.Groups['name'].Value
            if ( $sourceProfileName -notcontains $sourceProfileNames) {
                $sourceProfileNames.Add($sourceProfileName)| Out-Null
            }
        }
    }    
    
    Compare-Object $sectionHeaders $sourceProfileNames |
        Where-Object {$_.SideIndicator -eq '<='} |
        Select-Object -ExpandProperty InputObject    
}

function Use-AwsProfile {
    param(
        [Parameter(Mandatory = $true)]
        $profileName
    )
    Set-AWSCredential -StoredCredentials $profileName
    awsweb env --shell powershell $profileName
    $Cmd = (awsweb env --shell powershell $profileName) | Out-String
    Invoke-Expression $Cmd   
}

function Get-AwsServiceTasks {
    param($serviceName)

    Get-ECSClusterList | ForEach-Object {
        $cluster = (Get-ECSClusterDetail $_).Clusters
        $clusterServices = Get-ECSClusterService -Cluster $cluster.ClusterArn
        $clusterServices| ForEach-Object {
            $services = (Get-ECSService -Service $_ -Cluster $cluster.ClusterName).Services
            if ( $null -ne $serviceName ) {
                $services = @($services| Where-Object {$_.ServiceName.Contains($serviceName)})
            }
            $services | ForEach-Object {
                $service = $_
                $taskArns = Get-ECSTaskList -Cluster $cluster.ClusterName -ServiceName $service.ServiceName
                $taskArns | ForEach-Object {
                    $taskArn = $_    
                    $task = (Get-ECSTaskDetail -Cluster $cluster.ClusterName -Task $taskArn).Tasks
                    $taskDefinition = (Get-ECSTaskDefinitionDetail $task.TaskDefinitionArn).TaskDefinition
                    $ec2Instance = @(Get-ECSContainerInstanceDetail -Cluster $cluster.ClusterArn -ContainerInstance @($task.ContainerInstanceArn)).ContainerInstances 
                    $task | 
                        Add-Member -PassThru -MemberType NoteProperty Cluster -Value $cluster |
                        Add-Member -PassThru -MemberType NoteProperty Service -Value $service |
                        Add-Member -PassThru -MemberType NoteProperty Host -Value $ec2Instance |
                        Add-Member -PassThru -MemberType NoteProperty Definition -Value $taskDefinition
                }
            }
        }
    }
}

function Get-AwsServices {
    param ( 
        $serviceName,
        $clusterName )

    Get-ECSClusterList | ForEach-Object {
        $cluster = (Get-ECSClusterDetail $_).Clusters
        $clusterServices = Get-ECSClusterService -Cluster $cluster.ClusterArn
        if ($null -ne $clusterName) {
            $clusterServices = $clusterServices | Where-Object { $_.ClusterName -eq $clusterName }
        }
        $clusterServices| ForEach-Object {
            $services = (Get-ECSService -Service $_ -Cluster $cluster.ClusterName).Services
            if ( $null -ne $serviceName ) {
                $services = @($services| Where-Object {$_.ServiceName.Contains($serviceName)})
            }
            $services | ForEach-Object {
                $service = $_
                $taskArns = Get-ECSTaskList -Cluster $cluster.ClusterName -ServiceName $service.ServiceName
                $tasks = New-Object System.Collections.ArrayList
                $taskArns | ForEach-Object {
                    $taskArn = $_    
                    $task = (Get-ECSTaskDetail -Cluster $cluster.ClusterName -Task $taskArn).Tasks
                    $taskDefinition = (Get-ECSTaskDefinitionDetail $task.TaskDefinitionArn).TaskDefinition
                    $ec2Instance = @(Get-ECSContainerInstanceDetail -Cluster $cluster.ClusterArn -ContainerInstance @($task.ContainerInstanceArn)).ContainerInstances 
                    $task = $task | 
                        Add-Member -PassThru -MemberType NoteProperty Definition -Value $taskDefinition |
                        Add-Member -PassThru -MemberType NoteProperty Host -Value $ec2Instance
                    $tasks.Add($task)
                }
                $service |
                    Add-Member -PassThru -MemberType NoteProperty Cluster -Value $cluster |
                    Add-Member -PassThru -MemberType NoteProperty Tasks -Value $tasks
            }
        }
    }
}

function Set-AwsServiceTaskDesiredCount {
    param(
        [Parameter(Mandatory = $true)]
        $count,
        $serviceName
    )

    $services = @( Get-AwsServices $serviceName )
    $services | ForEach-Object {
        $service = $_
        Update-ECSService -Service $service.ServiceName -DesiredCount $count -Cluster $service.Cluster.ClusterName
    }
}

function Restart-AwsServiceTask {
    param(
        [Parameter(Mandatory = $true)]
        $serviceNames
    )
    @($serviceNames)|ForEach-Object {
        $serviceName = $_
        Set-AwsServiceTaskDesiredCount -serviceName $serviceName -Count 0
        Set-AwsServiceTaskDesiredCount -serviceName $serviceName -Count 1
    }

}

function ConvertTo-CfnParameters {
    [OutputType([System.Collections.ArrayList])]
    param($parameters = @{})
    $parameterPairs = New-Object System.Collections.ArrayList
    
    if ($null -eq $parameters) {
        return $parameterPairs
    }
    $parameters.GetEnumerator()|ForEach-Object { 
        $parameter = New-Object Amazon.CloudFormation.Model.Parameter
        $parameter.ParameterKey = $_.Key
        $parameter.ParameterValue = $_.Value
        $parameterPairs.Add($parameter) | Out-Null 
    }
    $parameterPairs
}

function Wait-ForCfnCompletion {
    param(
        $stackName,
        $opStartDateTime,
        $awsConfig
    )
    $staleEvents = New-Object System.Collections.ArrayList
    while ($true) {
        try {
            $stack = Get-CFNStack $stackName @awsConfig
            if ($stack.StackStatus -eq "CREATE_COMPLETE" -or $stack.StackStatus -eq "UPDATE_COMPLETE" ) {
                if ($staleEvents.Count -gt 0) {Write-CfnProgress $stackName $staleEvents $opStartDateTime $awsConfig}
                Write-Host "Final status - $($stack.StackStatus)"
                return 0
            }
        
            if ($stack.StackStatus -like "*FAIL*" -or $stack.StackStatus -like "*ROLLBACK*") {
                if ($staleEvents.Count -gt 0) {Write-CfnProgress $stackName $staleEvents $opStartDateTime $awsConfig} 
                Write-Host "Final status - $($stack.StackStatus)"
                return 1
            }
        }
        catch {
            $currentError = $_
            if ($currentError.Exception.Message.Contains('does not exist')) {
                Write-Information 'Stack does not exist detected'
                return 0
            }
            else {
                Write-Error -Message $currentError.Exception.Message -ErrorAction Stop
                return 1
            }     
        }
        
    
        Write-CfnProgress $stackName $staleEvents $opStartDateTime $awsConfig
        Start-Sleep -Seconds 1
    }    
}

function Write-CfnProgress {
    param( 
        $stackName, 
        $staleEvents, 
        [DateTime] $opStartDateTime, 
        $awsConfig)
    
    $stackEvents = @()    
    try {
        $stackEvents = Get-CFNStackEvents -StackName $stackName @awsConfig
    }
    catch {
        if ($currentError.Exception.Message.Contains('does not exist')) {
            Write-Host "Stack $stackName no longer exists"
            return $false
        }
        throw $currentError
    }
    $newEvents = $stackEvents| Where-Object { $_.Timestamp -gt $opStartDateTime -and $staleEvents -notcontains $_.EventId} | Sort-Object -Property Timestamp 

    $newEvents | ForEach-Object {
        $event = $_
        Write-Host "$($event.Timestamp) $($event.ResourceType) $($event.PhysicalResourceId) $($event.ResourceStatus)"    
        $staleEvents.Add( $event.EventId )|Out-Null
    }
    return $true
}

function Update-Stack {
    param(
        $stackName, 
        $templateFilePath,  
        $parameterList, # e.g. key1=value1[comma]key2=value2
        $templateUrl,
        $awsConfig,
        $terminateOnCompletion = $false)
    $parameters = @{}
    if (-not([string]::IsNullOrEmpty($parameterList))) {
        $parameterList = $parameterList.Replace('[comma]', "`n")
        $parameters = ConvertFrom-StringData $parameterList
    }
    
    # - get action ( create-stack or update-stack )
    $action = 'update-stack'
    try {
        $stack = Get-CFNStack $stackName @awsConfig

        if ( $null -eq $stack ) {
            $action = 'create-stack'
        }
    }
    catch {
        $action = 'create-stack'
    }
    
    # - get templatefilepath
    if ([string]::IsNullOrEmpty($templateFilePath) -and [string]::IsNullOrEmpty($templateUrl)) {
        throw "At least templateFilePath or templateUrl need to be specified"
    }
    if ([string]::IsNullOrEmpty($templateFilePath)) {
        $templateFileName = "template.yml"
        Invoke-WebRequest $templateUrl -OutFile "./$templateFileName"
        $templateFilePath = "file://$templateFileName"
    }
    
    # - save all required arguments
    $stackParams = @{ 
        StackName    = $stackName
        TemplateBody = [IO.File]::ReadAllText( $templateFilePath)
        Capability   = @('CAPABILITY_NAMED_IAM')
        ProfileName  = $awsConfig.ProfileName
        Region       = $awsConfig.Region 
    }
    
    # - add parameters argument if any 
    $parametersArguments = ConvertTo-CfnParameters $parameters
    if ($parametersArguments.Length -gt 0) {
        $stackParams.Add('Parameter', $parametersArguments) | Out-Null
    }
    
    $opStartDateTime = [DateTime]::Now
    try {
        if ( $action -eq 'create-stack') {
            Write-Host "Sending request to create stack..."
            New-CFNStack @stackParams 
            Write-Host "Completed sending request to create stack"
        }
        else {
            Write-Host "Sending request to update stack..."
            Update-CFNStack @stackParams
            Write-Host "Completed sending request to update stack"
        }
    }
    catch {
        Write-Host $_.Exception.Message
        if ($err.Exception.Message -like "*No updates are to be performed*") {
            Write-Host "No changes detected"
        }
        return 0    
    }

    Wait-ForCfnCompletion $stackName $opStartDateTime $awsConfig
}

function Get-CfnOutputValue {
    param($name, $stackName, $awsConfig)

    $stack = Get-CFNStack $stackName @awsConfig
    $stack.Outputs | Where-Object {$_.OutputKey -eq $name } |Select-Object -ExpandProperty 'OutputValue'
}

Export-ModuleMember -Function *
