jQuery(function($){
    /**
     * TRANSLATOR PLUGIN
     *
     * Example:
     * var trans = jQuery("input[type='text'], textarea").not(":hidden").Translatable(["es", "en"])  ===> convert input/textarea into translatable panel
     *
     * trans.trigger("trans_integrate") ==> encode translations into owner element
     */

    String.prototype.parameterize = function () { return this.trim().replace(/[^a-zA-Z0-9-\s]/g, '').replace(/[^a-zA-Z0-9-]/g, '-').toLowerCase(); }

    /**
     *
     * @param languages => ["es", "en", 'fr']
     * @param default_language => not important
     * @returns {$.fn.Translatable}
     * @constructor
     */
    $.fn.Translatable = function(languages, default_language){
        default_language = default_language?default_language:languages[0];
        var self = this;

        // decode translations
        get_translations = function(text){
            var translations_per_locale = {};
            if(text.search("<!--") != 0 || !text){ // not translated string
                for(var i in languages){
                    translations_per_locale[languages[i]] = text;
                }
                return translations_per_locale;
            }

            // has translations
            var splitted = text.split('<!--:-->');
            for(var i in splitted){
                var str = splitted[i];
                var m_atch = str.match(/^<!--:([\w]{2})/);
                if(m_atch && m_atch.length == 2){
                    translations_per_locale[m_atch[1]] = str.replace("<!--:"+m_atch[1]+"-->", "")
                }
            }
            return translations_per_locale;
        }

        // get translation for a language
        get_translation = function(translations, language){
            return language in translations?translations[language]:(default_language in translations?translations[default_language]:"");
        }

        $(self).each(function(){
            var ele = $(this);
            var tabs_title = [], tabs_content = [], translations = get_translations(ele.val()), inputs = {};

            // decoding languages
            for(var ii in languages){
                var l = languages[ii];
                var key = ("trans-"+ele.attr("name")+"-"+l).parameterize();
                tabs_title.push('<li role="presentation" class="pull-right '+(ii==0?"active":"")+'"><a href="#'+key+'" role="tab" data-toggle="tab">'+l+'</a></li>');
                var clone = ele.clone().attr({id: key, name: key}).addClass("translate-item").val(get_translation(translations, l));
                inputs[l] = clone;
                clone.wrap("<div class='tab-pane "+(ii==0?"active":"")+"' id='"+key+"'/>");
                tabs_content.push(clone.parent());
            }

            // creating tabs per translation
            var tabs = $('<div class="trans_panel" role="tabpanel"><ul class="nav nav-tabs" role="tablist"></ul><div class="tab-content"></div></div>');
            tabs.find(".nav-tabs").append(tabs_title);
            tabs.find(".tab-content").append(tabs_content);
            ele.addClass("translated-item").hide().after(tabs);


            // encode translation
            // remove tabs added by translation
            ele.bind("trans_integrate", function(){
                var r = [];
                for(var l in inputs){
                    r.push("<!--:"+l+"-->"+inputs[l].val()+"<!--:-->");
                }
                tabs.remove();
                ele.show().val(r.join(""));
            });

        });
        return this;
    }
});