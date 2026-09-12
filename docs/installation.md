# Installing Camaleon CMS

These are the current installation steps for Camaleon CMS. (The "updated installation steps" link on
camaleon.website points here.)

## Requirements

- Ruby and Rails versions per the project's `.tool-versions` and `Gemfile`.
- ImageMagick (for media processing).

## Steps

1. **Create your Rails project** (skip if you already have one):

   ```bash
   rails new my_project
   cd my_project
   ```

2. **Add the gem** to your `Gemfile`:

   ```ruby
   gem "camaleon_cms"
   # or the latest development version:
   # gem "camaleon_cms", github: "owen2345/camaleon-cms"
   ```

3. **Install dependencies:**

   ```bash
   bundle install
   ```

4. **Run the Camaleon installer generator:**

   ```bash
   rails generate camaleon_cms:install
   ```

5. *(Optional)* Configure your CMS in `config/system.json` before continuing (see
   [Configuration settings](#configuration-settings)). `users_share_sites` in particular can only be
   changed before installation.

6. **Create the database structure:**

   ```bash
   rake camaleon_cms:generate_migrations
   # you can customize the copied migration files before running them
   rake db:migrate
   ```

7. **Start your server:**

   ```bash
   rails server
   ```

8. **Complete the web installer.** Visit `http://localhost:3000/`. With no site yet, Camaleon shows the
   installer form asking for a domain/key, a site name, a theme — **and a setup token**.

   ### The setup token

   On a fresh deploy the installer is gated by a setup token, so that a random visitor who reaches a
   public deployment first cannot complete setup. **Local installs do not need it:** a request from the
   local host (installing on `localhost`, or over an `ssh -L` tunnel) is exempt, because local access
   already proves you are on the server. Leave the token field blank in that case.

   Only a **remote** request needs the token. Provide it one of two ways:

   - Set `CAMALEON_SETUP_TOKEN` in the server environment before booting, and enter that value; or
   - Leave it unset — Camaleon generates a token on first access, writes it to
     `tmp/camaleon_setup_token` (mode `0600`), and logs its location. Read it from that file or the
     server log and enter it in the form.

   The token stops working once a site exists. (The loopback exemption relies on your reverse proxy, if
   any, forwarding the real client IP via `X-Forwarded-For` — standard nginx/Apache configuration; a
   proxy that strips it would let a remote request appear local.)

9. **Save your administrator password.** The installer creates an `admin` account with a **randomly
   generated password**, shown **once** on the confirmation page (with a copy button). Save it now — it
   is not stored anywhere you can read later. When you first sign in you will be required to change it.

   If you miss the one-time display, reset the password from a Rails console on the server:

   ```bash
   rails console
   ```
   ```ruby
   u = CamaleonCms::User.find_by(username: "admin")
   u.update(password: "your-new-password", password_confirmation: "your-new-password")
   u.delete_meta("must_change_password") # optional: skip the forced-change prompt
   ```

## Configuration settings

Your app's `config/system.json` overrides the defaults in the gem's own
[`config/system.json`](../config/system.json). The file must be plain JSON, with no comments.
Restart the server after changing it.

| Setting | Gem default | Meaning |
| --- | --- | --- |
| `default_template` | `"default"` | Theme assigned to new sites. |
| `default_layout` | `"index"` | Default layout for frontend pages. |
| `default_plugins` | `["front_cache", "cama_contact_form", "attack", "cama_meta_tag"]` | Plugins installed on every new site. |
| `hooks` | `{}` | System-level hooks, in the same shape as a plugin's `hooks`. |
| `skip_format_url` | `true` | Omit the `.html` extension from frontend URLs. |
| `available_languages` | 11 locales | Languages offered on the frontend; any [rails-i18n](https://github.com/svenfuchs/rails-i18n) locale. |
| `admin_available_languages` | 11 locales | Languages offered in the admin panel. |
| `default_user_role` | `"client"` | Role given to new users. |
| `users_share_sites` | `true` | `true` shares users across all sites; `false` assigns each user to a single site. Change it only before installation. |
| `db_prefix` | `""` | Prefix for Camaleon's database table names. The install generator sets `"cama_"`. |
| `relative_url_root` | `""` | URL prefix when the app is served under a path: `"blog"` serves `http://localhost:3000/blog/`. |
| `admin_path_name` | `"admin"` | URL segment of the admin panel: `"sekret"` serves it at `http://localhost:3000/sekret/`. |
| `user_model` | `""` | Class name of a custom user model, for example one managed by Devise. |
| `media_slug_folder` | `false` | Name each site's upload folder after its slug instead of its id. |
| `auto_include_migrations` | `true` | Load the migrations of Camaleon and its plugins automatically. With `false` (the install generator's value), copy them with `rake camaleon_cms:generate_migrations`. |

## Production notes

- Serve compiled assets and precompile them:

  ```bash
  RAILS_ENV=production rake assets:precompile
  ```

- Provide `SECRET_KEY_BASE` via the environment (do not commit secrets).

- Integrating SSO or an external payment provider? The admin session flows only redirect to the site's own
  host by default. Trust a provider's host (or let a plugin vouch for a dynamic destination) via the
  off-site redirect allowlist — see [docs/security/permissions.md](security/permissions.md#security-off-site-redirect-allowlist).

## Support

- Issues: https://github.com/owen2345/camaleon-cms/issues
- Site: https://camaleon.website/
