function journal_today
    set -l wiki ~/phajas-wiki/phajas-wiki.html
    set -l title (date +%F)

    set -l tags (tw $wiki get $title tags 2>/dev/null; or echo "")
    if test -z "$tags"
        set tags Journal
    else if not string match -q -r '(^| )Journal( |$)|\\[\\[Journal\\]\\]' -- $tags
        set tags "$tags Journal"
    end

    tw $wiki set $title tags "$tags"
    tw $wiki edit $title
end
