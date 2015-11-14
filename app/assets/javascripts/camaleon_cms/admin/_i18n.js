// This library provide a helper to recover current translation
// Note: To use this you will need load js translations like this:
// <script> var I18n_data = <%= I18n.backend.send(:translations)[current_locale.to_sym][:admin][:js].to_json.html_safe %> </script>

// return translation of a key
// sample: I18n('button.edit')  ==> Edit
// return String with the translation
// default_val: (String) this value is returned if there is no exist translation for key
// if default_val is empty, will be returned the last key titleized
var I18n = function(key, default_val){
    try {
        var res = eval("I18n_data." + key);
        if (!res) res = default_val ? default_val : ("" + key.split(".").pop()).titleize();
    }catch(e){
        var res = (""+key.split(".").pop()).titleize();
    }
    return res;
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