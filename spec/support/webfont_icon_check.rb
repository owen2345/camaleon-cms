# require 'rails_helper'

def webfont_icon_fetch_status(icon_class, filnam_distinct_part, filnam_extension)
  icon_font_faces = page.execute_script(<<~JS, icon_class)
    let calendarIcon = document.getElementsByClassName(arguments[0])[0];
    let fontFamily = getComputedStyle(calendarIcon)['font-family']
    const allCSS = [...document.styleSheets]
      .flatMap(styleSheet => {
        try {
          return [...styleSheet.cssRules].map(rule => {
              let ruleText = rule.cssText
              if(ruleText.startsWith('@font-face') && ruleText.includes(fontFamily))
                return ruleText
            }
          ).filter(Boolean)
        } catch (e) {
          console.log('Access to stylesheet %s is denied. Ignoring...', styleSheet.href)
        }
      })
    return allCSS
  JS

  # First find is iterating through the array of font faces, 2nd - through the split chunks of found font face
  url_str = icon_font_faces.find { |str| str.include?(filnam_distinct_part) && str.include?(filnam_extension) }.split
                           .find { |str| str.include?(filnam_distinct_part) && str.include?(filnam_extension) }
                           .delete_prefix('url("')
                           .chomp('")')

  page.execute_script(<<~JS)
    let xhr = new XMLHttpRequest();
    xhr.open('GET', '#{url_str}', false);
    xhr.send();
    return xhr.status;
  JS
end
