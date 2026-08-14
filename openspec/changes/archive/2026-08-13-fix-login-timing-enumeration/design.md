# Design

## D1. Spend one comparison on both branches

`has_secure_password#authenticate` is `BCrypt::Password.new(password_digest).is_password?(password)`.
The missing-user branch now does the same shape of work against a fixed dummy digest:

```ruby
def cama_password_matches?(user, password)
  return user.authenticate(password) if user

  BCrypt::Password.new(TIMING_EQUALIZER_DIGEST).is_password?(password.to_s)
  false
end
```

so the wall-clock cost of "no such username" tracks the cost of "wrong password", removing the oracle.

## D2. Precomputed dummy digest

`TIMING_EQUALIZER_DIGEST = BCrypt::Password.create('cama-login-timing-equalizer').to_s.freeze` is a
class constant computed once at load, in the current environment's bcrypt cost (so its `is_password?`
cost matches real users' digests in that same environment). The dummy path calls only `is_password?`
per request — the same per-request work `authenticate` does — not `create`, which would add salt
generation the real path lacks.

## D3. Testing

The equalization is asserted deterministically, not by wall-clock time: `is_password?` (the actual
hash comparison) is invoked on a missing-username login. On master that count is zero — building the
failed-login user computes a digest via `create` but never compares one — so the example fails without
the fix. A second example confirms a real user still logs in with the correct password.
