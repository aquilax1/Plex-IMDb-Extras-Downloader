<#
.SYNOPSIS
Powershell script for PLEX to download the extra content of the movies from IMDB

.DESCRIPTION
This powershell script scans PLEX for movies and downloads the available extra content like trailers and interviews from IMDB.

.PARAMETER extras
A list of PLEX extra video types, only the videos matching the given types will be downloaded.
- Scene (IMDb Clip)
- Featurette (IMDb Featurette)
- Interview (IMDb Interview)
- Short (IMDb Promo)
- Trailer (IMDb Trailer)
- BehindTheScenes (IMDb Video)
If omitted all the types will be downloaded.

.PARAMETER libraries
A list of PLEX libraries, which will be scanned for new movies, if omitted all the libraries will be scanned.

.PARAMETER plex
The URL of PLEX, if omitted it will be used the default URL http://localhost:32400, which is the URL of the local instance of PLEX

.PARAMETER filterAdd
One of the filter key of the PLEX library, for add imdb extra content
- all: for all movies
- unwatched: for the unwatched movies
- newest: for the recently released
- recentlyAdded: for the recently added movies to PLEX
- recentlyViewed: for the recently vieved movies
- onDeck: for the movies on deck in PLEX
If omitted it will be used the default filter key, which is "recentlyAdded"

.PARAMETER max
The maximal number of movies to process, it is more a debug parameter

.PARAMETER removeFromWatched
If the parameter is added, all the downloaded extra videos of all watched movies will be deleted to save space on the hard disk.

.PARAMETER filterRemove
One of the filter key of the PLEX library, for remove the download imdb extra content
- all: for all movies
- unwatched: for the unwatched movies
- newest: for the recently released
- recentlyAdded: for the recently added movies to PLEX
- recentlyViewed: for the recently vieved movies
- onDeck: for the movies on deck in PLEX
If omitted it will be used the default filter key, which is "recentlyViewed"

.PARAMETER token
Authentication token to access PLEX WEB API, required if the origin IP has not be added to the list of the allowed networks without authentication.
For more information about authentication token and allowed network without authentication follow those links:
https://support.plex.tv/hc/en-us/articles/200890058-Require-authentication-for-local-network-access
https://support.plex.tv/hc/en-us/articles/204059436-Finding-an-authentication-token-X-Plex-Token

.PARAMETER omdbapikey
API key for omdb api rest service (http://www.omdbapi.com/), used as backup method to find out the IMDB id of a movie if PLEX hasn't identified it

.EXAMPLE
./PlexIMDbExtrasDownloader.ps1
It downloads all the available videos for all the types for all the movies in all categories

.EXAMPLE
./PlexIMDbExtrasDownloader.ps1 -libraries "movies" -extras "Trailer"
It downloads only the video marked as "trailer" only for the library "movies"

.LINK
https://github.com/aquilax1/Plex-IMDb-Extras-Downloader
#>
param([String[]] $extras, [String[]] $libraries, [String] $plex="http://localhost:32400", [string] $filterAdd="recentlyAdded", [Int] $max=0, [Switch] $removeFromWatched, [string] $filterRemove="recentlyViewed", [string] $token)

Function Remove-InvalidFileNameChars { param([Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String]$Name) $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''; $re = "[{0}]" -f [RegEx]::Escape($invalidChars); return ($Name -replace $re)}
Function Get-Movies ($filter) 
{ 
	#get all the movies of specified libraries with given filter
	$movies=$dirs | foreach{([xml]$web.DownloadString(($plex+"/library/sections/{0}/"+$filter+$token) -F $_.key)).MediaContainer.Video | where {$_.type -eq "movie"} | select -p key, title, year, @{Name="watched"; Expression={$_.viewCount -gt 0}}, @{Name="path"; Expression={(split-path -Path ([System.Uri]::UnescapeDataString(([Array]$_.Media)[0].Part.file)))}}, @{Name="imdb"; Expression={}}, @{Name="file"; Expression={}} }
	write-host (get-date) "There are" $movies.Count "movies in the libraries" $libraries "filtered by" $filter
	#get the imdb_extras file
	foreach($_ in $movies) { $_.file=Get-Item -LiteralPath ($_.path+$xmlfile) }
	return $movies	
}

Function Match-Movie($movie)
{
	#IMDb suggestions web api
	write-host (get-date) ("Resolving IMDb ID for '{0}'" -F $movie.title)
	$jsonp=$web.DownloadString(("http://sg.media-imdb.com/suggests/{0}/{1}.json" -F $movie.title.ToLower()[0], [System.Uri]::EscapeDataString($movie.title)))
	if ($jsonp -match "\{.*\}")
	{
		$mov=(ConvertFrom-Json $matches[0]).d | ? { $_.l -eq $movie.title -and $_.y -eq $movie.year } | Select-Object -first 1
		if ($mov -ne $Null) { $movie.imdb=$mov.id }
	}
	
	#omdb web api
	if ([System.String]::IsNullOrEmpty($movie.imdb) -and ![System.String]::IsNullOrEmpty($omdbapikey)) 
	{ 
		$doc.Load(("http://www.omdbapi.com/?apikey={0}&t={1}&y={2}&plot=short&r=xml" -F $omdbapikey, [System.Uri]::EscapeDataString($movie.title), $movie.year)); 
		$movie.imdb=$doc.root.movie.imdbID; 
	}
	
	# if ([System.String]::IsNullOrEmpty($movie.imdb) -and $False)
	# {
		# $movie.imdb=Read-Host ("IMDb Id for '{0}'" -F $movie.title)
	# }
	
	#updating the movie in plex with the IMDb Id
	write-host (get-date) ("IMDb ID for '{0}' is {1}" -F $movie.title, $movie.imdb)
	if ([System.String]::IsNullOrEmpty($movie.imdb))
	{
		[void]$web.UploadData($plex+$movie.key+"/match"+$token+("guid=com.plexapp.agents.imdb://{0}&name={1}" -F $_.imdb, [System.Uri]::EscapeDataString($_.title)),"PUT",[System.Byte[]]::CreateInstance([System.Byte],0))
	}
}

$xmlfile="\imdb_extras.xml"
$web=New-Object System.Net.WebClient
$doc=New-Object System.Xml.XmlDocument

#replace 127.0.0.1 and localhost with the machine ip because otherwiese plex returns a 401 access deneied
$plex=$plex -replace "localhost|127\.0\.0\.1", ((ipconfig | findstr [0-9].\.)[0]).Split()[-1]
#if the token is available, prepare it to be added at the end of each request
if (-not [String]::IsNullOrEmpty($token)) { $token="?X-Plex-Token="+$token+"&" } else { $token="?" }
#imdb video types to plex extra content type mapping
$map=@{"Clip"="Scene";"Featurette"="Featurette";"Interview"="Interview";"Promo"="Short";"Trailer"="Trailer";"Video"="BehindTheScenes"}
#get all the library and filter them if $libraries is defined
$dirs=([xml]$web.DownloadString($plex+"/library/sections"+$token)).MediaContainer.Directory | where {$libraries -eq $Null -or $libraries -contains $_.title }
#get all the movies, which haven't been processed yet, this means they don't have the imdb_extras.xml file in their folder
$newmovies=Get-Movies $filterAdd | where {$_.file -eq $Null} | sort -p title
if ($newmovies -eq $Null) { write-host (get-date) "All the movies have already been processed" }
else
{
	$count=0
	$nomatches=@()
	#get imdb id from the movie details, if imdb id is missing, try to get it from ombd with movie title and year. Breaking process if max is reached.
	foreach ($_ in $newmovies) { $doc.Load($plex+$_.key+$token); $_.imdb=[regex]::match($doc.MediaContainer.Video.guid,"imdb://(.*)\?").Groups[1].Value; if ([System.String]::IsNullOrEmpty($_.imdb)) { Match-Movie $_ }; if ([System.String]::IsNullOrEmpty($_.imdb)) { $nomatches+=$_.Title } elseif ($max -gt 0 -and ++$count -ge $max) { break; } }
	#showing unmatched movies, which are movies whitout imdb id
	if ($nomatches.Count -gt 0)  { write-host (get-date) "There are unmatched movies: " ($nomatches -join ", ") }
	#removing movies without the imdb id because it is impossible to download the extra content without the imdb id
	$newmovies=$newmovies | where { ![System.String]::IsNullOrEmpty($_.imdb) }
	if ($newmovies -eq $Null) { write-host (get-date) "All other movies have already been processed" }
	else
	{
		#get videos on imdb, max 60 videos (2 pages) per movie, the download url is missing here
		$newmovies=$newmovies | select *,@{Name="videos"; Expression={$path=$_.path; $page=$web.DownloadString("http://www.imdb.com/title/{0}/videogallery?ref_=tt_ov_vi_sm" -F $_.imdb)+$web.DownloadString("http://www.imdb.com/title/{0}/videogallery?ref_=tt_ov_vi_sm&page=2" -F $_.imdb); [regex]::matches($page,',-1_ZA(.*?),.*?<a href="/videoplayer/(\w*?)"(?:.|\s)*?>(.*?)</a>') | select -uniq @{Name="id"; Expression={$_.Groups[2].Value}},@{Name="type"; Expression={$map[$_.Groups[1].Value]}},@{Name="file"; Expression={(Remove-InvalidFileNameChars($_.Groups[3].Value))+".mp4"}},@{Name="url"; Expression={}} | where {$extras -eq $Null -or $extras -contains $_.type} }}
		#get the download url of the videos, some videos require the age verification and thus an account and to login, skip those videos
		$newmovies | foreach { write-host (get-date) "Processing" $_.title; if ($_.videos -eq $Null) { $_.videos = @() } else { $_.videos | foreach { $page=$web.DownloadString("http://www.imdb.com/video/imdb/{0}/imdb/single?vPage=1" -F $_.id); $_.url=[regex]::Match($page,'"videoMimeType":"video/mp4","videoUrl":"(.*?)"').Groups[1].Value } } }
		#download videos and creating the imdb_extras.xml file, to avoid to process the movies again
		$newmovies | foreach { if ($_.videos.Count -eq $Null) { $_.videos=@($_.videos) }; write-host (get-date) "Downloading" ($_.videos.Count) "videos for" $_.title; $path=$_.path; $_.videos | foreach { $dir=$path+"\"+$_.type; if (!(test-path -LiteralPath $dir)) {[void](New-Item -ItemType directory -Path $dir)}; while(test-path -LiteralPath ($dir+"\"+$_.file)) {$_.file=$_.file.Replace(".mp4"," .mp4")}; if (!([System.String]::IsNullOrEmpty($_.url))) {$web.DownloadFile($_.url,$dir+"\"+$_.file)} }; [System.IO.File]::WriteAllText(($path+$xmlfile),($_ | ConvertTo-XML -Depth 2).OuterXML); } 
	}
}

if ($removeFromWatched)
{
	#get all watched movies whose extra content has been downloaded from this script
	$watched=Get-Movies $filterRemove | where {$_.watched -and $_.file -ne $Null -and $_.file.Length -ne 0} | sort -p title
	#load the imdb_extrax.xml file and delete the downloaded videos
	$watched | foreach { write-host (get-date) "Remove extras from" $_.title; $path=$_.path; [xml]$xml=Get-Content -LiteralPath ($path+$xmlfile); $folders=@(); $parent=$xml.SelectSingleNode("//Property[@Name='videos']"); $videos=$parent.ChildNodes; if ($parent.Type -eq "System.Management.Automation.PSCustomObject") { $videos=@($parent) }; $videos | foreach { $folder=$_.SelectSingleNode("./Property[@Name='type']").'#text'; $file=$_.SelectSingleNode("./Property[@Name='file']").'#text'; if ($folders -NotContains $folder) { $folders+=$folder }; write-host (get-date) "Remove" $folder"\"$file; Remove-Item -LiteralPath ($path+"\"+$folder+"\"+$file); }; foreach ($folder in $folders) { if ((Get-ChildItem -LiteralPath ($path+"\"+$folder)).Length -eq 0) { Write-Host (Get-Date) "Remove folder" $folder; Rmdir -LiteralPath ($path+"\"+$folder) -Force } else { Write-Host (Get-Date) "Folder" $folder "is not empty"} }; [void](New-Item ($path+$xmlfile) -Force); }
}
