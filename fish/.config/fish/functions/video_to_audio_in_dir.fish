function video_to_audio_in_dir
    for file in *.mp4
        ffmpeg -i $file -vn -ac 1 -ab 8k -f mp3 $argv$file.mp3
    end
end
