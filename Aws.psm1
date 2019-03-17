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
                        Add-Member -PassThru -MemberType NoteProperty Definition -Value $taskDefinition
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

Export-ModuleMember -Function *
