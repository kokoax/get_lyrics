# GetLyrics
- discription
  This application is getting lyrics.
  Song searching is automatic get from the top of UtaTen.com with options.

- options
  -t, --title    => song title     :must using. if no using then put ""
  -a, --artist   => song artist    :must using. if no using then put ""
  -c, --composer => song composer  :must using. if no using then put ""


## Installation
``` shell
  $ cd get_lyrics
  $ mix deps.get
  $ mix escript.build
  $ ./get_lyrics --title "song title" --artist "song artist" --composer "song composer"
```

