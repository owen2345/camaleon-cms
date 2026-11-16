# frozen_string_literal: true

# Types the text at the end of the content of an editor frame, such as the frame of TinyMCE. Call it in
# `within_frame`.
#
# Chrome 157 types nothing when `send_keys` goes to the body of a frame that does not have the focus.
# The click gives the frame the focus. The click also puts the caret where it clicks, so the script
# moves the caret to the end of the last node of the body.
def type_in_editor_frame(text)
  body = find('body')
  body.click
  page.execute_script(<<~JS)
    var range = document.createRange();
    range.selectNodeContents(document.body.lastChild || document.body);
    range.collapse(false);
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
  JS
  body.send_keys(text)
end
