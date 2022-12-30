module.exports = {
  env: {
    browser: true,
    commonjs: true,
    es6: true
  },
  extends: 'standard',
  overrides: [
  ],
  parserOptions: {
    ecmaVersion: 6
  },
  ignorePatterns: [
    '**/magnific.min.js',
    '**/modernizr.custom.js',
    'app/assets/javascripts/camaleon_cms/bootstrap.*',
    'app/assets/javascripts/camaleon_cms/admin/_bootstrap*',
    'app/assets/javascripts/camaleon_cms/admin/bootstrap*',
    'app/assets/javascripts/camaleon_cms/admin/introjs/*',
    'app/assets/javascripts/camaleon_cms/admin/_jquery*',
    'app/assets/javascripts/camaleon_cms/admin/jquery*',
    'app/assets/javascripts/camaleon_cms/admin/jquery_validate/*',
    'app/assets/javascripts/camaleon_cms/admin/lte/*',
    'app/assets/javascripts/camaleon_cms/admin/momentjs/*',
    'app/assets/javascripts/camaleon_cms/admin/tageditor/*',
    'app/assets/javascripts/camaleon_cms/admin/tinymce/*',
    'app/assets/javascripts/camaleon_cms/admin/_underscore.js',
    'app/assets/javascripts/camaleon_cms/admin/uploader/_cropper.*',
    'app/assets/javascripts/camaleon_cms/admin/uploader/_jquery.*'
  ],
  rules: {
    'no-eval': ['error', { allowIndirect: true }],
    'space-before-function-paren': ['error', 'never'],
    curly: ['error', 'multi-or-nest']
  },
  globals: {
    ADMIN_TRANSLATIONS: true,
    CamaGetTinymceSettings: true,
    CURRENT_LOCALE: true,
    define: true,
    I18n: true,
    InitFormValidations: true,
    hideLoading: true,
    ModalFixMultiple: true,
    OpenModal: true,
    root_admin_url: true,
    showLoading: true,
    slugFunc: true,
    tinymce: true,
    tinymce_global_settings: true
  }
}
