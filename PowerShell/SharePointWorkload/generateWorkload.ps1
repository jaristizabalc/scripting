function getTrendingTag(){
    #Get a list of trending tags on GfyCat and pick one randomly
    $url = 'https://api.gfycat.com/v1test/tags/trending'
    $output = "api_tag.out"
    $Parameters = @{
        tagCount = "100"
    }
    Clear-Content $output -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $url -Body $Parameters -UseBasicParsing -OutFile $output
    $json = Get-Content $output
    $jsonObj = $json | ConvertFrom-Json
    #Request is defined with a number but API returns more tags, search all returned
    $random = Get-Random -Minimum 0 -Maximum $jsonObj.Length
    return $jsonObj[$random]

}
function pushGfycatFixedSize($downloadFolder,$targetSize){
    #Prep download folder
    if (Test-Path $downloadFolder) {
        Remove-Item ((Get-Location).Path+"\"+$downloadFolder) -Force -Recurse -ErrorAction SilentlyContinue
    }
    New-Item $downloadFolder -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    #limit image size
    $limitSize = 100*1024*1024 #max is 100 MB
    $totalSize = 0
    while($totalSize -lt $targetSize){
        $tag = getTrendingTag
        #get GfyCat urls based on tags
        $url = "https://api.gfycat.com/v1/gfycats/trending"
        $output = "api.out"
        $Parameters = @{
            tagName = $tag
        }
        #get the gfycats by searching for the tag value and returning X amount of them
        Clear-Content $output -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri $url -Body $Parameters -UseBasicParsing -OutFile $output
        $json = Get-Content $output
        $jsonObj = $json | ConvertFrom-Json
        foreach ($gfyCat in $jsonObj.gfycats) {
            if($gfyCat.gifSize -ge $limitSize) {Write-Host "Image too big, skipping"}
            else {
                $totalSize = $totalSize + $gfyCat.gifSize
                $outfile =  (Get-Location).Path + "\" + $downloadFolder + "\" + $gfyCat.gfyId + ".gif"
                Write-Host "Downloading $($gfyCat.gfyId).gif, ->$tag ,"
                Invoke-WebRequest -Uri $gfyCat.gifUrl -OutFile $outfile
                if($totalSize -ge $targetSize) {break}
            }
        }
    }
    Write-Host "Downloaded $totalSize bytes from gfycat ,"
}

#push data to SharePoint 
# 1. Set a periodicity 
# 2. Pick a user randomly
# 3. Pick random tags from the most trending tags until you meet the size quota
# 4. Download the gigs and upload them to hte SharePoint image library

#Global variables
$spHostName = "SharePointFrontServer" 
$spHost = "http://"+$spHostName +"/sites/SITE/Library”				#Update path with Site name and Library
$userArray = "user1","user2","user3","user4","user5"				#add more users by adding elements to the array
$password = "P@ssw0rd"
#Logfile
$date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
$logFile = "GFW_"+$date+".csv"
New-Item $logFile -value "time,user,transferredBytes`r`n" -type file -Force
$downloadFolder = "gfyDownloads"
#Calculate the targetsize for downloads and the sleep time based on the desired change rate
#Set desired data change in a day (bytes)
$dailyChange = 1024*1024*1024*10  #10GB
$factor = 2                       #use it to tune the frequency of uploads, 1 is each hour, 2 is every half an hour, 4 every 15 minutes etc....
$frequency = 24*$factor                 #upload files half and hour
$sleepTime = 60*60/$factor               #
$targetSize = $dailyChange/$frequency
Write-Host "Download target size is $targetSize bytes every $sleepTime seconds ,"

while($true) {
    $rnd = Get-Random -Minimum 0 -Maximum $userArray.Length
    $username = $userArray[$rnd]
    Write-Host "Start downloading gfycats for user $username ,"
    $StartPoint=(Get-Date)
    Write-Host $StartPoint
    pushGfycatFixedSize $downloadFolder $targetSize
    #Upload the images to SharePoint
    $securePasssword = ConvertTo-SecureString $password -AsPlainText -Force 
    $credentials = New-Object System.Management.Automation.PSCredential ($username, $securePasssword)
    $webclient = New-Object System.Net.WebClient
    $webclient.Credentials = $credentials
    $files = get-childitem ((Get-Location).Path+"\"+$downloadFolder)
    $uploadSize = 0
    foreach($file in $files) {
        Write-Host "Uploading $($file.Name) ,"
        $webclient.UploadFile($spHost + "/" + $file.Name, "PUT", $file.FullName)
        $uploadSize = $uploadSize + $file.Length
    }
    #Write to logfile
    $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
    Add-Content $logFile ($date+","+$username+","+$uploadSize)
    $EndPoint=(Get-Date)
    Write-Host $EndPoint
    $processTime = NEW-TIMESPAN –Start $StartPoint –End $EndPoint
    Write-host "Difference in date: $processTime"
    $waitTime = $sleepTime - ($processTime.Hours*60*60 + $processTime.Minutes*60 + $processTime.Seconds)
    Write-Host "Difference in seconds: $waitTime"
    if($waitTime -gt 0){
        Write-Host "Sleeping for $waitTime seconds ,"
        Start-Sleep $sleepTime
    }
}
