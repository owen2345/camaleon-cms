/* eslint-env jquery */
jQuery(function($) {
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
     * @param defaultLanguage => not important (deprecated)
     * @returns {$.fn.Translatable}
     * @constructor
     * select tag fix: save translated value in data-value
     */
  let translatorCounter = 1
  $.fn.Translatable = function(languages, defaultLanguage) {
    languages = languages || ADMIN_TRANSLATIONS // rescue from admin variable
    defaultLanguage = defaultLanguage || languages[0]
    const self = $(this).not('.translated-item, .translate-item')

    // decode translations
    // text: string containing translations
    // language(optional): get translation value for this language
    // return a hash of translations
    function getTranslations(text, language) {
      const translationsPerLocale = {}
      let res = ''
      /* eslint-disable-next-line eqeqeq */
      if (!text || text.trim().search('<!--') != 0) { // not translated string
        languages.forEach(function(i) { translationsPerLocale[languages[i]] = text })

        res = translationsPerLocale
      } else { // has translations
        const splitted = text.split('<!--:-->')
        splitted.forEach(function(i) {
          const str = splitted[i]
          const mAtch = str.trim().match(/^<!--:([\w||-]{2,5})/)
          if (mAtch && mAtch.length === 2) {
            mAtch[1] = mAtch[1].replace('--', '')
            translationsPerLocale[mAtch[1]] = str.replace('<!--:' + mAtch[1] + '-->', '')
          }
        })
        res = translationsPerLocale
      }
      if (language)
        return getTranslation(res, language)
      else
        return res
    }

    // get translation for a language
    function getTranslation(translations, language) {
      return language in translations ? translations[language] : (languages[0] in translations ? translations[languages[0]] : '')
    }

    // if translations is a uniq language
    if (languages.length < 2) {
      self.each(function() { $(this).val(getTranslations($(this).val(), languages[0])) })
      return this
    }

    self.each(function() {
      let ele = $(this)
      const tabsTitle = []
      const tabsContent = []
      const translations = getTranslations(ele.is('select') ? ele.data('value') : ele.val()); const inputs = {}
      const classGroup = ele.parent().hasClass('form-group') ? '' : 'form-group'
      // decoding languages
      languages.forEach(function(ii) {
        const l = languages[ii]
        const key = 'translation-' + l + '-' + translatorCounter
        tabsTitle.push(
          /* eslint-disable-next-line eqeqeq */
          '<li role="presentation" class="pull-right ' + (ii == 0 ? 'active' : '') + '"><a href="#pane-' + key + '" role="tab" data-toggle="tab">' + l.titleize() + '</a></li>'
        )
        const clone = ele.clone(true)
          .attr({ id: key, name: key, 'data-name': key, 'data-translation_l': l, 'data-translation': 'translation-' + l })
          .addClass('translate-item').val(getTranslation(translations, l))
        if (ii > 0 && !clone.hasClass('required_all_langs'))
          clone.removeClass('required') // to permit enter empty values for secondary languages
        inputs[l] = clone
        clone.wrap(
          /* eslint-disable-next-line eqeqeq */
          "<div class='tab-pane " + classGroup + ' trans_tab_item ' + (ii == 0 ? 'active' : '') + "' id='pane-" + key + "'/>"
        )
        tabsContent.push(clone.parent())
        translatorCounter++
        // Auto Update Translates
        clone.bind('change change_in', function() {
          const r = []
          for (const l in inputs)
            r.push('<!--:' + l + '-->' + inputs[l].val() + '<!--:-->')

          ele.val(r.join(''))
          if ((typeof tinymce === 'object') && ele.is('textarea') && ele.attr('id') && tinymce.get(ele.attr('id')))
            tinymce.get(ele.attr('id')).setContent(r.join(''))
        })
      })

      // creating tabs per translation
      const tabs = $('<div class="trans_panel" role="tabpanel"><ul class="nav nav-tabs" role="tablist"></ul><div class="tab-content"></div></div>')
      tabs.find('.nav-tabs').append(tabsTitle.reverse())
      tabs.find('.tab-content').append(tabsContent)

      // unknown fields (fix for select fields)
      if (ele.is('select')) {
        const repField = $('<input type="hidden">').attr({ class: ele.attr('class'), name: ele.attr('name') })
        ele.replaceWith(repField)
        ele = repField
        tabsContent[0].find('.translate-item').trigger('change')
      }

      ele.addClass('translated-item').hide().after(tabs)
      // ele.data("tabs_content", tabsContent)
      ele.data('translation_inputs', inputs)

      // encode translation
      // remove tabs added by translation
      ele.bind('trans_integrate', function() {
        const r = []
        for (const l in inputs)
          r.push('<!--:' + l + '-->' + inputs[l].val() + '<!--:-->')

        ele.show().val(r.join(''))
        if ((typeof tinymce === 'object') && ele.is('textarea') && ele.attr('id') && tinymce.get(ele.attr('id')))
          tinymce.get(ele.attr('id')).setContent(r.join(''))
        tabs.remove()
        $(this).removeClass('translated-item')
      })
    })
    return this
  }
})
