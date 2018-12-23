function Search-LineText
{
  param(
    [Parameter(Mandatory=$true)]
    $location,
    [Parameter(Mandatory=$true)]
    [string[]]
    $searchString,
    [switch]$asObject)
 
  $LineNumberSeparator=","
  Get-Childitem $location -recurse | ForEach-Object{
      if(-not $_.PSIsContainer)
      {
        $found = @(); 
        $searchResult=(select-string $searchString $_); 
        if($null -ne $searchResult)
        {
          $found+=$searchResult
        } 
    
        if( $found.Count -gt 0 ) 
        {
          $linesList= "";
          ( $found| ForEach-Object{$linesList += $LineNumberSeparator + [string]($_.LineNumber)});
          $linesList=$linesList.Trim($LineNumberSeparator);
          if ( -not($asObject) ){
            Write-Host ("$($_.FullName) at lines $linesList")
          }
          else {
            [PSCustomObject]@{FileFullName= $_.FullName; LineNumbers= @($found|ForEach-Object{$_.LineNumber})}
          }
        }
      }
    }
}

function Measure-CharacterCountTillPosition
{
  param($text, $character, $position=-1)

  if($position -gt 0){
    $text = $text.SubString(0,$position)
  }
  Write-Debug $text
  $sucessfulMatches = [regex]::Matches($text, $character)

  ([PSCustomObject]@{
    Count = $sucessfulMatches.Count
    Positions = @($sucessfulMatches | %{ $_.Index } )
  })
}

function Search-TextFiles
{
  param(
    [Parameter(Mandatory=$true)]
    $location,
    [Parameter(Mandatory=$true)]
    [string]
    $pattern,
    [switch]$asObject)
 
  Get-Childitem $location -recurse | ForEach-Object{
      if(-not $_.PSIsContainer)
      {
        $file = $_
        $found = @();
        $fileContent = [IO.File]::ReadAllText($file.FullName)
        $match=[regex]::Match($fileContent, $pattern)
        if($match.Success)
        {
          $lines = $fileContent.Split("`n")
          $newlines = Measure-CharacterCountTillPosition $fileContent "`n"
          $sucessfulMatches=[regex]::Matches($fileContent, $pattern)
          $details= @( $sucessfulMatches | ForEach-Object{
            $match = $_
            $fileIndex=$match.Index            
            $linesBefore = @($newlines.Positions | Where-Object{$_ -lt $fileIndex})
            $indexOfLineBefore = ([int]  ($linesBefore| Select-Object -Last 1))
            $indexOfStartOfLine=$indexOfLineBefore+1
            if($indexOfLineBefore -le 0){
              $indexOfStartOfLine=0
            }
            $start = [PSCustomObject]@{
              LineNumber = $linesBefore.Count + 1
              LineIndex = $fileIndex-$indexOfStartOfLine
              FileIndex = $fileIndex
            }
            $fileIndex=$match.Index+$match.Length
            $linesBefore = @($newlines.Positions | Where-Object{$_ -lt $fileIndex})
            $indexOfLineBefore = ([int]  ($linesBefore| Select-Object -Last 1))
            $indexOfStartOfLine=$indexOfLineBefore+1
            if($indexOfLineBefore -le 0){
              $indexOfStartOfLine=0
            }                        
            $end = [PSCustomObject]@{
              LineNumber = $linesBefore.Count + 1
              LineIndex = $fileIndex - $indexOfStartOfLine
              FileIndex = $fileIndex
            } 
                       
            [PSCustomObject]@{ Start=$start; End=$end; Length=$match.Length; Lines= $lines[($start.LineNumber-1)..($end.LineNumber-1)] }
          })
          Write-Host "Found in $($file.FullName)"
          $details | ForEach-Object{ 
            $match = $_
            Write-Host "# at position $($match.Start.FileIndex) `n"
            Write-Pretty $_ $lines 3
            Write-Host "`n"
          }
          
          $found+= [PSCustomObject]@{ File = $file; Matches = $details }
        } 
    
        if( $found.Count -gt 0 ) 
        {
          if ( -not($asObject) ){
            Write-Host $found.File.FullName
          }
          else {
            $found    
          }
        }
      }
    }
}

function Write-Pretty
{
  param(
    $match,
    $lines,
    $pad = 0
  )

  if ( $pad -gt 0 -and $match.Start.LineNumber -ne 1 ){
    $padStartLineIndex = ($match.Start.LineNumber-1)-$pad
    if( $padStartLineIndex -lt 0 ){
      $padStartLineIndex = 0
    }
    $beforePadLines = $lines[$padStartLineIndex..($match.Start.LineNumber-2)]
    $lineNumber=$padStartLineIndex+1
    $beforePadLines | ForEach-Object{ 
      $line=$_; Write-Host "$lineNumber     $line" 
      $lineNumber++
    }
  }


  if ( $match.Start.LineNumber -eq $match.End.LineNumber ){
    $line = $match.Lines[0]
    $firstBlock = $line.SubString(0,$match.Start.LineIndex)
    $secondBlock = $line.SubString($match.Start.LineIndex, $match.End.LineIndex-$match.Start.LineIndex)
    $thirdBlock = ''
    if ( $match.End.LineIndex+1 -lt ($line.Length-1)){
      $thirdBlock = $line.SubString($match.End.LineIndex, $line.Length-$match.End.LineIndex)
    }

    $lineNumber=$match.Start.LineNumber
    Write-Host "$lineNumber     " -NoNewline
    Write-Host $firstBlock -NoNewline -ForegroundColor White 
    Write-Host $secondBlock -NoNewline -ForegroundColor Black -BackgroundColor Gray
    Write-Host $thirdBlock -NoNewline -ForegroundColor White 
    Write-Host ''
    if ( $pad -gt 0 ){
      $padEndLineIndex = ($match.End.LineNumber-1)+$pad
      if( $padEndLineIndex -gt ($lines.Length-1) ){
        $padEndLineIndex = $lines.Length-1
      }
      $lineNumber=($match.End.LineNumber+1)
      $afterPadLines = $lines[$match.End.LineNumber..$padEndLineIndex]
      $afterPadLines | ForEach-Object{ 
        $line=$_
        Write-Host "$lineNumber      $line" 
        $lineNumber++
      }
    }    
    return
  }

  $lineNumber = $match.Start.LineNumber
  $line = $match.Lines[0]
  $firstBlock = $line.SubString(0,$match.Start.LineIndex)
  $secondBlock = $line.SubString($match.Start.LineIndex, $line.Length-$match.Start.LineIndex)
  Write-Host "$lineNumber     " -NoNewline
  Write-Host $firstBlock -NoNewline -ForegroundColor White 
  Write-Host $secondBlock -NoNewline -ForegroundColor Black -BackgroundColor Gray
  Write-Host ''
  $lineNumber++

  if($match.Lines.Length -gt 2){
    foreach($line in $match.Lines[1..($match.lines.Length-2)]){
      Write-Host "$lineNumber     " -NoNewline
      Write-Host $line -NoNewline -ForegroundColor Black -BackgroundColor Gray
      Write-Host ''
      $lineNumber++
    }
  }

  $line = $match.Lines[$match.lines.Length-1]
  $firstBlock = $line.SubString(0,$match.End.LineIndex)
  $secondBlock = $line.SubString($match.End.LineIndex, $line.Length-($match.End.LineIndex+1))
  Write-Host "$lineNumber     " -NoNewline
  Write-Host $firstBlock -NoNewline -ForegroundColor Black -BackgroundColor Gray
  Write-Host $secondBlock -NoNewline -ForegroundColor White 
  Write-Host ''

  if ( $pad -gt 0 ){
    $padEndLineIndex = ($match.End.LineNumber-1)+$pad
    if( $padEndLineIndex -gt ($lines.Length-1) ){
      $padEndLineIndex = $lines.Length-1
    }
    $lineNumber=($match.End.LineNumber+1)
    $afterPadLines = $lines[$match.End.LineNumber..$padEndLineIndex]
    $afterPadLines | ForEach-Object{ 
      $line=$_
      Write-Host "$lineNumber      $line" 
      $lineNumber++
    }
  }

}

Export-ModuleMember -Function *