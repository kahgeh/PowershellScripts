function Get-WorkWeeks
{
  param (
    [DateTime]$start,
    $numberOfWeeks
  )

  $startOfWeek = $start

  1..$numberOfWeeks | ForEach-Object {
    $endOfWeek = $startOfWeek + [TimeSpan]::FromDays(4)

    "$($startOfWeek.ToString("dd/MM"))-$($endOfWeek.ToString("dd/MM"))"
    $startOfWeek = $startOfWeek + [TimeSpan]::FromDays(7)
  }
}

function Get-Sprints
{
  param (
    [DateTime]$start,
    $numberOfSprints,
    $sprintDays
  )

  $startOfSprint = $start

  1..$numberOfSprints | ForEach-Object {
    $endOfSprint = $startOfSprint + [TimeSpan]::FromDays($sprintDays-1)

    "$($startOfSprint.ToString("dd/MM"))-$($endOfSprint.ToString("dd/MM"))"
    $startOfSprint = $startOfSprint + [TimeSpan]::FromDays($sprintDays)
  }
}

function Get-WeeklyRoster
{
  param (
    [DateTime]$start,
    $numberOfWeeks,
    $names,
    $delimiter=","
  )

  $weeks = @(Get-WorkWeeks $start $numberOfWeeks)
  $onDutyPersonCount = $names.length

  $nameIndex = 0
  $count = 0
  $weeks | ForEach-Object{
    $week = $_
    "$week$delimiter$($names[$nameIndex])"
    $count++
    $nameIndex = $count % $onDutyPersonCount
  }
}

function Get-SprintRoster
{
  param (
    [DateTime]$start,
    $numberOfSprints,
    $names,
    $delimiter=","
  )

  $sprints = @(Get-Sprints $start $numberOfSprints)
  $onDutyPersonCount = $names.length

  $nameIndex = 0
  $count = 0
  $sprints | ForEach-Object{
    $sprint = $_
    "$sprint$delimiter$($names[$nameIndex])"
    $count++
    $nameIndex = $count % $onDutyPersonCount
  }
}

Export-ModuleMember -Function * -Alias *
