WIDTH=300
wget --quiet --output-document "/tmp/radar.gif" "https://radar.weather.gov/ridge/standard/CONUS_9.gif"
ffmpeg -i /tmp/radar.gif -vf scale=$WIDTH:-1 -y /tmp/radar.jpeg
sketchybar --set $NAME width=$WIDTH
sketchybar --set $NAME background.color=0x11000000
sketchybar --set $NAME background.image="/tmp/radar.jpeg"
