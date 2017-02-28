jQuery(function($){
    /**
     * TRANSLATOR PLUGIN
     *
     * Example:
     * var trans = jQuery("input[type='text'], textarea").not(":hidden").Translatable(["es", "en"])  ===> convert input/textarea into translatable panel
     *
     * trans.trigger("trans_integrate") ==> encode translations into owner element (destroy translation elements)
     */

    /**
     *
     * @param languages => ["es", "en", 'fr']
     * @param default_language => not important (deprecated)
     * @returns {$.fn.Translatable}
     * @constructor
     * select tag fix: save translated value in data-value
     */
    var TRANSLATOR_counter = 1;
    $.fn.Translatable = function(languages, default_language){
        languages = languages || ADMIN_TRANSLATIONS; // rescue from admin variable
        default_language = default_language?default_language:languages[0];
        var self = $(this).not(".translated-item, .translate-item");

        // decode translations
        // text: string containing translations
        // language(optional): get translation value for this language
        // return a hash of translations
        get_translations = function(text, language){
            var translations_per_locale = {};
            var res = "";
            if(!text || text.trim().search("<!--") != 0){ // not translated string
                for(var i in languages){
                    translations_per_locale[languages[i]] = text;
                }
                res = translations_per_locale;

            }else{ // has translations
                var splitted = text.split('<!--:-->');
                for(var i in splitted){
                    var str = splitted[i];
                    var m_atch = str.trim().match(/^<!--:([\w||-]{2,5})/);
                    if(m_atch && m_atch.length == 2){
                        m_atch[1] = m_atch[1].replace("--", "")
                        translations_per_locale[m_atch[1]] = str.replace("<!--:"+m_atch[1]+"-->", "")
                    }
                }
                res = translations_per_locale;
            }
            if(language) return get_translation(res, language);
            else return res;
        }

        // get translation for a language
        get_translation = function(translations, language){
            return language in translations?translations[language]:(languages[0] in translations?translations[languages[0]]: "");
        }

        //if translations is a uniq language
        if(languages.length < 2){
            self.each(function(){ $(this).val(get_translations($(this).val(), languages[0])); });
            return this;
        }

        self.each(function(){
            var ele = $(this);
            var tabs_title = [], tabs_content = [], translations = get_translations(ele.is('select') ? ele.data('value') : ele.val()), inputs = {};
            var class_group = ele.parent().hasClass("form-group") ? "" : "form-group";
            // decoding languages
            for(var ii in languages){
                var l = languages[ii];
                var key = "translation-"+l+"-"+TRANSLATOR_counter;
                tabs_title.push('<li role="presentation" class="pull-right '+(ii==0?"active":"")+'"><a href="#pane-'+key+'" role="tab" data-toggle="tab">'+ l.titleize()+'</a></li>');
                var clone = ele.clone(true).attr({id: key, name: key, "data-name": key, 'data-translation_l': l, 'data-translation': "translation-"+l}).addClass("translate-item").val(get_translation(translations, l));
                if(ii > 0 && !clone.hasClass('required_all_langs')) clone.removeClass('required'); // to permit enter empty values for secondary languages
                inputs[l] = clone;
                clone.wrap("<div class='tab-pane "+class_group+" trans_tab_item "+(ii==0?"active":"")+"' id='pane-"+key+"'/>");
                tabs_content.push(clone.parent());
                TRANSLATOR_counter++;
                // Auto Update Translates
                clone.bind('change change_in',function(){
                    var r = [];
                    for(var l in inputs){
                        r.push("<!--:"+l+"-->"+inputs[l].val()+"<!--:-->");
                    }
                    ele.val(r.join(""));
                    if((typeof tinymce == "object") && ele.is('textarea') && ele.attr('id') &&  tinymce.get(ele.attr('id'))) tinymce.get(ele.attr('id')).setContent(r.join(""));
                });
            }

            // creating tabs per translation
            var tabs = $('<div class="trans_panel" role="tabpanel"><ul class="nav nav-tabs" role="tablist"></ul><div class="tab-content"></div></div>');
            tabs.find(".nav-tabs").append(tabs_title.reverse());
            tabs.find(".tab-content").append(tabs_content);
            
            // unknown fields (fix for select fields)
            if(ele.is('select')){
                var rep_field = $('<input type="hidden">').attr({class: ele.attr('class'), name: ele.attr('name')})
                ele.replaceWith(rep_field);
                ele = rep_field;
                tabs_content[0].find('.translate-item').trigger('change');
            }
            
            ele.addClass("translated-item").hide().after(tabs);
            //ele.data("tabs_content", tabs_content);
            ele.data("translation_inputs", inputs);

            // encode translation
            // remove tabs added by translation
            ele.bind("trans_integrate", function(){
                var r = [];
                for(var l in inputs){
                    r.push("<!--:"+l+"-->"+inputs[l].val()+"<!--:-->");
                }
                ele.show().val(r.join(""));
                if((typeof tinymce == "object") && ele.is('textarea') && ele.attr('id') &&  tinymce.get(ele.attr('id'))) tinymce.get(ele.attr('id')).setContent(r.join(""));
                tabs.remove();
                $(this).removeClass("translated-item");
            });
        });
        return this;
    }
});
