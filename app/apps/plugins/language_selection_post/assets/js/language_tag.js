/********** language tagEditor ******************/
$(document).ready(function() {
	$('#form-post').find(".languageinput").tagEditor({
	    autocomplete: {delay: 0, position: {collision: 'flip'}, source: window.language_selection_post_locales},
	    forceLowercase: false,
	    placeholder: I18n("button.add_tag") + '...'
	});
});
/********** end language tagEditor **************/
