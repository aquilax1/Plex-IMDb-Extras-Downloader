# Plex IMDb Extras Downloader

##Introduction
This script has been made for [Plex](https://plex.tv), to download all the extra videos available on IMDb.
If you don't have a [Plex Pass](https://plex.tv/subscription/about), but you would like to have automatically downloaded the extra content for your movies, this script is for you.
This script has been inspired from another [script](https://forums.plex.tv/discussion/121599/auto-download-missing-trailers-from-idmb-for-all-movies-in-collection). But I had a few issues with that script:

1. It is a bash script, which doesn't work on Windows, or at least you have to install Cygwin to run bash scripts on Windows
2. It accesses directly the database of Plex to get the IMDb Id of the movies, and to do that it requires the SQLite drivers, another software to install
3. It downloads the videos from Youtube and also for this task it requires an external application, namely youtube-dl
4. Last but not least it seems to be broken

So I took the idea but I remade the script in [Powershell](https://msdn.microsoft.com/en-us/powershell/mt173057.aspx), which is the scripting language of Windows, so it doesn't require Cgwin.
Then it uses the [Plex rest service](https://support.plex.tv/hc/en-us/articles/201638786-Plex-Media-Server-URL-Commands) to get the IMDb Id, therefore it doesn't require to access the database of Plex, what is in general a very bad practice, thus it doesn't require the SQLite drivers.
Last IMDb has already the videos on their server and to download them it's enough a simple HTTP request, thus it doesn't need to download them from Youtube, which means that it doesn't need the youtube-dl.
To summarize the beauty of this script is that it doesn't need any other application, it requires only Powershell, which is already part of Windows.

##How this script works
This script is quite smart, it uses the Plex rest service to get the required information about the movie collections, then it downloads the extra content from IMDb.
To find the movie on IMDb, it uses the IMDb id, which Plex saves in the database when it matches a movie. The videos on IMDb are also categorized, but they don't use the same categories of Plex, thus the script maps the IMDb categories as follow:

| **IMDb** | **Plex** |
|------------ | ------------- |
| Clip | Scene |
| Featurette | Featurette |
| Interview | Interview |
| Promo | Short |
| Trailer | Trailer |
| Video | BehindTheScenes |

On IMDb the videos are limited to 30 per page, the script parses only the first two pages, this means that it can download at maximum 60 videos per movie, but until now I haven't see a movie with more than 50 videos. Sometimes two or more videos can have the same name, in this case the script just appends at the end of the name one or more white spaces until the name is unique.

At the end it creates a XML file named **imdb_extas.xml, this file is very important, don't delete it**, because this file is to mark a movie as processed, this means that if the file is present in the directory of the movie, the script considers the movie as already processed and skips it. To reprocess a movie again just delete this file.

The imdb_extas.xml contains the information about the downloaded videos:
* IMDb Id of the video
* The category of the video
* The file name of the video
* The download URL of the video

##Parameters
The script accepts some parameters but they are all optional. If no parameter are passed to the script, it will download all the videos for all the movies in all the libraries.
* extras: This parameter filter the video categories, if omitted, the script downloads all the categories, otherwise only the specified one, for example to download only the trailers and the interviews use the following argument ```-extras Trailer,Interview```
* libraries: This parameter filter the Plex libraries, if omitted, the script processes all the movies in all the libraries, otherwise only the specified one, for example to process only the "Movies" library use the following argument ```-libraries Movies```
* plex: This parameter is to change the Plex URL, if omitted, the script uses the default URL and port, which is ```http://localhost:32400```
* max: This parameter limit the number of processed movies, if omitted, the script processes all the movies, otherwise it processes only "max" movies, for example to process only the first 10 movies use the following argument ```-max 10```
* removeFromWatched: This parameer is to remove all the downloaded videos from the wathced movies to save space on the hard disk
* filterRemove: This parameter is the filter to apply to the list of movies to remove from wathched ones
* token: This parameter is required only if Plex isn't configured to grant access without authentication. In the Plex configuration  it is possible to grant the access without authentication to a list of IP addresses or IP net masks, for example from a local network with the net mask 192.168.0.0/24
* omdbapikey: This parameter is to query the O(pen)MDBApi (http://www.omdbapi.com/) to find out the IMDb ID of a movie in case that Plex wasn't able to determine it. This parameter is not manadtory for the script to work, if no omdbapi key is given, the script just skips this step.

##Installation
This script hasn't an installer, just save the script somewhere in the hard disk and execute it: ```powershell -command .\PlexIMDbExtrasDownloader.ps1```.
To automate the process I have included a Windows scheduler task to execute the script daily at 4 o'clock in the morning. Just import the PlexIMDbExtrasDownloader.xml in Windows scheduler, once imported double click on the task and change the "working directory" in the "action" panel to the folder where you have saved the script.

##Support Me
I have invested quite some time to write this script, if you have found this script useful, consider give me a little of this time back and join the other users, who have opened a Dropbox account using my referral link: [https://db.tt/NO2L9ANq](https://db.tt/NO2L9ANq)

Thank you!
