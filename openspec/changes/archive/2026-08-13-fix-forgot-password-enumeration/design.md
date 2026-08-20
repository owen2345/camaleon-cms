# Design

## D1. One response for both branches

The enumeration came from branching the user-visible outcome on account existence. The fix collapses
both branches to the same observable result — a redirect to the login page with one neutral
`flash[:notice]` — and simply performs the side effect (send the email) only when there is an account
to send to:

```ruby
send_password_reset_email(@user) if @user.present? && cama_password_reset_email_allowed?(@user)
flash[:notice] = t('camaleon_cms.admin.login.message.password_reset_requested')
redirect_to cama_admin_login_path
```

A requester can no longer tell a registered address from an unregistered one by the message, the
status, or whether the page redirected.

## D2. Per-account send cooldown

`cama_password_reset_email_allowed?` returns true only when no reset was sent within
`PASSWORD_RESET_EMAIL_COOLDOWN` (5 minutes), read from `password_reset_sent_at`. This throttles the one
resource the endpoint spends on a *known* address — the outbound email — without adding a new store:
the timestamp already exists and already governs the 2h token window. A legitimate user who did not
receive the mail can retry after the window; the earlier token remains valid meanwhile.

The cooldown is per account, not per IP: it stops a flood of a single inbox regardless of source IP,
which the shared per-IP login throttle would not (an attacker rotating IPs). Credential-guessing rate
limits are a separate, already-shipped control.

## D3. Testing

`spec/requests/security/forgot_password_enumeration_spec.rb`: a known and an unknown email both redirect
to login with a neutral notice and no error (the unknown-email case fails on master, which renders an
error); and two reset requests for the same account within the window send only one email (master sends
two), asserted by spying on `send_email`.
