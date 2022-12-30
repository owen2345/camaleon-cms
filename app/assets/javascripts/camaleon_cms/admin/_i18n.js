// This library provide a helper to recover current translation
// Note: To use this you will need load js translations like this:
// <script> var I18n_data = <%= I18n.backend.send(:translations)[current_locale.to_sym][:admin][:js].to_json.html_safe %> </script>

// return translation of a key
// sample: I18n('button.edit', 'Editar %{title}', {title: 'Articulo'})  ==> Edit
// return String with the translation
// default_val: (String) this value is returned if there is no exist translation for key
// if default_val is empty, will be returned the last key titleized
// data: (hash) replacement values in the value, sample: {title: 'my title'}
// eslint-disable-next-line no-unused-vars
const I18n = function(key, defaultVal, data) {
  let res = ''
  const evaluate = eval

  try { res = evaluate('I18n_data.' + key) } catch (e) {}
  if (!res) res = defaultVal || ('' + key.split('.').pop()).titleize()

  // replacements
  data = data || {}
  for (key in data)
    res = res.replace('%{' + key + '}', data[key])

  return res
}

// helper to convert not found translations key into titleized string
// eslint-disable-next-line no-extend-native
String.prototype.titleize = function() {
  const words = this.replace(/_/g, ' ').split(' ')
  const array = []
  for (let i = 0; i < words.length; ++i)
    array.push(words[i].charAt(0).toUpperCase() + words[i].toLowerCase().slice(1))

  return array.join(' ')
}
