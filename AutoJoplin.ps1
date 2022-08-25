param($hostname)


# TOKEN
$token = "ENTER JOPLIN TOKEN"

# API URIs
$joplinNoteUrl = "http://localhost:41184/notes?token=$($token)"
$joplinFolderUrl = "http://localhost:41184/folders?token=$($token)"



# FILEPATH TO AUTORECON SCANS FOLDER
$filepath = "ENTER FILEPATH TO AUTORECON SCANS FOLDER"


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
    $files = Get-ChildItem -Path  "$filepath/scans" -Recurse -Attributes !Directory
    $fileNmapFull = $files| Where-Object BaseName -eq "_full_tcp_nmap"

    try{
        CreateNotebook -title $hostname
        $hostID = ((GetJoplinFolders) | Where-Object title -eq $hostname).id

        CreateNotebook -title "Ports" -parentNotebook $hostID
        $portID = ((GetJoplinFolders) | Where-Object parent_id -eq $hostID | Where-Object title -eq "Ports").id

        CreateNotebook -title "Unsorted" -parentNotebook $portID
        $unsortedID = ((GetJoplinFolders) | Where-Object parent_id -eq $portID | Where-Object title -eq "Unsorted").id

    }
    catch{
        Write-Host "Notebook already exists!!!"
    }

    if($fileNmapFull){
        $message = Get-Content $fileNmapFull
        foreach($line in $message){
            $line
            if($line -match "^\d+.tcp"){
                $port = ($line.Split())[0]
                CreateNotebook -title $port -parentNotebook $portID
            }
        }
    }


    foreach($file in $files){
        $title = $file.Basename
        $message = Get-Content $file -Raw 

        $joplinFolders = GetJoplinFolders
        # Creates the notes and places in proper notebook
        if ($title -like "smb*") {
            $smbNotebook = ($joplinFolders | Where-Object parent_id -eq $portID | Where-Object title -eq "445/tcp").id

            CreateNote -notebook $smbNotebook -title $title -message $message
        }
        elseif ($title -match "(tcp|udp)_\d+.*") {
            $portNum = ($title.Split("_"))[1]
            $portFolder = ($joplinFolders | Where-Object parent_id -eq $portID | Where-Object title -like "$portNum*").id

            CreateNote -notebook $portFolder -title $title -message $message
        }
        else{
            CreateNote -notebook $unsortedID -title $title -message $message
        }
    }
}

GetScanFiles -filepath $filepath -hostname $hostname










