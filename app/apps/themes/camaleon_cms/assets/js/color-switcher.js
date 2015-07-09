	jQuery(document).ready(function($) {
			
			
			jQuery(".color-switcher ul li a.change").click(function(){
			  jQuery(".color-switcher ul li a").removeClass("active");
			  jQuery(this).addClass("active");
			  return false;
		  });
			
			
			
		  jQuery("#yellow" ).click(function(){
			  jQuery("#color" ).attr("href", "css/yellow.css");
			  jQuery(".logo" ).attr("src", "images/logo-yellow-dark.png");
			  setCookie('color', 'yellow', 365);
			  return false;
		  });
		  
		  jQuery("#red" ).click(function(){
			  jQuery("#color" ).attr("href", "css/red.css");
			  jQuery(".logo" ).attr("src", "images/logo-red-dark.png");
			    setCookie('color', 'red', 365);
			  return false;
		  });
		  
		  jQuery("#blue" ).click(function(){
			  jQuery("#color" ).attr("href", "css/blue.css");
			  jQuery(".logo" ).attr("src", "images/logo-blue-dark.png");
			    setCookie('color', 'blue', 365);
			  return false;
		  });
		  
		  jQuery("#orange" ).click(function(){
			  jQuery("#color" ).attr("href", "css/orange.css");
			  jQuery(".logo" ).attr("src", "images/logo-orange-dark.png");
			    setCookie('color', 'orange', 365);
			  return false;
		  });
		  
		  jQuery("#green" ).click(function(){
			  jQuery("#color" ).attr("href", "css/green.css");
			  jQuery(".logo" ).attr("src", "images/logo-green-dark.png");
			    setCookie('color', 'green', 365);
			  return false;
		  });
		  
		  
		  
		  //DARK VERSION
		  jQuery("#yellow.dark").click(function(){
			  jQuery(".logo").attr("src", "images/logo-yellow-light.png");
			    setCookie('color', 'yellow', 365);
			  return false;
		  });
		  
		  jQuery("#red.dark").click(function(){
			  jQuery(".logo").attr("src", "images/logo-red-light.png");
			    setCookie('color', 'red', 365);
			  return false;
		  });
		  
		  jQuery("#blue.dark").click(function(){
			  jQuery(".logo").attr("src", "images/logo-blue-light.png");
			    setCookie('color', 'blue', 365);
			  return false;
		  });
		  
		  jQuery("#orange.dark").click(function(){
			  jQuery(".logo").attr("src", "images/logo-orange-light.png");
			    setCookie('color', 'orange', 365);
			  return false;
		  });
		  
		  jQuery("#green.dark").click(function(){
			  jQuery(".logo").attr("src", "images/logo-green-light.png");
			    setCookie('color', 'green', 365);
			  return false;
		  });
		  
		  

		 
		  
		  // picker buttton
		  jQuery(".picker-off").click(function(){
			  jQuery(this).toggleClass("move");
			  	jQuery(".color-switcher").toggleClass("position");
				jQuery(".color-switcher").toggleClass("fadeInRight animated");
		   });
		   
		  
		  
	})
	
	

