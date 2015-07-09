

	(function(){


	$.fn.smint = function( options ) {

		// adding a class to users div
		jQuery(this).addClass('smint')

		var settings = jQuery.extend({
		            'scrollSpeed '  : 500
		}, options);

		//Set the variables needed
		var optionLocs = new Array();
		var lastScrollTop = 0;
		var menuHeight = jQuery("").height();

		return jQuery('.smint a').each( function(index) {
            
			if ( settings.scrollSpeed ) {
				var scrollSpeed = settings.scrollSpeed
			}

			//Fill the menu
			var id = jQuery(this).attr("id");
			optionLocs.push(Array(jQuery("div."+id).position().top-menuHeight, jQuery("div."+id).height()+jQuery("div."+id).position().top, id));

			///////////////////////////////////

			// get initial top offset for the menu 
			var stickyTop = jQuery('.smint').offset().top;	

			// check position and make sticky if needed
			var stickyMenu = function(direction){

				// current distance top
				var scrollTop = jQuery(window).scrollTop(); 

				// if we scroll more than the navigation, change its position to fixed and add class 'fxd', otherwise change it back to absolute and remove the class
				if (scrollTop > stickyTop) { 
					jQuery('.smint').css({ 'position': 'fixed', 'top':0 }).addClass('fxd');	
				} else {
					jQuery('.smint').css({ 'position': 'absolute', 'top':stickyTop }).removeClass('fxd'); 
				}   

				//Check if the position is inside then change the menu
				// Courtesy of Ryan Clarke (@clarkieryan)


				if(optionLocs[index][0] <= scrollTop && scrollTop <= optionLocs[index][1]){	
					if(direction == "up"){
						jQuery("#"+id).addClass("active");
						jQuery("#"+optionLocs[index+1][2]).removeClass("active");
					} else if(index > 0) {
						jQuery("#"+id).addClass("active");
						jQuery("#"+optionLocs[index-1][2]).removeClass("active");
					} else if(direction == undefined){
						jQuery("#"+id).addClass("active");
					}
					jQuery.each(optionLocs, function(i){
						if(id != optionLocs[i][2]){
							jQuery("#"+optionLocs[i][2]).removeClass("active");
						}
					});
				}
			};

			// run functions
			stickyMenu();

			// run function every time you scroll
			jQuery(window).scroll(function() {
				//Get the direction of scroll
				var st = jQuery(this).scrollTop();
				if (st > lastScrollTop) {
				    direction = "down";
				} else if (st < lastScrollTop ){
				    direction = "up";
				}
				lastScrollTop = st;
				stickyMenu(direction);

				// Check if at bottom of page, if so, add class to last <a> as sometimes the last div
				// isnt long enough to scroll to the top of the page and trigger the active state.

				if(jQuery(window).scrollTop() + jQuery(window).height() == jQuery(document).height()) {
       			jQuery('.smint a').removeClass('active')
       			jQuery('.smint a').last().addClass('active')
   }
			});

			///////////////////////////////////////
    
        
        	jQuery(this).on('click', function(e){
				// gets the height of the users div. This is used for off-setting the scroll so the menu doesnt overlap any content in the div they jst scrolled to
				var selectorHeight = jQuery('.smint').height();   

        		// stops empty hrefs making the page jump when clicked
				e.preventDefault();

				// get id pf the button you just clicked
		 		var id = jQuery(this).attr('id');

		 		// if the link has the smint-disable class it will be ignored 
		 		// Courtesy of mcpacosy ‏(@mcpacosy)

                if (jQuery(this).hasClass("smint-disable"))
                {
                    return false;
                }

				// gets the distance from top of the div class that matches your button id minus the height of the nav menu. This means the nav wont initially overlap the content.
				var goTo =  jQuery('div.'+ id).offset().top -selectorHeight;

				// Scroll the page to the desired position!
				jQuery("html, body").animate({ scrollTop: goTo }, scrollSpeed);

			});	
		});
	}


})(jQuery);