# 🧪 jQuery 3 Migration — Browser Test Plan

Server: `http://localhost:3005` — login: `admin` / `admin123`

**Before starting — open DevTools Console (F12) — watch for red jQuery errors throughout testing.**

---

## 1. 🖼️ Media Manager (CRITICAL — 8 fixes affected)

**Where:** Admin → Content → Media (or Post Editor → Add Media)

- [ ] Upload a file (image) — tests patched jQuery Form + Upload File
- [ ] Click uploaded file → open edit view — tests `.on('load')` (was `.load()`)
- [ ] Delete a file — tests `.fail()` (was `.error()`)
- [ ] Scroll the file list — tests `.on('scroll')` (was `.scroll()`)
- [ ] Create a folder, navigate into it, go back — tests `.on('navigate_to')` / `.on('update_breadcrumb')` (was `.bind()`)
- [ ] Insert media into a post — tests `.on('add_file')` (was `.bind()`)

**Affected files:** `_media_manager.js` — 8 of 18 total fixes

---

## 2. 📝 Post Editor + Tag Editor (CRITICAL — 10 fixes affected)

**Where:** Admin → Content → New Post

- [ ] Enter tags in tagEditor field (right sidebar) — tests patched tagEditor v1.0.21 (`.bind()` → `.on()`, `$.trim()` → `.trim()`)
- [ ] Add a tag, remove a tag, edit a tag
- [ ] Enter URL slug — tests jQuery slugify
- [ ] Scroll the page with a long post — tests `.on('scroll')` in `_post.js`
- [ ] Resize browser window — tests `.on('resize')` in `_post.js`
- [ ] Save post → verify tags saved correctly (tests `JSON.parse` replacing `$.parseJSON`)

**Affected files:** `_post.js` — 3 fixes, `_jquery.tag-editor.js` — 7 patches

---

## 3. 🔧 Custom Fields (jQuery UI sortable + datepicker — 4 fixes)

**Where:** Admin → Content → Post Types → Custom Fields

- [ ] Add a Custom Field Group → drag & drop fields to reorder — tests jQuery UI `.sortable()` (upgraded to 1.13.3)
- [ ] Add a Date field → pick a date — tests jQuery UI `.datepicker()`
- [ ] Delete a field (× button) — tests `.on("click", '.actions .fa-times')` (was `.delegate()`)
- [ ] Save field group → verify values — tests `JSON.parse` (was `$.parseJSON`)
- [ ] Create a field-group and add multiple elements — tests `.on('update_custom_group_number')` (was `.bind()`)

**Affected files:** `_custom_fields.js` — 4 fixes, jQuery UI 1.13.3

---

## 4. 📋 Navigation Menu (jQuery UI sortable)

**Where:** Admin → Appearance → Menus

- [ ] Create a new menu
- [ ] Add menu items (Pages, Posts, Categories)
- [ ] Drag menu items to reorder — tests jQuery UI `.sortable()`
- [ ] Create a nested sub-item (drag right) — tests jQuery Nestable
- [ ] Save menu

**Affected files:** `nav_menu.js`, jQuery Nestable, jQuery UI sortable

---

## 5. 🌐 Translator (multilingual)

**Where:** Admin → Settings → General (if multiple languages enabled)

- [ ] Switch language in admin panel
- [ ] Edit a translation string — tests `.on('change change_in')` (was `.bind()`)
- [ ] Verify translation integration — tests `.on("trans_integrate")` (was `.bind()`)

**Affected files:** `_translator.js` — 2 fixes

---

## 6. 📄 Widgets & Sidebar (jQuery UI sortable)

**Where:** Admin → Appearance → Widgets

- [ ] Drag a widget to sidebar — tests jQuery UI `.sortable()` + `.draggable()`
- [ ] Reorder widgets

---

## 7. ⚙️ Settings Pages (jQuery UI tooltip)

**Where:** Admin → Settings → any settings page

- [ ] Hover over tooltip icons — tests jQuery UI `.tooltip()`
- [ ] Switch settings tabs/sections

---

## Priority Summary

| Priority | Page               | Fixes affected      |
|----------|--------------------|---------------------|
| 🔴 P0    | Media Manager      | 8 fixes             |
| 🔴 P0    | Post Editor + Tags | 10 fixes            |
| 🟡 P1    | Custom Fields      | 4 fixes + jQuery UI |
| 🟡 P1    | Navigation Menus   | jQuery UI sortable  |
| 🟢 P2    | Translator         | 2 fixes             |
| 🟢 P2    | Widgets, Settings  | jQuery UI widgets   |

**Pass criteria:** Console clean (no jQuery errors) + all actions above work correctly.
