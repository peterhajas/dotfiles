
function prepareEventHandlers()
{
    console.log('test');

    $('.linkSectionContainer').click(function() {
        // Collapse all other columns
        $('.linkSectionContainer').addClass("collapsed");
        // Open this column
        $(this).removeClass("collapsed");
    });

    $('.linkSectionContainer').addClass("collapsed");
}

