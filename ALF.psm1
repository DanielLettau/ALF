class ALFObjectSearchResult {
    [string]$Name
    [string]$Property
    [string]$Value
    [string]$Pattern
    [bool]$ColorizeProperty
    [bool]$ColorizeValue
    ALFObjectSearchResult ([String]$Name,[string]$Property,[string]$Value,[string]$Pattern,[bool]$ColorizeProperty,[bool]$ColorizeValue)
    {
        $this.Name = $Name
        $this.Property = $Property
        $this.Value = $Value
        $this.Pattern = $Pattern
        $this.ColorizeProperty = $ColorizeProperty
        $this.ColorizeValue = $ColorizeValue
    } 
}
if (((get-typedata ALFObjectSearchResult).defaultdisplaypropertyset.referencedproperties | Sort-Object) -join "" -ne "NamePropertyValue")  {
    Update-TypeData -TypeName ALFObjectSearchResult -DefaultDisplayPropertySet 'Name','Property','Value'
}
function crawl ($obj,[array]$path) {
    if ($path.Count -le $script:maxdepth) {
        if ($null -ne $obj) {
            
            if ($obj.psobject.methods.OverloadDefinitions -contains "string ToString()") {
                @{
                    PropertyPath = $path -join "."
                    Propertyvalue = $obj.tostring()
                }
            } 
        }
        $members = $obj.psobject.Properties -ne "Length"
        foreach ($membername in $members.name) {
            if ($null -ne $obj.$membername) {
                if ($obj.$membername.psobject.typenames -match "System.SByte\[\]") {
                    crawl ($obj.$membername -join " ") ($path + $membername)                
                } elseif ($obj.$membername.psobject.typenames -match "array") {
                    for ($i=0;$i -lt $obj.$membername.count;$i++) {
                        crawl $obj.$membername[$i] ($path + ($membername + "[$($i)]"))
                    }
                } else {
                    crawl $obj.$membername ($path + $membername)
                }
            }
        }
    }
}

class ALFOneLineText {
    [string]$Text
    hidden [int] $Length
    ALFOneLineText ([String] $Text, [int] $Length)
    {
        $this.Text = $Text
        $this.Length = $Length
    }
    ALFOneLineText ([String] $Text)
    {
        $this.Text = $Text
    } 
    [string] Shorten([int]$Length)
    {
        $this.Length = $Length
        if ($this.Length -gt $this.Text.Length) {
            return $this.Text
        } else {
            return ($this.Text.Substring(0,($this.Length -3)) + '...')
        }
    }
    [string] Shorten()
    {
        if ($this.Length -eq 0) {
            $this.Length = $global:Host.UI.RawUI.BufferSize.Width - $global:Host.UI.RawUI.CursorPosition.X
        }
        if ($this.Length -gt $this.Text.Length) {
            return $this.Text
        } else {
            return ($this.Text.Substring(0,($this.Length -3)) + '...')
        }
    }
}
function Write-ALFColorHost {
    <#
    .SYNOPSIS
        Colorizes string matching patterns by a given color

    .DESCRIPTION
        Parses a string or array of strings, finds patterns which are colorized by a given console color

    .PARAMETER Text
        The string or array of strings you want to make look nicer    

    .PARAMETER Pattern
        The string or regular expression you intend to colorize

    .PARAMETER ForgroundColorMatch
        Foregroundcolor of the matching pattern

    .PARAMETER BackgroundColorMatch
        Backgroundcolor of the matching pattern
    
    .PARAMETER ForgroundColor
        Foregroundcolor of all parts of the text not matching the pattern

    .PARAMETER BackgroundColor
        Backgroundcolor of all parts of the text not matching the pattern    

    .PARAMETER Postfix
        A trailing text added to Text Parameter    

    .INPUTS
        The string or array of strings you want to make look nicer 

    .OUTPUTS
        Text with colors

    .EXAMPLE
        get-service | out-string | Write-ALFColorHost -Pattern Running -ForgroundColorMatch red -BackgroundColorMatch yellow

    .LINK
        https://github.com/DanielLettau/ALF

    #>
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$Text,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [Parameter(Mandatory)]
        [consolecolor]$ForgroundColorMatch,
        [Parameter(Mandatory)]
        [consolecolor]$BackgroundColorMatch,
        [consolecolor]$ForgroundColor,
        [consolecolor]$BackgroundColor,
        [string]$Postfix=""
    )
    begin {
        if ($input) {$Text = $input}
        function Write-ALFColorHostDefault($Text) {
            $parameters = @{
                NoNewline = $true
                Object = $Text
            }
            if ($ForgroundColor) {$parameters.Add("ForegroundColor",$ForgroundColor)}
            if ($BackgroundColor) {$parameters.Add("BackgroundColor",$BackgroundColor)}
            Write-Host @parameters
        }
    }
    process {
        foreach ($Line in $Text) {
            if ($Pattern) {
                $Line -split "(?=$($pattern))|(?<=$($pattern))" | ForEach-Object {
                    if ($_ -match $pattern) {
                        Write-Host -NoNewline -ForegroundColor $ForgroundColorMatch -BackgroundColor $BackgroundColorMatch -Object $_
                    } else {
                        Write-ALFColorHostDefault $_
                    }
                }
            } else {
                Write-ALFColorHostDefault $Line
            }
        }
        Write-ALFColorHostDefault $Postfix
    }
}

function Format-ALFObjectContentColor {
        <#
        .SYNOPSIS
            Makes ALFObjectContent results more readable
    
        .DESCRIPTION
            Takes ALFObjectSearchResult Objects as input to colorize the matching pattern
    
        .PARAMETER SearchResult
            An object of type ALFObjectSearchResult   
    
        .INPUTS
            An object of type ALFObjectSearchResult 
    
        .OUTPUTS
            Text with colors
    
        .EXAMPLE
            
        $VmView | Find-OjectContent -Pattern '201[89]' | Format-ALFObjectContentColor
    
        .LINK
            https://github.com/DanielLettau/ALF
    
        #>
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [ALFObjectSearchResult[]]
        $SearchResult
    )
    begin {
        if ($input) {$SearchResult = $input}
    }
    process {
        foreach ($sr in $SearchResult) {
            $ObjectName = [ALFOneLineText]::new($sr.Name,100)
            Write-ALFColorHost -Text ($ObjectName.Shorten() + ' ') -Pattern $sr.Pattern -ForgroundColorMatch Gray -BackgroundColorMatch DarkGray -ForgroundColor Gray -BackgroundColor Black
            if ($sr.ColorizeProperty) {
                Write-ALFColorHost -Text $sr.Property -Pattern $sr.Pattern -ForgroundColorMatch DarkCyan -BackgroundColorMatch DarkRed -Postfix ": " -ForgroundColor Cyan -BackgroundColor Black
            } else {
                Write-Host -NoNewline -Object ($sr.property + ": ")
            }
            if ($sr.value) {
                $Value = [ALFOneLineText]::new($sr.Value)
                if ($sr.ColorizeValue) {
                    Write-ALFColorHost -Text $Value.Shorten() -Pattern $sr.Pattern -ForgroundColorMatch DarkYellow -BackgroundColorMatch DarkRed -Postfix "`n" -ForgroundColor Yellow -BackgroundColor Black
                } else {
                    Write-Host -Object $Value.Shorten()
                }
            } else {
                ""
            }
        }
    }
}
function Find-ALFObjectContent {
<#
    .SYNOPSIS
        Finds values or properties matching a given pattern within an object

    .DESCRIPTION
        Find-ObjectContent searches through a given object and retrieves matching propertynames
        or propertyvalues. This command was intended to find values in PowerCLI get-view results /
        extensiondata property but is also useful for any other large object in which you know a
        specific value must exist.

    .PARAMETER Object
        A (large) object of any kind. E.g.: (get-view -ViewType VirtualMachine)    

    .PARAMETER Pattern
        The string or regular expression you intend to find

    .PARAMETER IncludePropertyName
        Defins if a match in the propertyname should be listed

    .PARAMETER IncludePropertyValue
        Defins if a match in the propertyvalue should be listed
    
    .PARAMETER MaxDepth
        How deep in the properties should be searched for a match

    .INPUTS
        A (large) object of any kind. E.g.: (get-view -ViewType VirtualMachine) 

    .OUTPUTS
        Returns an object of class ObjectSearchResult
        Name             : ESX1
        Property         : Hardware.CpuPkg[0].Description
        Value            : Intel(R) Xeon(R) CPU           L3426  @ 1.87GHz
        Pattern          : Intel
        ColorizeProperty : True
        ColorizeValue    : True

    .EXAMPLE
        Find-OjectContent -Object $EsxHost.extensiondata -MaxDepth 4 -Pattern Intel -IncludePropertyName -IncludePropertyValue:$false

    .EXAMPLE
        $VmView | Find-OjectContent -Pattern '201[89]' | Format-ALFObjectContentColor

    .LINK
        https://github.com/DanielLettau/ALF

    #>
    [OutputType([ALFObjectSearchResult[]])]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [object[]]$Object,
        [Parameter(Mandatory)]
        [string]$Pattern,
        [switch]$IncludePropertyName=$false,
        [switch]$IncludePropertyValue=$true,
        [int]$MaxDepth=3
    )
    begin {
        if ($input) {$Object = $input}
        $script:maxdepth = $MaxDepth
    }

    process {    
        $Crawlresult = foreach ($o in $object) {
            if ($o.psobject.Properties.name -contains "Name") {
                $ObjectName = $o.Name
            } elseif ($o.psobject.Properties.name -contains "Key") {
                $ObjectName = $o.Key
            } else {
                $ObjectName = $o.tostring()
            }      
            $r = crawl -obj $o 
            $r | ForEach-Object {$_.Add("ObjectName",$ObjectName)}
            $r
        }
        $FilteredCrawlResult = $Crawlresult | Where-Object {
            ($IncludePropertyValue -and $_.Propertyvalue -match $Pattern) -or 
            ($IncludePropertyName -and ($_.PropertyPath -replace '\[\d+?\]','') -match $Pattern)
        }
        foreach ($Result in $FilteredCrawlResult) {
            [ALFObjectSearchResult]::new(
                $Result.ObjectName,
                $Result.PropertyPath,
                $Result.PropertyValue,
                $pattern,
                $IncludePropertyName,
                $IncludePropertyValue
            )
        }
    }
}