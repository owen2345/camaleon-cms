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
  rules: {
    'space-before-function-paren': ['error', 'never'],
    curly: ['error', 'multi-or-nest']
  }
}
