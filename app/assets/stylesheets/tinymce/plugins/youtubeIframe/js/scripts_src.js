// @name scripts
// @author Darius Matulionis <darius@matulionis.lt>

tinyMCEPopup.requireLangPack();

var YoutubeDialog = {
    init: function () {
        var f = document.forms[0];
        // Get the selected contents as text and place it in the input
        f.youtubeURL.value = tinyMCEPopup.editor.selection.getContent({format: 'text'});
        
        //Add click event form selection
        $(".share-embed-size-list li.share-embed-size").each(function(){
            $(this).click(function(){
                $("li.share-embed-size").removeClass("selected");
                $(this).addClass("selected");
            });
        });
    },
    // Insert the contents from the input into the document
    insert: function () {
        
        //Get Code from URL
        var url = $("#youtubeURL").val();
        if (url === null) {tinyMCEPopup.close();return;}
        
        var code, regexRes, width, height, type;
        regexRes = url.match("[\\?&]v=([^&#]*)");
        code =  $.trim( (regexRes === null) ? url : regexRes[1] );
        if (code === "") {tinyMCEPopup.close();return;}
        
        //Get Size
        width = $("li.selected label input").attr("data-width");
        height = $("li.selected label input").attr("data-height");
        
        //Get Custom size
        if(width == -1 && height == -1){
            width = $("input.share-embed-size-custom-width").val();
            height = $("input.share-embed-size-custom-height").val();
        }
        
        //No size or Some Error Accured
        if(width == "" || width == "undefined" || height == "" || height == "undefined"){
            alert("Error: No size selected");tinyMCEPopup.close();return;
        }
        
        //Get insert type
        type = $("input[name='yType']:checked").val();
        
        //No type or Some Error Accured
        if(type == "" || type == "undefined"){
            alert("Error: No type selected");tinyMCEPopup.close();return;
        }
        
        //Codes
        var iFrame = '<iframe width="'+width+'" height="'+height+'" src="http://www.youtube.com/embed/'+code+'?wmode=transparent" frameborder="0" allowfullscreen></iframe>';
        var embeded = '\
        <object width="'+width+'" height="'+height+'">\n\
            <param name="movie" value="http://www.youtube.com/v/'+code+'?version=3&amp;hl=en_US"></param>\n\
            <param name="allowFullScreen" value="true"></param>\n\
            <param name="allowscriptaccess" value="always"></param>\n\
            <param name="wmode" value="transparent"></param>\n\
            <embed src="http://www.youtube.com/v/'+code+'?version=3&amp;hl=en_US" type="application/x-shockwave-flash" width="'+width+'" height="'+height+'" allowscriptaccess="always" allowfullscreen="true"></embed>\n\
        </object>';
        
        //Isert to edditor
        if(type == "iframe"){
            tinyMCEPopup.editor.execCommand('mceInsertContent', false, iFrame);
        }else{
            tinyMCEPopup.editor.execCommand('mceInsertContent', false, embeded);
        }
        
        //Close
        tinyMCEPopup.close();
        
        
    }
};
tinyMCEPopup.onInit.add(YoutubeDialog.init, YoutubeDialog);


