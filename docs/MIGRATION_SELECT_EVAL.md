# Migration Guide: select_eval Permission (v2.9.2)

## Overview

Starting with version 2.9.2, the `select_eval` custom field type requires explicit permission due to security concerns. This field type can execute arbitrary Ruby code and must be restricted to trusted users only.

## What Changed?

### Before 2.9.2
- Any user could create `select_eval` fields via API calls
- There were no explicit authorization checks on `select_eval` field creation or modification

### After 2.9.2
- Requires explicit `select_eval: 1` permission in role meta for non-admin users
- Users with the 'admin' role automatically have access through `can :manage, :all` (no role meta changes needed)
- Note: The Admin role's "Select Eval" checkbox in the UI will remain unchecked (this is expected behavior)
- Authorization enforced at model layer (works everywhere: web, console, background jobs)
- Direct model manipulation (e.g., `field.set_options`) now requires permission

## Impact Assessment

### High Impact (Action Required)
✅ **Custom roles with `custom_fields` permission**
- These roles can NO LONGER create `select_eval` fields unless explicitly granted permission
- Action: Review roles and grant `select_eval` permission to trusted users

### Medium Impact (Review Recommended)
⚠️ **Background jobs creating custom fields**
- Jobs must now set `CurrentRequest.user` and `CurrentRequest.site` before creating `select_eval` fields
- Action: Update background jobs to set user context

⚠️ **Console scripts manipulating custom fields**
- Console operations must set user context
- Action: Update scripts to use CurrentRequest

### Low Impact (Monitoring)
✓ **Users with 'admin' role** - No changes needed, these users have full access via `can :manage, :all`
  - Note: The Admin role's "Select Eval" checkbox in the UI will remain unchecked (this is expected behavior)
  - Admin access is granted through the Ability class, not through role meta
✓ **Client users** - Already restricted, no change in behavior
✓ **Web requests** - Authorization handled automatically

## Migration Steps

### Step 1: Audit Existing Usage

**Find all select_eval fields in your database:**

```ruby
# In Rails console
select_eval_fields = CamaleonCms::CustomField.all.select do |field|
  field.options[:field_key] == 'select_eval'
end

puts "Found #{select_eval_fields.count} select_eval fields:"
select_eval_fields.each do |field|
  puts "  - #{field.name} (slug: #{field.slug})"
  puts "    Command: #{field.options[:command]}"
  puts "    Group: #{field.custom_field_group&.name}"
  puts
end
```

**Find roles that might be affected:**

```ruby
# Find roles with custom_fields but without select_eval permission
CamaleonCms::UserRole.find_each do |role|
  site_id = role.site_id
  manager_meta = role.get_meta("_manager_#{site_id}", {})
  
  if manager_meta[:custom_fields] && !manager_meta[:select_eval]
    puts "Role needs update: #{role.name} (site: #{site_id})"
    puts "  Users: #{role.site.users.where(role: role.slug).count}"
  end
end
```

### Step 2: Backup Your Database

```bash
# PostgreSQL example
pg_dump your_database > backup_before_select_eval_migration_$(date +%Y%m%d).sql

# MySQL example
mysqldump your_database > backup_before_select_eval_migration_$(date +%Y%m%d).sql
```

### Step 3: Grant Permissions

**Option A: Automated rake task for Admin Roles**

```bash
# Run from your application root
bundle exec rake camaleon_cms:backfill_select_eval_permission

# This task will:
# - Find all admin roles (slug: 'admin', term_group: -1)
# - Grant them select_eval permission
# - Print progress to stdout
# - Safe to run multiple times (idempotent)
# Note: Only admin roles are updated by this task
```

**Option B: Manual via Rails console (For Custom Roles)**

```ruby
# Grant to specific non-admin role
site = CamaleonCms::Site.find(1)
role = site.user_roles.find_by(slug: 'editor')

current_meta = role.get_meta("_manager_#{site.id}", {})
updated_meta = current_meta.merge(select_eval: 1)
role.set_meta("_manager_#{site.id}", updated_meta)

puts "✓ Granted select_eval permission to #{role.name}"
```

**⚠️ Important:** The automated rake task only updates admin roles. For custom roles (e.g., 'editor', 'contributor'), you must manually grant `select_eval` permission using Option B or Option C.

**Option C: Via Admin UI**

1. Log in as an admin user
2. Navigate to: **Settings → User Roles**
3. Click **Edit** on the role you want to update
4. Scroll to **Manager Permissions**
5. Check the **"Select Eval"** checkbox
6. Click **Save**

### Step 4: Update Background Jobs to get the current user context

**Before:**
```ruby
class CustomFieldJob < ApplicationJob
  def perform(site_id, group_id)
    site = CamaleonCms::Site.find(site_id)
    group = site.custom_field_groups.find(group_id)
    
    # This will now raise CanCan::AccessDenied
    group.add_field(
      { name: 'Dynamic', slug: 'dynamic' },
      { field_key: 'select_eval', command: 'some_method' }
    )
  end
end
```

**After:**
```ruby
class CustomFieldJob < ApplicationJob
  def perform(site_id, group_id, user_id)
    site = CamaleonCms::Site.find(site_id)
    group = site.custom_field_groups.find(group_id)
    user = CamaleonCms::User.find(user_id)
    
    # Set user context for authorization
    CurrentRequest.user = user
    CurrentRequest.site = site
    
    begin
      group.add_field(
        { name: 'Dynamic', slug: 'dynamic' },
        { field_key: 'select_eval', command: 'some_method' }
      )
    ensure
      # Clean up (optional, auto-resets between requests anyway)
      CurrentRequest.reset
    end
  end
end
```

### Step 5: Update Console Scripts to get the current user context

**Before:**
```ruby
# dangerous_script.rb
site = CamaleonCms::Site.first
group = site.custom_field_groups.first

# Will now fail with CanCan::AccessDenied
group.add_field(
  { name: 'Test', slug: 'test' },
  { field_key: 'select_eval', command: 'test_command' }
)
```

**After:**
```ruby
# safe_script.rb
site = CamaleonCms::Site.first
admin_user = site.users.admin_scope.first # Get an admin user

# Set context
CurrentRequest.user = admin_user
CurrentRequest.site = site

# Now authorized
group = site.custom_field_groups.first
group.add_field(
  { name: 'Test', slug: 'test' },
  { field_key: 'select_eval', command: 'test_command' }
)

# Cleanup
CurrentRequest.reset
```

### Step 6: Test in Staging

**Test checklist:**

- [ ] Users with 'admin' role can create `select_eval` fields via UI (despite unchecked checkbox on Admin role)
- [ ] Custom roles with permission can create `select_eval` fields
- [ ] Custom roles without permission are blocked (see error message)
- [ ] Background jobs complete successfully
- [ ] Console scripts execute without errors
- [ ] Existing `select_eval` fields continue to work
- [ ] Performance is acceptable (authorization checks are fast)

**Smoke test script:**

```ruby
# Run in Rails console (staging environment)

# Test 1: Admin can create
admin = CamaleonCms::User.admin_scope.first
site = admin.site
CurrentRequest.user = admin
CurrentRequest.site = site

group = site.custom_field_groups.create!(
  name: 'Test Group', 
  slug: 'test_group',
  object_class: 'Site',
  objectid: site.id
)

field = group.add_field(
  { name: 'Test Field', slug: 'test_field' },
  { field_key: 'select_eval', command: 'test' }
)

puts field.present? ? "✓ Admin test passed" : "✗ Admin test FAILED"

# Test 2: Non-admin without permission is blocked
non_admin = site.users.where.not(role: 'admin').first
CurrentRequest.user = non_admin

begin
  group.add_field(
    { name: 'Blocked', slug: 'blocked' },
    { field_key: 'select_eval', command: 'blocked' }
  )
  puts "✗ Permission test FAILED (should have been blocked)"
rescue CanCan::AccessDenied
  puts "✓ Permission test passed (correctly blocked)"
end

# Cleanup
group.destroy
CurrentRequest.reset
```

### Step 7: Deploy to Production

1. **Schedule maintenance window** (optional, no downtime required)
2. **Deploy the update:**
   ```bash
   git pull origin main
   bundle install
   bundle exec rake assets:precompile
   # Restart your application server
   ```
3. **Run the backfill task:**
   ```bash
   bundle exec rake camaleon_cms:backfill_select_eval_permission
   ```
4. **Monitor logs** for any `CanCan::AccessDenied` errors
5. **Verify** critical workflows still function

## Troubleshooting

### Issue: Users report "Not authorized" errors

**Symptom:**
```
CanCan::AccessDenied: Not authorized to create select_eval fields
```

**Solution:**
Grant the user's role explicit `select_eval` permission (see Step 3)

### Issue: Background job fails with authorization error

**Symptom:**
```ruby
# In job logs
CanCan::AccessDenied: Not authorized to create select_eval fields
```

**Solution:**
Update job to set `CurrentRequest.user` and `CurrentRequest.site` (see Step 4)

### Issue: Console script fails

**Symptom:**
```ruby
# In console
CanCan::AccessDenied: Not authorized to create select_eval fields
```

**Solution:**
Set user context before operations (see Step 5):
```ruby
CurrentRequest.user = admin_user
CurrentRequest.site = site
```

### Issue: Permission granted but still blocked

**Possible causes:**

1. **Stale ability cache in tests:**
   ```ruby
   # Reset cached ability after changing role meta
   model.reset_ability
   ```

2. **Wrong site_id in role meta:**
   ```ruby
   # Verify the meta key matches current site
   role.get_meta("_manager_#{current_site.id}", {})
   ```

3. **User context not set:**
   ```ruby
   # Ensure CurrentRequest is set
   CurrentRequest.user = user
   CurrentRequest.site = site
   ```

## Security Best Practices

### 1. Principle of Least Privilege
- Only grant `select_eval` permission to users who absolutely need it
- Prefer alternative field types (select, radio, checkbox) when possible

### 2. Regular Audits
```ruby
# Audit users with select_eval permission
CamaleonCms::Site.find_each do |site|
  roles_with_permission = site.user_roles.select do |role|
    role.get_meta("_manager_#{site.id}", {})[:select_eval] == 1
  end
  
  roles_with_permission.each do |role|
    users = site.users.where(role: role.slug)
    puts "Site: #{site.name}"
    puts "Role: #{role.name}"
    puts "Users: #{users.pluck(:username).join(', ')}"
    puts
  end
end
```

### 3. Code Review
- Review all `select_eval` command values before deploying
- Audit commands that could access sensitive data or perform destructive operations

### 4. Monitoring
```ruby
# Add to your monitoring/logging
Rails.logger.warn "select_eval field created: #{field.slug} by user: #{CurrentRequest.user&.username}"
```

## Rollback Plan

If you need to temporarily disable the new restriction:

**⚠️ NOT RECOMMENDED** - Only use in emergency situations

```ruby
# Monkey-patch in config/initializers/disable_select_eval_check.rb
# This removes authorization checks (INSECURE!)

module CamaleonCms
  class CustomFieldGroup
    def add_manual_field(item, options)
      # Skip authorization check
      c = get_field(item[:slug] || item['slug'])
      return c if c.present?

      field_item = fields.new(item)
      if field_item.save
        field_item.set_options(options)
        auto_save_default_values(field_item, options)
      end
      field_item
    end
  end
end
```

**Better alternative:** Grant permission to affected roles rather than disabling security

## Support

- **Documentation:** [README.md Security Section](../README.md#security-select_eval-custom-field-type)
- **Changelog:** [CHANGELOG.md v2.9.2](../CHANGELOG.md)
- **Issues:** https://github.com/owen2345/camaleon-cms/issues
- **Community:** https://camaleon.website/

## Timeline

- **v2.9.1 and earlier:** No select_eval restrictions
- **v2.9.2 (March 29, 2026):** select_eval permission required
- **Recommended migration deadline:** Within 30 days of upgrading to v2.9.2
