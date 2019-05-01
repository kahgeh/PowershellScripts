function Start-NewGitBranchRetainingSomeFiles {
    param(
        [Parameter(Mandatory = $true)]
        $branchName
    )
    
    if ( $null -eq $projectFilesToSave ) {
        Write-Information "projectFilesToSave is not defined globally, setting it to empty hashtable"
        $projectFilesToSave = @{ }
    }

    $tmpFolder = $env:TEMP
    if ( [string]::IsNullOrEmpty($TEMP) ) {
        $homePath = Resolve-Path '~/'
        $tmpFolder = Join-Path $homePath 'Documents/tmp'
    }
	
    if ( -not ( Test-Path $tmpFolder ) ) {
        New-Item $tmpFolder -ItemType Directory | Out-Null
    }
    $tmpPath = Join-Path $tmpFolder ([Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory  $tmpPath | Out-Null
    try {
        $currentFolder = Get-Item ( Resolve-Path ./)
        $projectName = $currentFolder.Name
		
        # save
        if ( $projectFilesToSave.ContainsKey($projectName) ) {
            $filesToSave = $projectFilesToSave[$projectName]
            $filesToSave | % {
                $fileToSave = $_
                $fileToSaveFullName = Join-Path $currentFolder.FullName $fileToSave
                $destinationFullName = ( Join-Path $tmpPath $fileToSave )
                $destinationFolderFullName = ([IO.FileInfo]$destinationFullName).Directory.FullName
                if (!(Test-Path $destinationFolderFullName)) { New-Item $destinationFolderFullName -Type Directory | Out-Null }
                Copy-Item  -Recurse -Force $fileToSaveFullName ( Join-Path $tmpPath $fileToSave )
                Write-Host "Saved $fileToSaveFullName"
            }	
        }

        Start-NewGitBranch $branchName

        # restore
        if ( $projectFilesToSave.ContainsKey($projectName) ) {
            Copy-Item "$tmpPath/*" $currentFolder.FullName -Recurse -Force
            Write-Host 'Restored files'
        }		
    }
    finally {
        Remove-Item -recurse -force $tmpPath
    }
	
}

function Start-NewGitBranch {
    param(
        [Parameter(Mandatory = $true)]
        $branchName
    )
    git checkout master
    git reset --hard
    git branch -a | % { $_.trim() } | where { $_ -notlike 'remotes/*' -and $_ -notlike '*master' } | % { git branch -d $_ --force }
    git pull
    $newBranchList = git branch -a | % { $_.trim() }
    if ( $newBranchList -contains "remotes/origin/$branchName" ) {
        git checkout $branchName
        git branch --set-upstream-to="origin/$branchName"		
        return
    }

    git branch $branchName
    git checkout $branchName
}

function Get-FileChanges {
    param(
        $commitId,
        $baseCommitId
    )
    # get all the file changes in commitId but not in baseCommitId
    git diff --name-only $commitId $baseCommitId | cat
}

function Get-CommitsSince {
    param(
        $commitId
    )
    $commitIds = git log "$($commitId)..HEAD" --oneline --pretty=format:'%H' | cat
    $commitIds
}

function Set-RemoteRepository {
    param(
        $remoteRepoUrl,
        $branchName = 'master'
    )
    git remote add origin $remoteRepoUrl
    git remote -v
    git push -u origin $branchName
}

function Remove-Tag {
    param(
        [Parameter(Mandatory)]
        $tag,
        [Parameter(Mandatory)]
        $repo,        
        [Parameter(Mandatory)]
        $org,
        [Parameter(Mandatory)]
        $token,
        $baseUri = "api.github.com"
    )
    $basicToken = ConvertTo-Base64 "$($org):$($token)"
    $headers = @{
        "Content-Type"  = "application/json"
        "Accept"        = "application/vnd.github.v3.full+json"
        "Authorization" = "Basic $basicToken"        
    }

    $tagUrl = "https://$($baseUri)/repos/$($org)/$($repo)/git/refs/tags/$($tag)"
    Invoke-WebRequest -Method DELETE -Headers $headers -Uri $tagUrl
}

Export-ModuleMember -Function * 