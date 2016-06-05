param([String[]] $extras, [String[]] $libraries, [String] $plex="http://localhost:32400", [Int] $max=0)
Function Remove-InvalidFileNameChars { param([Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][String]$Name) $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''; $re = "[{0}]" -f [RegEx]::Escape($invalidChars); return ($Name -replace $re)}
$web=New-Object System.Net.WebCLient
$doc=New-Object System.Xml.XmlDocument
#imdb video types to plex extra content type mapping
$map=@{"Clip"="Scene";"Featurette"="Featurette";"Interview"="Interview";"Promo"="Short";"Trailer"="Trailer";"Video"="BehindTheScenes"}
#get all the library and filter them if $libraries is defined
$dirs=([xml]$web.DownloadString($plex+"/library/sections")).MediaContainer.Directory | where {$libraries -eq $Null -or $libraries -contains $_.title }
#get all  the movies of the libraries, select only the needed data and esclude all the already processed movies, which have the imdb_extras.xml file in their folder
$movies=$dirs | foreach{([xml]$web.DownloadString(($plex+"/library/sections/{0}/all") -F $_.key)).MediaContainer.Video | where {$_.type -eq "movie"} | select -p key, title, @{Name="path"; Expression={(split-path -Path ([System.Uri]::UnescapeDataString($_.Media.Part.file)))}}, @{Name="imdb"; Expression={}} | where {!(test-path -LiteralPath ($_.path+"\imdb_extras.xml"))}} | sort -p title
if ($movies -eq $Null) { write-host (get-date) "All the movies have already been processed" }
else
{
	#get imdb movie id from the movie detail
	$movies | foreach { $doc.Load($plex+$_.key); $_.imdb=[regex]::match($doc.MediaContainer.Video.guid,"imdb://(.*)\?").Groups[1].Value }
	$nomatches=$movies | where { [System.String]::IsNullOrEmpty($_.imdb) } | foreach {$_.title}
	if ($nomatches -ne $Null)  { write-host (get-date) "There are unmached movies: " ($nomatches -join ", ") }
	#removing movies without imdb key, which aren't yet identified by plex
	$movies=$movies | where { ![System.String]::IsNullOrEmpty($_.imdb) }
	if ($movies -eq $Null) { write-host (get-date) "All other movies have already been processed" }
	else
	{
		#if $max is defined processing only $max movies (it was a debugging feature, but it could be useful)
		if ($max -gt 0) { $movies=$movies | select -first $max }
		#get videos on imdb, max 60 videos (2 pages) per movie, the download url is missing here
		$movies=$movies | select *,@{Name="videos"; Expression={$path=$_.path; $page=$web.DownloadString("http://www.imdb.com/title/{0}/videogallery?ref_=tt_ov_vi_sm" -F $_.imdb)+$web.DownloadString("http://www.imdb.com/title/{0}/videogallery?ref_=tt_ov_vi_sm&page=2" -F $_.imdb); [regex]::matches($page,',-1_ZA(.*?),.*?<a href="/video/imdb/(.*?)"[.|\s|\n|\r]*?>(.*?)</a>') | select @{Name="id"; Expression={$_.Groups[2].Value}},@{Name="type"; Expression={$map[$_.Groups[1].Value]}},@{Name="file"; Expression={(Remove-InvalidFileNameChars($_.Groups[3].Value))+".mp4"}},@{Name="url"; Expression={}} | where {$extras -eq $Null -or $extras -contains $_.type} }}
		#get the download url of the videos, some videos require the age verification and thus an account and to login, skip those videos
		$movies | foreach { write-host (get-date) "Processing" $_.title; if ($_.videos -eq $Null) { $_.videos = @() } else { $_.videos | foreach { $page=$web.DownloadString("http://www.imdb.com/video/imdb/{0}/imdb/single?vPage=1" -F $_.id); $_.url=[regex]::Match($page,'"videoMimeType":"video/mp4","videoUrl":"(.*?)"').Groups[1].Value } } }
		#download videos and creating the imdb_extras.xml file, to avoid to process the movies again
		$movies | foreach { $path=$_.path; $_.videos | foreach { $dir=$path+"\"+$_.type; if (!(test-path -LiteralPath $dir)) {New-Item -ItemType directory -Path $dir}; while(test-path -LiteralPath ($dir+"\"+$_.file)) {$_.file=$_.file.Replace(".mp4"," .mp4")}; if (!([System.String]::IsNullOrEmpty($_.url))) {$web.DownloadFile($_.url,$dir+"\"+$_.file)} }; [System.IO.File]::WriteAllText(($path+"\imdb_extras.xml"),($_ | ConvertTo-XML -Depth 2).OuterXML); } 
	}
}
