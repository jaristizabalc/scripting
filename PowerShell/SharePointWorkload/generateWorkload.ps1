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
    $location = ("C:\Users\Administrator\Documents\"+$downloadFolder)
    if (Test-Path $location) {
        Remove-Item $location -Force -Recurse -ErrorAction SilentlyContinue
    }
    New-Item $location -ItemType Directory -ErrorAction SilentlyContinue
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
                #add a unique timestamp to the filename so duplicates make it to the database, otherwise they will be overwritten without increasing the DB size (but will count as block changes from the SRN point of view)
                $unixTimeStamp = [math]::floor((Get-Date -UFormat %s))
                $outfile =  $location + "\" + $gfyCat.gfyId + "_" + $unixTimeStamp + ".gif"
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
$logFile =  "C:\Users\Administrator\Documents\GFW_"+$date+".csv"
New-Item $logFile -value "time,user,transferredBytes`r`n" -type file -Force
$downloadFolder = "gfyDownloads"
#Calculate the targetsize for downloads and the sleep time based on the desired change rate
#Set desired data change in a day (bytes)
$dailyGB = 48                     #target Download size per day in GB
$dailyChange = (1024*1024*1024)*$dailyGB 
$factor = 2                       #use it to tune the frequency of uploads, 1 is each hour, 2 is every half an hour, 4 every 15 minutes etc....
$frequency = 24*$factor                 #upload files half and hour
$sleepTime = 60*60/$factor               #
$targetSize = $dailyChange/$frequency
Write-Host "Download target size is $targetSize bytes every $sleepTime seconds ,"
$uploadCounter = 0                 #record the bytes uploaded so cleanup can be triggered accordingly
while($true) {
    if($uploadCounter -lt $dailyChange)
    {
        $rnd = Get-Random -Minimum 0 -Maximum $userArray.Length
        $username = $userArray[$rnd]
        Write-Host "Start downloading gfycats for user $username ,"
        $StartPoint=(Get-Date)
        Write-Host "Starting cycle at $StartPoint"
        pushGfycatFixedSize $downloadFolder $targetSize
        Write-Host "Finished downloading at $(Get-Date)"
        #Upload the images to SharePoint
        $securePasssword = ConvertTo-SecureString $password -AsPlainText -Force 
        $credentials = New-Object System.Management.Automation.PSCredential ($username, $securePasssword)
        $webclient = New-Object System.Net.WebClient
        $webclient.Credentials = $credentials
        $files = get-childitem ("C:\Users\Administrator\Documents\"+$downloadFolder)
        $uploadSize = 0
        $pass = 0
        foreach($file in $files) {
        Write-Host "Uploading $($file.Name) ,"
        try 
        {
            [byte[]] $response = $webclient.UploadFile($spHost + "/" + $file.Name, "PUT", $file.FullName)
            Write-Host $response
            $uploadSize = $uploadSize + $file.Length
            $pass = $pass + 1
        }
        catch [System.Net.WebException]
        {
            Write-Host "Upload failed"

        }
        
    }
        Write-Host "Uploaded $pass files"
        #Write to logfile
        $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
        Add-Content $logFile ($date+","+$username+","+$uploadSize)
        $uploadCounter = $uploadCounter + $uploadSize
        $EndPoint=(Get-Date)
        Write-Host "Finished cycle at $EndPoint"
        $differenceTime = NEW-TIMESPAN –Start $StartPoint –End $EndPoint
        Write-Host "Time difference is $differenceTime"
        $taskTime = $differenceTime.Hours*60*60 + $differenceTime.Minutes*60 + $differenceTime.Seconds
        $waitTime = $sleepTime - $taskTime
        Write-Host "Sleeping $sleepTime  - $taskTime"
        if($waitTime -gt 0){
            Write-Host "Sleeping for $waitTime seconds ,"
            Start-Sleep $waitTime
        }
        else {Write-Host "Negative difference, no sleeping"}
    }
    else {
        #clean-up files on SharePoint
        Write-Host "Cleanup SharePoint Library to avoid filling up file system, target is $dailyGB GB"
        #Record process on logfile
        $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
        $sharePointAdmin = "username"
        $sharePointIP = "A.B.C.D"    #Update Value
        Add-Content $logFile ($date+",StartCleanup,-----------------------------")
        $pwd = Get-Content c:\Users\Administrator\Documents\sp_creds.txt | ConvertTo-SecureString
        $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sharePointAdmin,$pwd 
        Invoke-Command -ComputerName $sharePointIP -Credential $creds -Authentication CredSSP -ArgumentList $dailyGB -ScriptBlock {
            #Commands to execute on SharePoint server
            Add-PSSnapin Microsoft.SharePoint.PowerShell
            $web = Get-SPWeb -Identity "http://SharePointServer/sites/SiteName"  #Update values
            $list = $web.GetList("http://SharePointServer/sites/SiteName/Downloads")    #Update Values   
            $folderUrl = $list.RootFolder.Url
            $folder = $web.GetFolder($folderUrl)
            $deleteMax = [int]$($args[0])*1024*1024*1024
            $total = 0
            $items = 0
            foreach ($file in $folder.Files) {
	            $total = $total + $file.Length
	            $items = $items+1
            }
            $totalGB = ([math]::Round($total/(1024*1024*1024), 4))
            Write-Host "Currently $items items on Library, for a total of $totalGB GB, deleting $deleteMax bytes ..."
            $current = 0 
            foreach ($file in $folder.Files) {
	            if($current -le $deleteMax){
		            #Write-Host("DELETED FILE: " + $file.name)
        	        $list.Items.DeleteItemById($file.Item.Id)
		            $current = $current + $file.Length	
	            }
	            else {
		            Write-Host "Deleted $current bytes already, exiting loop"
		            break
	            }
            }
            $folder = $web.GetFolder($folderUrl)
            $total = 0
            $items = 0
            foreach ($file in $folder.Files) {
	            $total = $total + $file.Length
	            $items = $items+1
            }
            $totalGB = ([math]::Round($total/(1024*1024*1024), 4))
            Write-Host "$items items on Library, for a total of $totalGB GB"
        }
        $uploadCounter = 0
        $date = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
        Add-Content $logFile ($date+",FinishCleanup,---------------------------")
    }
}
