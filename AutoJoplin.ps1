param($hostname)

# TOKEN
$token = ""

# API URIs
$joplinNoteUrl = "http://localhost:41184/notes?token=$($token)"
$joplinFolderUrl = "http://localhost:41184/folders?token=$($token)"



# FILEPATH TO AUTORECON SCANS FOLDER
$filepath = ""


# Call this to get initial and updated folder lists


function GetJoplinFolders{
    $joplinFoldersJson = curl $joplinFolderUrl
    $joplinFolders = $joplinFoldersJson | ConvertFrom-Json

    return ($joplinFolders).items
}

# Posts Notebook and Notes to Joplin
function JoplinPost{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$url,
        [string]$title,

        [Parameter()]
        [string]$parentID,
        [string]$message
    )

    $params = @{
        title = $title
    }

    if($parentID){
        $params += @{'parent_id' = $parentID}

        if($message){
            $params += @{'body' = $message}
        }
    }

    Invoke-WebRequest -Uri $url -Method Post -Body ($params|ConvertTo-Json) -ContentType "application/json"
}

# Calls JoplinPost and creates new Notebook
function CreateNotebook{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$title,

        [Parameter()]
        [string]$parentNotebook
    )
    
    try{
        if($parentNotebook){

            JoplinPost -url $joplinFolderUrl -title $title -parentID $parentNotebook
        }
        else {
            JoplinPost -url $joplinFolderUrl -title $title
        }
    }
    catch{
        Write-Host $Error[0]
    }
}

# Calls JoplinPost and creates new Note
function CreateNote{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$notebook,
        [string]$title,
        [string]$message
    )

    try{
        JoplinPost -url $joplinNoteUrl -title $title -parentID $notebook -message $message
    }

    catch{
        Write-Host $Error[0]
    }
}

# Primary function that scans filesystem and gets files ready to upload to Joplin
function GetScanFiles{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$hostname,
        [string]$filepath
    )
    $filepath = Join-Path -Path $filepath -ChildPath $hostname
    $directories = Get-ChildItem -Path  "$filepath/scans"  

    try{
        CreateNotebook -title $hostname
        $hostID = ((GetJoplinFolders) | Where-Object title -eq $hostname).id

        CreateNotebook -title "Ports" -parentNotebook $hostID
        $portID = ((GetJoplinFolders) | Where-Object parent_id -eq $hostID | Where-Object title -eq "Ports").id

        CreateNotebook -title "Other" -parentNotebook $portID
        $OtherID = ((GetJoplinFolders) | Where-Object parent_id -eq $portID | Where-Object title -eq "Other").id

    }
    catch{
        Write-Host $Error[0]
    }


    foreach($directory in $directories){

        if ($directory.Attributes -eq 'Directory') {
            if(!($directory.Name -eq 'xml')){
                CreateNotebook -title ($directory.Name) -parentNotebook $portID
                $id = ((GetJoplinFolders) | Where-Object parent_id -eq $portID | Where-Object title -eq ($directory.Name)).id

                foreach($file in $($directory.EnumerateFiles())){
                    $title = $file.BaseName
                    $message = Get-Content $file -Raw

                    CreateNote -notebook $id -title $title -message $message
                }
            }
        }
        elseif($directory.Attributes -ne 'Directory'){
            $title = $directory.BaseName
            $message = Get-Content $directory -Raw

            CreateNote -notebook $OtherID -title $title -message $message
        }
    }
}
GetScanFiles -filepath $filepath -hostname $hostname










