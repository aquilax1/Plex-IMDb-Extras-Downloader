# Imdb Extras Downloader

##Introduction
This script is made for Plex, to download all the extra videos available on imdb.
If you don't have a Plex Pass, but you would like to have automatically downloaded the extra content for your movies, this script is for you.
This script has been inspired from this other [script](https://forums.plex.tv/discussion/121599/auto-download-missing-trailers-from-idmb-for-all-movies-in-collection). But I had a few issues with that script:

1. It is a bash script, which doesn't work on Windows, or at least you have to install Cygwin to run bash scripts on Windows
2. It access directly the database of Plex to get the IMDB Id of the movies, and to do that it requires the SQLite drivers, another software to install
3. It downloads the videos from Youtube and also for this task it requires an external application, namely youtube-dl
4. Last but not least it seems to be broken

So I took the idea but I remade the script in Powershell, which is the scripting language of windows, so I didn't need to install Cygwin.
Then I get the IMDB Id from the [Plex rest service](https://support.plex.tv/hc/en-us/articles/201638786-Plex-Media-Server-URL-Commands), so I didn't need to access the database of Plex, which is in general a very bad practice, thus I didn't need to install the SQLite drivers.
Last IMDB has already the videos on their server and to download them it requires a simple HTTP request, thus I didn't need to download them from Youtube, which means I didn't even need youtube-dl.
To summarize the beauty of this script is that you don't need to install any other application, because everything that you need is just Powershell, which is already included in Windows.

##How this script works
This script is quite smart, it uses the Plex rest service to get the required information about the movie collection, then it downloads the extra content from IMDB.
To find the movie on IMDB, it uses the IMDB id, which Plex saves in the database when it matches a movie. The videos on IMDB are also categorized, but they don't use the same categories of Plex, thus the script maps the IMDB categories as follow:
* **IMDB** --->  **Plex**
* Clip ---> Scene
* Featurette ---> Featurette
* Interview ---> Interview
* Promo ---> Short
* Trailer ---> Trailer
* Video ---> BehindTheScenes

Then it downloads all the video, but it is limited to 60 videos, because IMDB shows 30 videos per page, and the script gets only the videos of the first 2 pages, but until now I haven't seen a movie with more than 50 videos.
At the end it creates a XML file named "imdb_extas.xml", this file contains the information about the downloaded videos:
* IMDB Id of the video
* The category of the video
* The file name of the video
* The download URL of the video

This file is very important, because it is to mark a movie as processed, this means if the file is present in the directory of the movie, the script considers the movie as already processed and skips it. To reprocess a movie just delete this file.
When two or more videos have the same name, the script just append a white char at the end of the name of the video.

##Parameters
The script accept some parameters:
* extras: This parameter filter the video categories, if omitted the script downloads all the categories, otherwise only the specified one, for example to download only the trailers and the interviews use the following argument ```-extras Trailer,Interview```
* libraries: This parameter filter the Plex libraries, if omitted the script processes all the movies in all the libraries, otherwise only the specified one, for example to process only the "Movies" library use the following argument ```-libraries Movies```
* plex: This parameter is to change the Plex URL, if omitted the script uses the default URL and port, which is "http://localhost:32400"
* max: This parameter limit the number of processed movies, if omitted the script processes all the movies, otherwise if processes only "max" movies, for example to process only the first 10 movies use the following argument ```-max 10```

##Installation
This script hasn't an installer, just save the script somewhere in the hard disk and execute it ```powershell -command .\ImdbExtrasDownloader.ps1```.
To automate the process I have included a windows scheduler task to execute the script daily at 4 in the morning. Just import the imdbExtrasDownloader.xml in windows scheduler, once imported double click on the task and change the "working directory" in the "action" panel to the folder where you have saved the script.
