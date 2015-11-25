
function prepareEventHandlers()
{
    console.log('test');

    $('.linkSectionContainer').click(function() {
        var isCollapsed = $(this).hasClass("collapsed");
        // Collapse all other columns
        $('.linkSectionContainer').addClass("collapsed");
        // Toggle this column
        if (isCollapsed) {
            $(this).removeClass("collapsed");
        }
        else {
            $(this).addClass("collapsed");
        }
    });

    $('.linkSectionContainer').addClass("collapsed");
}

