// This library provide a helper to recover current translation
// Note: To use this you will need load js translations like this:
// <script> var I18n_data = <%= I18n.backend.send(:translations)[current_locale.to_sym][:admin][:js].to_json.html_safe %> </script>

// return translation of a key
// sample: I18n('button.edit', 'Editar %{title}', {title: 'Articulo'})  ==> Edit
// return String with the translation
// default_val: (String) this value is returned if there is no exist translation for key
// if default_val is empty, will be returned the last key titleized
// data: (hash) replacement values in the value, sample: {title: 'my title'}
var I18n = function(key, default_val, data){
    var res = '';
    try { res = eval("I18n_data." + key); }catch(e){}
    if (!res) res = default_val ? default_val : ("" + key.split(".").pop()).titleize();

    // A translation that is not a String, such as a list, has no placeholder. The caller gets it as
    // it is.
    if (typeof res !== 'string') return res;

    // replacements
    // One pass gives each placeholder its value as text. So a pattern such as $& in a value has no
    // meaning, and a placeholder that a value holds stays as it is.
    data = data || {}
    return res.replace(/%\{([^}]*)\}/g, function(placeholder, name){
        return Object.prototype.hasOwnProperty.call(data, name) ? data[name] : placeholder;
    });
}

// helper to convert not found translations key into titleized string
String.prototype.titleize = function() {
    var words = this.replace(/_/g, " ").split(' ')
    var array = []
    for (var i=0; i<words.length; ++i) {
        array.push(words[i].charAt(0).toUpperCase() + words[i].toLowerCase().slice(1))
    }
    return array.join(' ')
}