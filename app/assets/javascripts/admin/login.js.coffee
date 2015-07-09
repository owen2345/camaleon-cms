$ ->
  f = $("#login_user")
  f.submit( ->
    if(f.valid?())
      e = f.find("input[name='user[password]']");
      e.val(GibberishAES.enc(e.val(), kk));
  ).validate();