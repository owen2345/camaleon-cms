# Change Log

## [2.5.3.1](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2020-08-04)
- Use non-digest-assets gem for using 3rd party assets (fix missing not found glyphicon fonts)

## [2.5.3](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2020-07-02)
- Russian locale additions and fixes
- Fix deprecation warnings present in Ruby 2.7 and Rails 6.0
- Fix admin error path
- Process shortcodes when evaluating widgets
- Add canonical option to seo
- Theme template include i18n
- Upgrade Bootstrap from 3.3.4 to 3.4.1

## [2.5.0](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2020-01-08)
- feat: sprockets 4 support
- feat: for sprockets 4, generate config manifest to precompile
- feat: precompile assets only for sprockets <= 3x
- fix: Rails 6 missing to_s for session id
- fix: preview error 

## [2.4.6.7](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2019-08-05)
- Fixed rails 6 bundle install error
- Added https to default uri options
- Use default page if no other pages exist

## [2.4.6.4](https://github.com/owen2345/camaleon-cms/tree/2.4.6.6) (2019-08-05)
- Fixed posts slug index length
- Added support for rails 6
- Improved themes list UI

## [2.4.6.4](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Updated aws-sdk dependency to include only s3 needed dependency available in aws-sdk v3+

## [2.4.6.3](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Fixed cache plugin to support several domains/hosts

## [2.4.6.2](https://github.com/owen2345/camaleon-cms/tree/2.4.6.1) (2019-05-02)
- Fixed route errors for error for non static error pages

## [2.4.6.1](https://github.com/owen2345/camaleon-cms/tree/2.4.6.0) (2019-04-16)
- Fixed s3 nil error

## [2.4.6.0](https://github.com/owen2345/camaleon-cms/tree/2.4.6.0) (2019-04-05)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.14...2.4.6.0)

- Cannot create site on Rails 6 [\#884](https://github.com/owen2345/camaleon-cms/issues/884)
- Loosen CanCanCan version restriction [\#886](https://github.com/owen2345/camaleon-cms/pull/886) ([brian-kephart](https://github.com/brian-kephart))
- Set config.belongs\_to\_required\_by\_default = false for Rails 6 [\#885](https://github.com/owen2345/camaleon-cms/pull/885) ([brian-kephart](https://github.com/brian-kephart))
- Use implicit return on case statement assignment [\#858](https://github.com/owen2345/camaleon-cms/pull/858) ([chukitow](https://github.com/chukitow))
- Fixed update posts to exclude slug verification in trash posts
- Updated min version of contact form plugin

## [2.4.5.14](https://github.com/owen2345/camaleon-cms/tree/2.4.5.14) (2019-03-24)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.13...2.4.5.14)

**Closed issues:**

- Issue in production mode [\#882](https://github.com/owen2345/camaleon-cms/issues/882)
- Missing template themes/\[themename\]/views/single [\#875](https://github.com/owen2345/camaleon-cms/issues/875)

**Merged pull requests:**

- Use headless Chrome instead of Capybara-Webkit [\#881](https://github.com/owen2345/camaleon-cms/pull/881) ([brian-kephart](https://github.com/brian-kephart))
- apply fix in \#878 when site has a custom error page [\#880](https://github.com/owen2345/camaleon-cms/pull/880) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.5.13](https://github.com/owen2345/camaleon-cms/tree/2.4.5.13) (2019-03-11)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.12...2.4.5.13)

**Closed issues:**

- Contact form throws error on submission [\#877](https://github.com/owen2345/camaleon-cms/issues/877)
- "the\_avatar" showing as undefined. [\#874](https://github.com/owen2345/camaleon-cms/issues/874)
- PG::UndefinedFunction: ERROR: function lower\(boolean\) when searching in admin panel [\#866](https://github.com/owen2345/camaleon-cms/issues/866)
- SEO field is not saving for specific custom group [\#863](https://github.com/owen2345/camaleon-cms/issues/863)
- module CamaleonCms::UploaderHelper - north\_east north\_west params [\#860](https://github.com/owen2345/camaleon-cms/issues/860)
- Camaleon CMS in Rails 5, adding a new post the form disappear when updating the category [\#859](https://github.com/owen2345/camaleon-cms/issues/859)
- Intro Popups in the Admin Screen [\#781](https://github.com/owen2345/camaleon-cms/issues/781)

**Merged pull requests:**

- Restrict sqlite3 version due to Rails incompatibility [\#879](https://github.com/owen2345/camaleon-cms/pull/879) ([brian-kephart](https://github.com/brian-kephart))
- Fix 500 errors when missing theme CSS is requested [\#878](https://github.com/owen2345/camaleon-cms/pull/878) ([brian-kephart](https://github.com/brian-kephart))
- Revert "fixed S3 bucket options merge error" [\#873](https://github.com/owen2345/camaleon-cms/pull/873) ([owen2345](https://github.com/owen2345))
- fixed S3 bucket options merge error [\#872](https://github.com/owen2345/camaleon-cms/pull/872) ([superchell](https://github.com/superchell))
- changed aws-sdk dependency version for ActiveStorage support [\#870](https://github.com/owen2345/camaleon-cms/pull/870) ([superchell](https://github.com/superchell))
- Fix query builder bug when params\[:q\] specified [\#868](https://github.com/owen2345/camaleon-cms/pull/868) ([blaszczakphoto](https://github.com/blaszczakphoto))
- fixed url in hreflang link [\#831](https://github.com/owen2345/camaleon-cms/pull/831) ([superchell](https://github.com/superchell))

## [2.4.5.12](https://github.com/owen2345/camaleon-cms/tree/2.4.5.12) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.11...2.4.5.12)

**Closed issues:**

- Broken Preview Function for Draft Post [\#861](https://github.com/owen2345/camaleon-cms/issues/861)

## [2.4.5.11](https://github.com/owen2345/camaleon-cms/tree/2.4.5.11) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/camaleon_cms-2.4.5.11.gem...2.4.5.11)

## [camaleon_cms-2.4.5.11.gem](https://github.com/owen2345/camaleon-cms/tree/camaleon_cms-2.4.5.11.gem) (2018-12-04)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.10...camaleon_cms-2.4.5.11.gem)

**Closed issues:**

- Some errors in apache proxy  [\#844](https://github.com/owen2345/camaleon-cms/issues/844)

**Merged pull requests:**

- image custom field remove button [\#857](https://github.com/owen2345/camaleon-cms/pull/857) ([superchell](https://github.com/superchell))

## [2.4.5.10](https://github.com/owen2345/camaleon-cms/tree/2.4.5.10) (2018-10-26)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.7...2.4.5.10)

**Closed issues:**

- How to override \_data.js [\#855](https://github.com/owen2345/camaleon-cms/issues/855)
- Update the Website [\#848](https://github.com/owen2345/camaleon-cms/issues/848)
- How can I add new language ? [\#846](https://github.com/owen2345/camaleon-cms/issues/846)
- Site is down [\#840](https://github.com/owen2345/camaleon-cms/issues/840)
- Shortcode yield content  [\#838](https://github.com/owen2345/camaleon-cms/issues/838)
- Problems loading the Documentation [\#837](https://github.com/owen2345/camaleon-cms/issues/837)
- install problem [\#833](https://github.com/owen2345/camaleon-cms/issues/833)
- Route problem [\#827](https://github.com/owen2345/camaleon-cms/issues/827)
- Multilanguage and varchar field length issue [\#820](https://github.com/owen2345/camaleon-cms/issues/820)
- Test fix prevents testing plugins [\#817](https://github.com/owen2345/camaleon-cms/issues/817)
- Support for old Ruby/Rails versions [\#813](https://github.com/owen2345/camaleon-cms/issues/813)
- Images are not being created in different versions [\#808](https://github.com/owen2345/camaleon-cms/issues/808)
- Uploading image doesn't auto orient [\#786](https://github.com/owen2345/camaleon-cms/issues/786)
- post order problem [\#783](https://github.com/owen2345/camaleon-cms/issues/783)
- Cant create theme without sudo [\#771](https://github.com/owen2345/camaleon-cms/issues/771)
- Sprockets::FileNotFound in CamaleonCms::AdminController\#dashboard [\#763](https://github.com/owen2345/camaleon-cms/issues/763)
- AWS Media doesn't scale [\#757](https://github.com/owen2345/camaleon-cms/issues/757)
- Unable to add attachments to custom content type [\#753](https://github.com/owen2345/camaleon-cms/issues/753)
- Contact form throws error on submission [\#729](https://github.com/owen2345/camaleon-cms/issues/729)
- We're sorry, but something went wrong. If you are the application owner check the logs for more information. [\#728](https://github.com/owen2345/camaleon-cms/issues/728)
- Hi Owen [\#727](https://github.com/owen2345/camaleon-cms/issues/727)
- How to implement Paper Trials in Camaleon CMS? [\#725](https://github.com/owen2345/camaleon-cms/issues/725)
- Cannot add custom fields to custom user [\#719](https://github.com/owen2345/camaleon-cms/issues/719)
- Copy from Word into Rich editor? [\#717](https://github.com/owen2345/camaleon-cms/issues/717)
- Default user\_model? [\#715](https://github.com/owen2345/camaleon-cms/issues/715)
- Media gallery uses different path than actual path [\#714](https://github.com/owen2345/camaleon-cms/issues/714)
- Serve camaleon assets from cloudfront? [\#709](https://github.com/owen2345/camaleon-cms/issues/709)
- NoMethodError in CamaleonCms::Admin::InstallersController\#save [\#702](https://github.com/owen2345/camaleon-cms/issues/702)
- Redirect loop with existin devise model [\#699](https://github.com/owen2345/camaleon-cms/issues/699)
- Tags created with tag form do not appear [\#695](https://github.com/owen2345/camaleon-cms/issues/695)
- Tags for multiple post types [\#694](https://github.com/owen2345/camaleon-cms/issues/694)
- NoMethodError in CamaleonCms::Admin\#dashboard [\#687](https://github.com/owen2345/camaleon-cms/issues/687)
- Comment's submit flash messages doesn't shows [\#686](https://github.com/owen2345/camaleon-cms/issues/686)
- Error action save\_comment [\#685](https://github.com/owen2345/camaleon-cms/issues/685)
- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#684](https://github.com/owen2345/camaleon-cms/issues/684)
- Authoring Posts plugin shows all users instead of current\_site.users [\#681](https://github.com/owen2345/camaleon-cms/issues/681)
- Contact Form Item not translate to chinese [\#606](https://github.com/owen2345/camaleon-cms/issues/606)
- Feature request [\#597](https://github.com/owen2345/camaleon-cms/issues/597)
- warning: already initialized constant JSON::\* [\#596](https://github.com/owen2345/camaleon-cms/issues/596)
- Can I migrate existing pages from BrowserCMS to CamaleonCMS? [\#595](https://github.com/owen2345/camaleon-cms/issues/595)
- I18n.backend translations not working [\#593](https://github.com/owen2345/camaleon-cms/issues/593)
- json pagination problem [\#584](https://github.com/owen2345/camaleon-cms/issues/584)
- Asset Undefined And Testing Repo [\#579](https://github.com/owen2345/camaleon-cms/issues/579)
- Unable to install. Command `gem 'camaleon\_cms'` not working. [\#573](https://github.com/owen2345/camaleon-cms/issues/573)
- Request Update Feature [\#572](https://github.com/owen2345/camaleon-cms/issues/572)
- Using Camaleon with existing database and models [\#567](https://github.com/owen2345/camaleon-cms/issues/567)
- Assign a template to a content-group global page [\#561](https://github.com/owen2345/camaleon-cms/issues/561)
- Bootstrap Sass variable and Mixin are also undefined with Camaleon CMS version 2.4 [\#560](https://github.com/owen2345/camaleon-cms/issues/560)
- Assets conflict [\#557](https://github.com/owen2345/camaleon-cms/issues/557)
- How to avoid N+1 queries in CamaleonCms? [\#556](https://github.com/owen2345/camaleon-cms/issues/556)
- Urgently BUG: Camaleon Version 2.1.1 does not upload file to S3 [\#555](https://github.com/owen2345/camaleon-cms/issues/555)
- Multiple Language: Editor field of other language doesn't show container body to input data [\#552](https://github.com/owen2345/camaleon-cms/issues/552)
- Integrate with an existing authentication system [\#545](https://github.com/owen2345/camaleon-cms/issues/545)
- Rspec tests are failing  [\#540](https://github.com/owen2345/camaleon-cms/issues/540)
- Server migration and image url problem [\#538](https://github.com/owen2345/camaleon-cms/issues/538)
- How to add leadpages to Camaleon [\#535](https://github.com/owen2345/camaleon-cms/issues/535)
- Multi Site: How to assign users to specific sites only? [\#525](https://github.com/owen2345/camaleon-cms/issues/525)
- Image uploader caching is not scalable [\#518](https://github.com/owen2345/camaleon-cms/issues/518)
- Creating a folder in image uploader should clear cache [\#517](https://github.com/owen2345/camaleon-cms/issues/517)
- Theme settings missing [\#513](https://github.com/owen2345/camaleon-cms/issues/513)
- Favicon Causes DNS issues.  [\#510](https://github.com/owen2345/camaleon-cms/issues/510)
- Image upload enhancements [\#509](https://github.com/owen2345/camaleon-cms/issues/509)
- Dynamic URLs for pagination [\#505](https://github.com/owen2345/camaleon-cms/issues/505)
- Test suite does not run [\#470](https://github.com/owen2345/camaleon-cms/issues/470)
- Setting Custom Homepage Via Theme Settings in Default Theme Not Working Correctly [\#467](https://github.com/owen2345/camaleon-cms/issues/467)
- How to create mobile app for Camaleon CMS and subdomains [\#462](https://github.com/owen2345/camaleon-cms/issues/462)
- Direction should be :asc or :desc [\#425](https://github.com/owen2345/camaleon-cms/issues/425)
- How to avoid numeric values in tags [\#403](https://github.com/owen2345/camaleon-cms/issues/403)
- NoMethodError in CamaleonCms::Frontend\#index [\#397](https://github.com/owen2345/camaleon-cms/issues/397)
- Is there a blogs json api? [\#393](https://github.com/owen2345/camaleon-cms/issues/393)
- Themes assets not found on production [\#348](https://github.com/owen2345/camaleon-cms/issues/348)
- Hang in Heroku/Dokku push-deploy [\#321](https://github.com/owen2345/camaleon-cms/issues/321)
- Add Custom field [\#319](https://github.com/owen2345/camaleon-cms/issues/319)
- Custom field types extendable by plugins [\#293](https://github.com/owen2345/camaleon-cms/issues/293)
- MIT License [\#292](https://github.com/owen2345/camaleon-cms/issues/292)
- New user role for basic info, theme setting and Contact Response [\#285](https://github.com/owen2345/camaleon-cms/issues/285)
- Specs not running [\#228](https://github.com/owen2345/camaleon-cms/issues/228)
- Pt-BR translation to admin [\#177](https://github.com/owen2345/camaleon-cms/issues/177)
- "Author Name" Confusion in SEO Settings [\#98](https://github.com/owen2345/camaleon-cms/issues/98)

**Merged pull requests:**

- Support Plugin / Theme usage and development [\#852](https://github.com/owen2345/camaleon-cms/pull/852) ([westonganger](https://github.com/westonganger))
- Fix upload to s3 for private files - Updated [\#851](https://github.com/owen2345/camaleon-cms/pull/851) ([westonganger](https://github.com/westonganger))
- Cleanup cruft in test output [\#850](https://github.com/owen2345/camaleon-cms/pull/850) ([westonganger](https://github.com/westonganger))
- Fix UX for Plugins Activate/Deactivate buttons [\#849](https://github.com/owen2345/camaleon-cms/pull/849) ([westonganger](https://github.com/westonganger))
- Update Project [\#847](https://github.com/owen2345/camaleon-cms/pull/847) ([westonganger](https://github.com/westonganger))
- Ability to search for a post by it's slug [\#841](https://github.com/owen2345/camaleon-cms/pull/841) ([tostasqb](https://github.com/tostasqb))
- fix login page logo [\#836](https://github.com/owen2345/camaleon-cms/pull/836) ([superchell](https://github.com/superchell))
- \[WIP\] Fix upload to s3 for private files [\#830](https://github.com/owen2345/camaleon-cms/pull/830) ([max2320](https://github.com/max2320))
- Add Lang Arabic in Admin Panel [\#828](https://github.com/owen2345/camaleon-cms/pull/828) ([Abd-El-Rahman-HSN](https://github.com/Abd-El-Rahman-HSN))
- Change Color MAIN NAVIGATION And Add Lang Arabic [\#826](https://github.com/owen2345/camaleon-cms/pull/826) ([Abd-El-Rahman-HSN](https://github.com/Abd-El-Rahman-HSN))
- added fix\_list\_elements parameter for TinyMCE [\#823](https://github.com/owen2345/camaleon-cms/pull/823) ([superchell](https://github.com/superchell))
- fixes owen2345/camaleon-cms\#820 [\#822](https://github.com/owen2345/camaleon-cms/pull/822) ([christianmeyer](https://github.com/christianmeyer))
- Remove TinyMCE test workaround that breaks plugin tests [\#819](https://github.com/owen2345/camaleon-cms/pull/819) ([brian-kephart](https://github.com/brian-kephart))
- added last opened folder in the media manager [\#818](https://github.com/owen2345/camaleon-cms/pull/818) ([superchell](https://github.com/superchell))
- Added translatable default value [\#816](https://github.com/owen2345/camaleon-cms/pull/816) ([superchell](https://github.com/superchell))
- Create build matrix in Travis CI and clarify supported versions [\#815](https://github.com/owen2345/camaleon-cms/pull/815) ([brian-kephart](https://github.com/brian-kephart))
- Custom fields groups of custom fields for posts belonging to the same category. [\#814](https://github.com/owen2345/camaleon-cms/pull/814) ([superchell](https://github.com/superchell))
- Cache bundle on Travis CI [\#811](https://github.com/owen2345/camaleon-cms/pull/811) ([brian-kephart](https://github.com/brian-kephart))
- Fix typos in README & gemspec [\#810](https://github.com/owen2345/camaleon-cms/pull/810) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.5.7](https://github.com/owen2345/camaleon-cms/tree/2.4.5.7) (2018-05-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5.1...2.4.5.7)

**Closed issues:**

- image versions are not created [\#805](https://github.com/owen2345/camaleon-cms/issues/805)
- Plugin tests fail [\#799](https://github.com/owen2345/camaleon-cms/issues/799)
- Redirect after subscription [\#798](https://github.com/owen2345/camaleon-cms/issues/798)
- SVG uploads failing [\#787](https://github.com/owen2345/camaleon-cms/issues/787)
- Updating custom fields does not update parent [\#785](https://github.com/owen2345/camaleon-cms/issues/785)
- Image cropper is broken [\#782](https://github.com/owen2345/camaleon-cms/issues/782)
- wildcard ssl using nginx redirects page to localhost instead of main sub-domained site [\#780](https://github.com/owen2345/camaleon-cms/issues/780)
- \[Request\] Use Travis CI [\#778](https://github.com/owen2345/camaleon-cms/issues/778)
- There should be an endpoint for rendering a 404 page [\#772](https://github.com/owen2345/camaleon-cms/issues/772)
- translation missing: en.camaleon\_cms.admin.post\_type.private [\#768](https://github.com/owen2345/camaleon-cms/issues/768)
- Page not found not giving 404 status code [\#767](https://github.com/owen2345/camaleon-cms/issues/767)
- "wrong number of arguments \(given 1, expected 0\)" when using gretel [\#765](https://github.com/owen2345/camaleon-cms/issues/765)
- Create a folder with spaces breaks image path [\#756](https://github.com/owen2345/camaleon-cms/issues/756)
- ActionController::InvalidCrossOriginRequest: Security warning [\#742](https://github.com/owen2345/camaleon-cms/issues/742)
- Feature Request: Wordpress Import [\#34](https://github.com/owen2345/camaleon-cms/issues/34)

**Merged pull requests:**

- Fix plugin generator so plugin tests pass [\#807](https://github.com/owen2345/camaleon-cms/pull/807) ([brian-kephart](https://github.com/brian-kephart))
- fixed creating uploded image versions [\#806](https://github.com/owen2345/camaleon-cms/pull/806) ([superchell](https://github.com/superchell))
- added parent id data attribute in category list [\#804](https://github.com/owen2345/camaleon-cms/pull/804) ([superchell](https://github.com/superchell))
- added id attribute in category list table tag [\#800](https://github.com/owen2345/camaleon-cms/pull/800) ([superchell](https://github.com/superchell))
- added create and update post\_type hooks [\#797](https://github.com/owen2345/camaleon-cms/pull/797) ([superchell](https://github.com/superchell))
- added create category hooks [\#796](https://github.com/owen2345/camaleon-cms/pull/796) ([superchell](https://github.com/superchell))
- added post type edit link on post elements list page [\#795](https://github.com/owen2345/camaleon-cms/pull/795) ([superchell](https://github.com/superchell))
- more fixed russian translates [\#793](https://github.com/owen2345/camaleon-cms/pull/793) ([superchell](https://github.com/superchell))
- fixed russian translates [\#792](https://github.com/owen2345/camaleon-cms/pull/792) ([superchell](https://github.com/superchell))
- updated Fontawesome link [\#791](https://github.com/owen2345/camaleon-cms/pull/791) ([superchell](https://github.com/superchell))
- fix SVG thumbs on AWS [\#789](https://github.com/owen2345/camaleon-cms/pull/789) ([brian-kephart](https://github.com/brian-kephart))
- convert SVGs to JPEG when editing to avoid errors [\#788](https://github.com/owen2345/camaleon-cms/pull/788) ([brian-kephart](https://github.com/brian-kephart))
- Update camaleon\_cms.gemspec [\#784](https://github.com/owen2345/camaleon-cms/pull/784) ([gdurelle](https://github.com/gdurelle))
- Fix 'before\_upload' hook when uploading to local filesystem [\#775](https://github.com/owen2345/camaleon-cms/pull/775) ([brian-kephart](https://github.com/brian-kephart))
- Created endpoint for page not found [\#773](https://github.com/owen2345/camaleon-cms/pull/773) ([jpac-run](https://github.com/jpac-run))
- fix post\_order when no records [\#770](https://github.com/owen2345/camaleon-cms/pull/770) ([cestivan](https://github.com/cestivan))
- 767: Page not found not giving 404 status code [\#769](https://github.com/owen2345/camaleon-cms/pull/769) ([jpac-run](https://github.com/jpac-run))
- calc post order for persisted record only [\#766](https://github.com/owen2345/camaleon-cms/pull/766) ([cestivan](https://github.com/cestivan))
- Skip forgery check on .js files in /assets [\#764](https://github.com/owen2345/camaleon-cms/pull/764) ([brian-kephart](https://github.com/brian-kephart))
- fix post order bug when old posts are deleted [\#761](https://github.com/owen2345/camaleon-cms/pull/761) ([cestivan](https://github.com/cestivan))
- update will\_paginate column distribution [\#759](https://github.com/owen2345/camaleon-cms/pull/759) ([cestivan](https://github.com/cestivan))
- Slugify folder name when creating [\#758](https://github.com/owen2345/camaleon-cms/pull/758) ([tostasqb](https://github.com/tostasqb))
- Let a hook override the ability to see drafts [\#755](https://github.com/owen2345/camaleon-cms/pull/755) ([tostasqb](https://github.com/tostasqb))
- fix typo error [\#751](https://github.com/owen2345/camaleon-cms/pull/751) ([cestivan](https://github.com/cestivan))
- generate random character when slugify empty [\#750](https://github.com/owen2345/camaleon-cms/pull/750) ([cestivan](https://github.com/cestivan))
- fix post tag created without parent\_id bug [\#749](https://github.com/owen2345/camaleon-cms/pull/749) ([cestivan](https://github.com/cestivan))

## [2.4.5.1](https://github.com/owen2345/camaleon-cms/tree/2.4.5.1) (2018-01-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.5...2.4.5.1)

**Closed issues:**

- 500 internal server error & can\_edit\_file? in Media [\#744](https://github.com/owen2345/camaleon-cms/issues/744)
- Any recommended approach to deploying from dev/staging to production? [\#743](https://github.com/owen2345/camaleon-cms/issues/743)
- A question about camaleon's asset [\#740](https://github.com/owen2345/camaleon-cms/issues/740)
- add new language to common.yml [\#736](https://github.com/owen2345/camaleon-cms/issues/736)
- the path to the media file breaks when the frontend and backend localizations do not match [\#733](https://github.com/owen2345/camaleon-cms/issues/733)
- Demo page crash [\#713](https://github.com/owen2345/camaleon-cms/issues/713)
- Timestamp of NavMenu and NavMenuItem not updated [\#539](https://github.com/owen2345/camaleon-cms/issues/539)
- TinyMCE Templates [\#463](https://github.com/owen2345/camaleon-cms/issues/463)

**Merged pull requests:**

- Replaces deprecated fields, field\_values and field\_groups associations [\#746](https://github.com/owen2345/camaleon-cms/pull/746) ([fmfdias](https://github.com/fmfdias))
-  Re \#740 modify admin-manifest file [\#741](https://github.com/owen2345/camaleon-cms/pull/741) ([lanzhiheng](https://github.com/lanzhiheng))
- added .svg extansion to validation image files method [\#739](https://github.com/owen2345/camaleon-cms/pull/739) ([superchell](https://github.com/superchell))

## [2.4.5](https://github.com/owen2345/camaleon-cms/tree/2.4.5) (2017-11-23)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.6...2.4.5)

**Closed issues:**

- Unable to upload image: Internal Server Error [\#724](https://github.com/owen2345/camaleon-cms/issues/724)
- How to fix mixed content warnings when moving to production [\#722](https://github.com/owen2345/camaleon-cms/issues/722)
- Inactive site with no page selected is inaccessible [\#690](https://github.com/owen2345/camaleon-cms/issues/690)
- Camaleon store sources ? [\#356](https://github.com/owen2345/camaleon-cms/issues/356)

**Merged pull requests:**

- small fixes of Ukrainian language [\#734](https://github.com/owen2345/camaleon-cms/pull/734) ([superchell](https://github.com/superchell))
- Ukrainian localization [\#732](https://github.com/owen2345/camaleon-cms/pull/732) ([superchell](https://github.com/superchell))

## [2.4.4.6](https://github.com/owen2345/camaleon-cms/tree/2.4.4.6) (2017-11-01)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.5...2.4.4.6)

**Closed issues:**

- No such file or directory @ dir\_initialize [\#720](https://github.com/owen2345/camaleon-cms/issues/720)
- Edit link visible when viewing post category while logged out [\#718](https://github.com/owen2345/camaleon-cms/issues/718)
- Visibility plugin bug: Published Date not ok in list view [\#710](https://github.com/owen2345/camaleon-cms/issues/710)
- Disable create new sites? [\#708](https://github.com/owen2345/camaleon-cms/issues/708)
- Dynamic admin URL at system.json ? [\#707](https://github.com/owen2345/camaleon-cms/issues/707)
- Can't see changes when assigning field group to User [\#704](https://github.com/owen2345/camaleon-cms/issues/704)

**Merged pull requests:**

- Fix \#710 Published Date not ok in list view [\#711](https://github.com/owen2345/camaleon-cms/pull/711) ([tostasqb](https://github.com/tostasqb))
- use custom user model name if it present [\#706](https://github.com/owen2345/camaleon-cms/pull/706) ([vikagalkina](https://github.com/vikagalkina))
- Added GIF file types to asset precompilation. [\#703](https://github.com/owen2345/camaleon-cms/pull/703) ([Vaidaz](https://github.com/Vaidaz))

## [2.4.4.5](https://github.com/owen2345/camaleon-cms/tree/2.4.4.5) (2017-10-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.3...2.4.4.5)

**Closed issues:**

- mounting? [\#700](https://github.com/owen2345/camaleon-cms/issues/700)
- Migration does not work [\#692](https://github.com/owen2345/camaleon-cms/issues/692)
- Image custom field [\#294](https://github.com/owen2345/camaleon-cms/issues/294)

## [2.4.4.3](https://github.com/owen2345/camaleon-cms/tree/2.4.4.3) (2017-10-02)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4.2...2.4.4.3)

## [2.4.4.2](https://github.com/owen2345/camaleon-cms/tree/2.4.4.2) (2017-10-02)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.4...2.4.4.2)

**Closed issues:**

- ActiveModel::UnknownAttributeError in CamaleonCms::Admin::InstallersController\#save [\#698](https://github.com/owen2345/camaleon-cms/issues/698)
- Support with Gitter? [\#697](https://github.com/owen2345/camaleon-cms/issues/697)

## [2.4.4](https://github.com/owen2345/camaleon-cms/tree/2.4.4) (2017-09-30)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.12...2.4.4)

**Closed issues:**

- Not working: users\_share\_sites = false [\#691](https://github.com/owen2345/camaleon-cms/issues/691)
- Assets compilation failing working with webpack [\#688](https://github.com/owen2345/camaleon-cms/issues/688)
- Can't access admin panel for inactive site [\#682](https://github.com/owen2345/camaleon-cms/issues/682)
- Application stops working [\#680](https://github.com/owen2345/camaleon-cms/issues/680)
- Validation with contact\_form [\#679](https://github.com/owen2345/camaleon-cms/issues/679)
- Plugin generator creates duplicate routes in Gemfile [\#663](https://github.com/owen2345/camaleon-cms/issues/663)
- undefined method `saved\_change\_to\_attribute?' for \#\<CamaleonCms::Site:0x007ff468a826b8\> [\#651](https://github.com/owen2345/camaleon-cms/issues/651)

**Merged pull requests:**

- bump cancancan version [\#696](https://github.com/owen2345/camaleon-cms/pull/696) ([wuboy0307](https://github.com/wuboy0307))
- Added hooks for media support [\#693](https://github.com/owen2345/camaleon-cms/pull/693) ([tostasqb](https://github.com/tostasqb))
- Allow login to inactive sites [\#683](https://github.com/owen2345/camaleon-cms/pull/683) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.3.12](https://github.com/owen2345/camaleon-cms/tree/2.4.3.12) (2017-08-13)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.11...2.4.3.12)

**Closed issues:**

- Query to find all object with a certain custom field value [\#673](https://github.com/owen2345/camaleon-cms/issues/673)
- Template is missing [\#612](https://github.com/owen2345/camaleon-cms/issues/612)

**Merged pull requests:**

- Remove outdated data in the session [\#678](https://github.com/owen2345/camaleon-cms/pull/678) ([aspirewit](https://github.com/aspirewit))
- Contrib dev [\#677](https://github.com/owen2345/camaleon-cms/pull/677) ([haffla](https://github.com/haffla))
- fix method to delete folders [\#676](https://github.com/owen2345/camaleon-cms/pull/676) ([haffla](https://github.com/haffla))

## [2.4.3.11](https://github.com/owen2345/camaleon-cms/tree/2.4.3.11) (2017-08-01)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.10...2.4.3.11)

**Closed issues:**

- show/hide custom fields based on another custom fields value [\#671](https://github.com/owen2345/camaleon-cms/issues/671)
- Loop on the multiple group custom fields on the FO [\#668](https://github.com/owen2345/camaleon-cms/issues/668)
- Can't create new custom\_field\_group [\#666](https://github.com/owen2345/camaleon-cms/issues/666)
- Changer order back office [\#665](https://github.com/owen2345/camaleon-cms/issues/665)
- Ukrainian Flag Image [\#664](https://github.com/owen2345/camaleon-cms/issues/664)
- Import Script to Camaleon CMS Database [\#659](https://github.com/owen2345/camaleon-cms/issues/659)
- Content group slug on multiple sites [\#655](https://github.com/owen2345/camaleon-cms/issues/655)
- Multiple Files Uploading [\#653](https://github.com/owen2345/camaleon-cms/issues/653)

**Merged pull requests:**

- fix paths in cache methods [\#670](https://github.com/owen2345/camaleon-cms/pull/670) ([brian-kephart](https://github.com/brian-kephart))
- Add option to invalidate Front Cache rather than deleting it [\#669](https://github.com/owen2345/camaleon-cms/pull/669) ([brian-kephart](https://github.com/brian-kephart))

## [2.4.3.10](https://github.com/owen2345/camaleon-cms/tree/2.4.3.10) (2017-07-08)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3.7...2.4.3.10)

**Closed issues:**

- incomplete response in production env [\#661](https://github.com/owen2345/camaleon-cms/issues/661)
- \[Question\] Add fields to post category [\#656](https://github.com/owen2345/camaleon-cms/issues/656)
- admin post\_types page fail to load from time to time [\#634](https://github.com/owen2345/camaleon-cms/issues/634)
- Feature Request: Memcached/Redis support [\#609](https://github.com/owen2345/camaleon-cms/issues/609)

**Merged pull requests:**

- Fix custom fields group issue on Rails 5.1.1 [\#667](https://github.com/owen2345/camaleon-cms/pull/667) ([max2320](https://github.com/max2320))
- Use Rails cache store in Front Cache plugin [\#662](https://github.com/owen2345/camaleon-cms/pull/662) ([brian-kephart](https://github.com/brian-kephart))
- Cast parameters to hash to avoid error in rails 5 [\#660](https://github.com/owen2345/camaleon-cms/pull/660) ([sudoaza](https://github.com/sudoaza))
- upload files sequentially [\#658](https://github.com/owen2345/camaleon-cms/pull/658) ([haffla](https://github.com/haffla))
- using content slug instead of id to prevent conflict between multiple sites [\#657](https://github.com/owen2345/camaleon-cms/pull/657) ([phlcastro](https://github.com/phlcastro))
- fix error when using another model for authentication \(ie.: devise\) [\#654](https://github.com/owen2345/camaleon-cms/pull/654) ([phlcastro](https://github.com/phlcastro))
- memory leak in plugin routes [\#652](https://github.com/owen2345/camaleon-cms/pull/652) ([niedfelj](https://github.com/niedfelj))

## [2.4.3.7](https://github.com/owen2345/camaleon-cms/tree/2.4.3.7) (2017-06-09)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.3...2.4.3.7)

**Closed issues:**

- Incomplete Documentation for Draper patch for Rails 5 [\#646](https://github.com/owen2345/camaleon-cms/issues/646)
- the\_related\_posts returns duplicate records [\#637](https://github.com/owen2345/camaleon-cms/issues/637)
- Title tags truncated to 65 chars [\#635](https://github.com/owen2345/camaleon-cms/issues/635)
- db:migrate StandardError Directly inheriting from ActiveRecord::Migration [\#625](https://github.com/owen2345/camaleon-cms/issues/625)
- Front Cache problem with Rails 5.1 [\#624](https://github.com/owen2345/camaleon-cms/issues/624)
- SEO fields not translate to other languages [\#621](https://github.com/owen2345/camaleon-cms/issues/621)
- default slug from title.to\_url [\#619](https://github.com/owen2345/camaleon-cms/issues/619)
- remove pluralize for some locales [\#618](https://github.com/owen2345/camaleon-cms/issues/618)
- TinyMCE error after upgrading to 2.4.3.2 [\#617](https://github.com/owen2345/camaleon-cms/issues/617)
- How to display different versions/dimensions of an image  [\#614](https://github.com/owen2345/camaleon-cms/issues/614)
- User Roles Disabled [\#613](https://github.com/owen2345/camaleon-cms/issues/613)
- Frontend routes issue [\#600](https://github.com/owen2345/camaleon-cms/issues/600)
- Customize email template [\#599](https://github.com/owen2345/camaleon-cms/issues/599)
- How to get the contact form to actually send the emails [\#598](https://github.com/owen2345/camaleon-cms/issues/598)
- Can I migrate existing pages from BrowserCMS to CamaleonCMS? [\#594](https://github.com/owen2345/camaleon-cms/issues/594)
- Validation error [\#591](https://github.com/owen2345/camaleon-cms/issues/591)
- how can I override default\_url\_options [\#590](https://github.com/owen2345/camaleon-cms/issues/590)
- Probably typo in posts controller [\#586](https://github.com/owen2345/camaleon-cms/issues/586)
- upload\_file method in rake task [\#585](https://github.com/owen2345/camaleon-cms/issues/585)
- How to filter featured posts from a specific category [\#583](https://github.com/owen2345/camaleon-cms/issues/583)
- real estate website functionality [\#582](https://github.com/owen2345/camaleon-cms/issues/582)
- Missing pagination in admin user list [\#581](https://github.com/owen2345/camaleon-cms/issues/581)
- Display the featured image [\#580](https://github.com/owen2345/camaleon-cms/issues/580)
- How to loop through custom fields content [\#578](https://github.com/owen2345/camaleon-cms/issues/578)
- MiniMagick::Error when cropping [\#577](https://github.com/owen2345/camaleon-cms/issues/577)
- Can a custom post type be child of another custom post ? [\#576](https://github.com/owen2345/camaleon-cms/issues/576)
- Feature request: title tag for User profiles [\#575](https://github.com/owen2345/camaleon-cms/issues/575)
- S3 errors [\#571](https://github.com/owen2345/camaleon-cms/issues/571)
- Is there a function like blogcard or linkcard? [\#570](https://github.com/owen2345/camaleon-cms/issues/570)
- Colorpicker field type throws JS bugs in console and does not work [\#569](https://github.com/owen2345/camaleon-cms/issues/569)
- Warning: already initialized constant Cama::User [\#566](https://github.com/owen2345/camaleon-cms/issues/566)
- Wrong shortcode post search? [\#565](https://github.com/owen2345/camaleon-cms/issues/565)
- Enable ability to programatically tie a custom field to a post type [\#564](https://github.com/owen2345/camaleon-cms/issues/564)
- All users are have the permissions to update into admin user [\#563](https://github.com/owen2345/camaleon-cms/issues/563)
- Programatically enable custom field groups with multiple groups [\#562](https://github.com/owen2345/camaleon-cms/issues/562)
- No route matches {:action=\>"search", :controller=\>"camaleon\_cms/frontend", :label=\>"search", :slug=\>"welcome"} missing required keys: \[:label\] [\#558](https://github.com/owen2345/camaleon-cms/issues/558)

**Merged pull requests:**

- remove deprecated method 'render :text' [\#650](https://github.com/owen2345/camaleon-cms/pull/650) ([brian-kephart](https://github.com/brian-kephart))
- fix I18n.backend translations [\#649](https://github.com/owen2345/camaleon-cms/pull/649) ([wuboy0307](https://github.com/wuboy0307))
- Update application\_decorator.rb [\#648](https://github.com/owen2345/camaleon-cms/pull/648) ([gordienko](https://github.com/gordienko))
- Fixed NoMethodError undefined method 'paginate' for comments [\#644](https://github.com/owen2345/camaleon-cms/pull/644) ([pulkit21](https://github.com/pulkit21))
- add draft\_child to slug validation [\#643](https://github.com/owen2345/camaleon-cms/pull/643) ([haffla](https://github.com/haffla))
- wrap custom fields setter in activerecord transaction [\#642](https://github.com/owen2345/camaleon-cms/pull/642) ([niedfelj](https://github.com/niedfelj))
- fix restoring of drafts [\#641](https://github.com/owen2345/camaleon-cms/pull/641) ([haffla](https://github.com/haffla))
- Update post\_decorator.rb [\#639](https://github.com/owen2345/camaleon-cms/pull/639) ([brian-kephart](https://github.com/brian-kephart))
- Added PNG and JPG file types to asset precompilation. [\#638](https://github.com/owen2345/camaleon-cms/pull/638) ([WMPayne](https://github.com/WMPayne))
- Wording change [\#636](https://github.com/owen2345/camaleon-cms/pull/636) ([aspirewit](https://github.com/aspirewit))
- prevent nav menu item field 'kind' to be the empty string [\#633](https://github.com/owen2345/camaleon-cms/pull/633) ([haffla](https://github.com/haffla))
- Add the updated\_category hook [\#632](https://github.com/owen2345/camaleon-cms/pull/632) ([aspirewit](https://github.com/aspirewit))
- Add missing Chinese translation [\#631](https://github.com/owen2345/camaleon-cms/pull/631) ([aspirewit](https://github.com/aspirewit))
- Sanitize the filename of uploaded file [\#628](https://github.com/owen2345/camaleon-cms/pull/628) ([aspirewit](https://github.com/aspirewit))
- Improve media manager style [\#626](https://github.com/owen2345/camaleon-cms/pull/626) ([aspirewit](https://github.com/aspirewit))
- Improve gem plugin generator [\#623](https://github.com/owen2345/camaleon-cms/pull/623) ([aspirewit](https://github.com/aspirewit))
- Reassign comments after destroy user [\#622](https://github.com/owen2345/camaleon-cms/pull/622) ([aspirewit](https://github.com/aspirewit))
- translate post type title in posts custom field [\#620](https://github.com/owen2345/camaleon-cms/pull/620) ([haffla](https://github.com/haffla))
- delete file only when it exists [\#616](https://github.com/owen2345/camaleon-cms/pull/616) ([yfractal](https://github.com/yfractal))
- fix invalid key causes validate\_file\_format throw exception [\#615](https://github.com/owen2345/camaleon-cms/pull/615) ([yfractal](https://github.com/yfractal))
- Fix frontend routes issues [\#611](https://github.com/owen2345/camaleon-cms/pull/611) ([aspirewit](https://github.com/aspirewit))
- add missing chinese translation [\#610](https://github.com/owen2345/camaleon-cms/pull/610) ([yfractal](https://github.com/yfractal))
- add trash/restore hooks [\#608](https://github.com/owen2345/camaleon-cms/pull/608) ([haffla](https://github.com/haffla))
- To restrict user change role [\#607](https://github.com/owen2345/camaleon-cms/pull/607) ([aspirewit](https://github.com/aspirewit))
- Fix test cases [\#605](https://github.com/owen2345/camaleon-cms/pull/605) ([aspirewit](https://github.com/aspirewit))
- Removed some automatic pluralizes [\#604](https://github.com/owen2345/camaleon-cms/pull/604) ([aspirewit](https://github.com/aspirewit))
- Add missing Chinese translation [\#603](https://github.com/owen2345/camaleon-cms/pull/603) ([aspirewit](https://github.com/aspirewit))
- Allow the host application to override the translation [\#602](https://github.com/owen2345/camaleon-cms/pull/602) ([aspirewit](https://github.com/aspirewit))
- Revised simplified Chinese translation [\#601](https://github.com/owen2345/camaleon-cms/pull/601) ([aspirewit](https://github.com/aspirewit))
- add translation for logo upload [\#589](https://github.com/owen2345/camaleon-cms/pull/589) ([wuboy0307](https://github.com/wuboy0307))
- German translation - complement [\#574](https://github.com/owen2345/camaleon-cms/pull/574) ([haffla](https://github.com/haffla))
- German translation [\#559](https://github.com/owen2345/camaleon-cms/pull/559) ([haffla](https://github.com/haffla))

## [2.4.3](https://github.com/owen2345/camaleon-cms/tree/2.4.3) (2017-01-07)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.2...2.4.3)

**Closed issues:**

- "Constrain proportions" can't be deselected in editor [\#554](https://github.com/owen2345/camaleon-cms/issues/554)
- Error when saving posts [\#553](https://github.com/owen2345/camaleon-cms/issues/553)

## [2.4.2](https://github.com/owen2345/camaleon-cms/tree/2.4.2) (2016-12-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.1...2.4.2)

## [2.4.1](https://github.com/owen2345/camaleon-cms/tree/2.4.1) (2016-12-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.4.0...2.4.1)

**Closed issues:**

- Could you please add haml for designing template? [\#551](https://github.com/owen2345/camaleon-cms/issues/551)
- Coffeescript is not defined [\#550](https://github.com/owen2345/camaleon-cms/issues/550)
- Allow Each Page's Meta Tags to be Editable [\#547](https://github.com/owen2345/camaleon-cms/issues/547)

## [2.4.0](https://github.com/owen2345/camaleon-cms/tree/2.4.0) (2016-12-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.7...2.4.0)

**Closed issues:**

- NotNullViolation [\#548](https://github.com/owen2345/camaleon-cms/issues/548)

## [2.3.7](https://github.com/owen2345/camaleon-cms/tree/2.3.7) (2016-12-12)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.6...2.3.7)

**Closed issues:**

- Method overwrite warning when precompiling [\#549](https://github.com/owen2345/camaleon-cms/issues/549)
- RSS feed error [\#544](https://github.com/owen2345/camaleon-cms/issues/544)
- 500 Internal Server Error [\#541](https://github.com/owen2345/camaleon-cms/issues/541)
- Problem with setting post dates [\#534](https://github.com/owen2345/camaleon-cms/issues/534)
- Typo [\#533](https://github.com/owen2345/camaleon-cms/issues/533)
- Question about login [\#532](https://github.com/owen2345/camaleon-cms/issues/532)
- S3 upload options [\#531](https://github.com/owen2345/camaleon-cms/issues/531)
- Deprecation warning [\#530](https://github.com/owen2345/camaleon-cms/issues/530)
- parent\_auth\_token [\#529](https://github.com/owen2345/camaleon-cms/issues/529)
- Request: async loading with cama\_draw\_custom\_assets [\#521](https://github.com/owen2345/camaleon-cms/issues/521)
- Edit link visible when viewing post category while logged out [\#520](https://github.com/owen2345/camaleon-cms/issues/520)
- How to route subdomain to its own domain [\#514](https://github.com/owen2345/camaleon-cms/issues/514)
- Separate URLs for admin and public site [\#507](https://github.com/owen2345/camaleon-cms/issues/507)
- List of available plugins [\#497](https://github.com/owen2345/camaleon-cms/issues/497)
- TypeError in CamaleonCms::Admin::SettingsController\#save\_theme [\#496](https://github.com/owen2345/camaleon-cms/issues/496)
- Theme per Site [\#493](https://github.com/owen2345/camaleon-cms/issues/493)
- How can I Override FrontendController [\#492](https://github.com/owen2345/camaleon-cms/issues/492)
- Rails 5 [\#487](https://github.com/owen2345/camaleon-cms/issues/487)
- Rails console not running [\#485](https://github.com/owen2345/camaleon-cms/issues/485)
- Use only Admin portal of Camaleon with Rails 4 application [\#483](https://github.com/owen2345/camaleon-cms/issues/483)
- Assigning Custom Field Group to Users has no effects. [\#477](https://github.com/owen2345/camaleon-cms/issues/477)
- adding gem to my plugin [\#468](https://github.com/owen2345/camaleon-cms/issues/468)
- Creating content group in rails 5 [\#458](https://github.com/owen2345/camaleon-cms/issues/458)
- ActiveModel::ForbiddenAttributesError Rails 5 [\#450](https://github.com/owen2345/camaleon-cms/issues/450)
- Feature Request: External Link should have target. [\#444](https://github.com/owen2345/camaleon-cms/issues/444)
- Unable to upload media files. [\#418](https://github.com/owen2345/camaleon-cms/issues/418)
- Changing theme reverting back footer info [\#309](https://github.com/owen2345/camaleon-cms/issues/309)
- How to enable amazon S3 storage for all subdomains [\#270](https://github.com/owen2345/camaleon-cms/issues/270)

**Merged pull requests:**

- Adds ButterCMS sponsorship [\#542](https://github.com/owen2345/camaleon-cms/pull/542) ([rogerjin12](https://github.com/rogerjin12))
- Add translations in zh-CN [\#537](https://github.com/owen2345/camaleon-cms/pull/537) ([cheenwe](https://github.com/cheenwe))
- Cleanup and improvements in custom fields classes [\#528](https://github.com/owen2345/camaleon-cms/pull/528) ([sabinahofmann](https://github.com/sabinahofmann))
- Cleanup category class [\#527](https://github.com/owen2345/camaleon-cms/pull/527) ([sabinahofmann](https://github.com/sabinahofmann))
- cleanup and improvements in ability class [\#526](https://github.com/owen2345/camaleon-cms/pull/526) ([sabinahofmann](https://github.com/sabinahofmann))
- Revert "code cleanup in models" [\#523](https://github.com/owen2345/camaleon-cms/pull/523) ([owen2345](https://github.com/owen2345))
- code cleanup in models [\#522](https://github.com/owen2345/camaleon-cms/pull/522) ([sabinahofmann](https://github.com/sabinahofmann))
- Treat username case insensitively when logging in [\#516](https://github.com/owen2345/camaleon-cms/pull/516) ([p-decoraid](https://github.com/p-decoraid))
-  Fix user agent check to work in test environment.  [\#515](https://github.com/owen2345/camaleon-cms/pull/515) ([p-decoraid](https://github.com/p-decoraid))
- Reenable expect syntax as it was used in examples [\#512](https://github.com/owen2345/camaleon-cms/pull/512) ([p-decoraid](https://github.com/p-decoraid))
- Fix checkbox custom fields always being checked in admin [\#511](https://github.com/owen2345/camaleon-cms/pull/511) ([p-decoraid](https://github.com/p-decoraid))
- Lowercase user email addresses [\#508](https://github.com/owen2345/camaleon-cms/pull/508) ([p-decoraid](https://github.com/p-decoraid))
- Fix spelling of AWS S3 [\#506](https://github.com/owen2345/camaleon-cms/pull/506) ([p-decoraid](https://github.com/p-decoraid))
- Added Gemfile.lock to gitignore file [\#504](https://github.com/owen2345/camaleon-cms/pull/504) ([mazharoddin](https://github.com/mazharoddin))
- Explicitly include plugin helper dependency into hooks helper [\#503](https://github.com/owen2345/camaleon-cms/pull/503) ([p-decoraid](https://github.com/p-decoraid))
- Fix some spelling errors [\#502](https://github.com/owen2345/camaleon-cms/pull/502) ([p-decoraid](https://github.com/p-decoraid))
- just make models more readable [\#501](https://github.com/owen2345/camaleon-cms/pull/501) ([p-decoraid](https://github.com/p-decoraid))
- Just a gemfile.lock update [\#500](https://github.com/owen2345/camaleon-cms/pull/500) ([p-decoraid](https://github.com/p-decoraid))
- Drop executable bits on files that are not executable [\#495](https://github.com/owen2345/camaleon-cms/pull/495) ([p-decoraid](https://github.com/p-decoraid))
- Use an English string by default [\#494](https://github.com/owen2345/camaleon-cms/pull/494) ([p-decoraid](https://github.com/p-decoraid))

## [2.3.6](https://github.com/owen2345/camaleon-cms/tree/2.3.6) (2016-09-21)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.5...2.3.6)

## [2.3.5](https://github.com/owen2345/camaleon-cms/tree/2.3.5) (2016-09-19)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.4...2.3.5)

**Closed issues:**

- Release a new version [\#489](https://github.com/owen2345/camaleon-cms/issues/489)
- Performance issues [\#461](https://github.com/owen2345/camaleon-cms/issues/461)

## [2.3.4](https://github.com/owen2345/camaleon-cms/tree/2.3.4) (2016-09-14)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.3...2.3.4)

**Closed issues:**

- Rendering is broken when using narrower window widths [\#481](https://github.com/owen2345/camaleon-cms/issues/481)
- undefined local variable or method `doorkeeper\_token'  error with new changes. [\#476](https://github.com/owen2345/camaleon-cms/issues/476)
- undefined local variable or method `cama\_root\_url' with rails 5.0. [\#473](https://github.com/owen2345/camaleon-cms/issues/473)
- undefined method `id' for nil:NilClass while trying to access ecommerce posts as un logged in user. [\#472](https://github.com/owen2345/camaleon-cms/issues/472)
- Checkbox and Checkboxes in Custom Fields not working proerly [\#464](https://github.com/owen2345/camaleon-cms/issues/464)
- 2.1.2.6 tag missing [\#460](https://github.com/owen2345/camaleon-cms/issues/460)
- Change history [\#459](https://github.com/owen2345/camaleon-cms/issues/459)
- Cannot use shortcode [\#432](https://github.com/owen2345/camaleon-cms/issues/432)

**Merged pull requests:**

- email\_late hook, to permit modifying e.g. smtp settings [\#488](https://github.com/owen2345/camaleon-cms/pull/488) ([p-decoraid](https://github.com/p-decoraid))
- Custom fields diagnostics [\#486](https://github.com/owen2345/camaleon-cms/pull/486) ([p-decoraid](https://github.com/p-decoraid))
- french traduction for admin panel [\#484](https://github.com/owen2345/camaleon-cms/pull/484) ([Gloumy](https://github.com/Gloumy))
- Further work on testing [\#482](https://github.com/owen2345/camaleon-cms/pull/482) ([p-decoraid](https://github.com/p-decoraid))
- Take 3 at doorkeeper\_token fix. [\#480](https://github.com/owen2345/camaleon-cms/pull/480) ([p-decoraid](https://github.com/p-decoraid))
- Work in progress to fix the test suite [\#479](https://github.com/owen2345/camaleon-cms/pull/479) ([p-decoraid](https://github.com/p-decoraid))
- Second fix for doorkeeper\_token/rescue nil [\#478](https://github.com/owen2345/camaleon-cms/pull/478) ([p-decoraid](https://github.com/p-decoraid))
- Move conditionals for clarity [\#475](https://github.com/owen2345/camaleon-cms/pull/475) ([p-decoraid](https://github.com/p-decoraid))
- Do not rescue nil in session helper [\#474](https://github.com/owen2345/camaleon-cms/pull/474) ([p-decoraid](https://github.com/p-decoraid))
- Added an option to show file actions in media modals [\#471](https://github.com/owen2345/camaleon-cms/pull/471) ([p-decoraid](https://github.com/p-decoraid))
- Indicate development dependencies on rspec and capybara [\#469](https://github.com/owen2345/camaleon-cms/pull/469) ([p-decoraid](https://github.com/p-decoraid))
- Handle the case of shortcodes not being initialized, as might happen … [\#466](https://github.com/owen2345/camaleon-cms/pull/466) ([p-decoraid](https://github.com/p-decoraid))

## [2.3.3](https://github.com/owen2345/camaleon-cms/tree/2.3.3) (2016-08-16)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.2...2.3.3)

**Closed issues:**

- ActionController::RoutingError - Media routes fail when you use relative\_url\_root [\#437](https://github.com/owen2345/camaleon-cms/issues/437)

## [2.3.2](https://github.com/owen2345/camaleon-cms/tree/2.3.2) (2016-08-16)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.3.1...2.3.2)

**Closed issues:**

- Languages support for camaleon [\#457](https://github.com/owen2345/camaleon-cms/issues/457)
- How to create/change ecommerce plugin as multi vendor store [\#453](https://github.com/owen2345/camaleon-cms/issues/453)
- rails generate camaleon\_cms:install :error" Rais 5 [\#452](https://github.com/owen2345/camaleon-cms/issues/452)
- How to run specs [\#429](https://github.com/owen2345/camaleon-cms/issues/429)

## [2.3.1](https://github.com/owen2345/camaleon-cms/tree/2.3.1) (2016-08-12)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.2.0...2.3.1)

**Closed issues:**

- ForbiddenAttributesError  in ShippingMethodsController [\#455](https://github.com/owen2345/camaleon-cms/issues/455)
- Custom PaymentMethod Error  [\#454](https://github.com/owen2345/camaleon-cms/issues/454)
- Slim/ Haml support [\#449](https://github.com/owen2345/camaleon-cms/issues/449)
- Where to define current site?  [\#448](https://github.com/owen2345/camaleon-cms/issues/448)
- Adding custom post type and custom field programmatically.  [\#447](https://github.com/owen2345/camaleon-cms/issues/447)
- Forbidden attributes error [\#446](https://github.com/owen2345/camaleon-cms/issues/446)
- Logo doesn't appear after uploaded. [\#445](https://github.com/owen2345/camaleon-cms/issues/445)
- Camaleon doesn't run in both  rails 4.2.7 and with rails 5 ? [\#443](https://github.com/owen2345/camaleon-cms/issues/443)
- Draft posts can not be published [\#442](https://github.com/owen2345/camaleon-cms/issues/442)
- Camaleon App code [\#436](https://github.com/owen2345/camaleon-cms/issues/436)
- Reorder in menu does not work. [\#435](https://github.com/owen2345/camaleon-cms/issues/435)
- Register FAIL [\#433](https://github.com/owen2345/camaleon-cms/issues/433)
- undefined method `\[\]' for nil:NilClass error whith cms 2.2.1 and ecommerce 1.1 version. [\#428](https://github.com/owen2345/camaleon-cms/issues/428)
- install with rails 5.0 [\#424](https://github.com/owen2345/camaleon-cms/issues/424)
- redirect on creation of a second site [\#423](https://github.com/owen2345/camaleon-cms/issues/423)
- Not administrators users editing profile [\#417](https://github.com/owen2345/camaleon-cms/issues/417)
- Image in template email [\#415](https://github.com/owen2345/camaleon-cms/issues/415)
- What cased this problem ? How to solve this ? [\#413](https://github.com/owen2345/camaleon-cms/issues/413)
- How to override plugin views [\#405](https://github.com/owen2345/camaleon-cms/issues/405)
- uninitialized constant CamaleonCms::Admin::AdminController Error if I use cloudfront URL & while trying to delete Images [\#402](https://github.com/owen2345/camaleon-cms/issues/402)

**Merged pull requests:**

- select content helper [\#441](https://github.com/owen2345/camaleon-cms/pull/441) ([Uysim](https://github.com/Uysim))
- Bugfix set\_field\_values [\#431](https://github.com/owen2345/camaleon-cms/pull/431) ([gcrofils](https://github.com/gcrofils))
- Master [\#430](https://github.com/owen2345/camaleon-cms/pull/430) ([gcrofils](https://github.com/gcrofils))
- Fix relative link to RoR site on sample homepage [\#427](https://github.com/owen2345/camaleon-cms/pull/427) ([alexbrinkman](https://github.com/alexbrinkman))
- Fix typos in admin walkthrough [\#426](https://github.com/owen2345/camaleon-cms/pull/426) ([alexbrinkman](https://github.com/alexbrinkman))
- Enable matching paths as regexes. [\#422](https://github.com/owen2345/camaleon-cms/pull/422) ([stahor](https://github.com/stahor))
- Added fix to ability iteration [\#421](https://github.com/owen2345/camaleon-cms/pull/421) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Frontcache plugin [\#420](https://github.com/owen2345/camaleon-cms/pull/420) ([stahor](https://github.com/stahor))
- Fixed update post button in draft and translations for Pt-BR [\#419](https://github.com/owen2345/camaleon-cms/pull/419) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Fixed update password by normal user [\#416](https://github.com/owen2345/camaleon-cms/pull/416) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Fixed logo image in email template [\#414](https://github.com/owen2345/camaleon-cms/pull/414) ([RafaelTCostella](https://github.com/RafaelTCostella))
- add Português \(Portugal\) [\#411](https://github.com/owen2345/camaleon-cms/pull/411) ([filiperocha](https://github.com/filiperocha))
- stacksmith: Add Dockerfile [\#409](https://github.com/owen2345/camaleon-cms/pull/409) ([stacksmith-bot](https://github.com/stacksmith-bot))
- Update ita translations [\#408](https://github.com/owen2345/camaleon-cms/pull/408) ([ramensoup](https://github.com/ramensoup))
- Permit to change post author [\#372](https://github.com/owen2345/camaleon-cms/pull/372) ([gcrofils](https://github.com/gcrofils))

## [2.2.0](https://github.com/owen2345/camaleon-cms/tree/2.2.0) (2016-06-15)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.2.1...2.2.0)

**Closed issues:**

- pt-BR problems [\#407](https://github.com/owen2345/camaleon-cms/issues/407)
- How to change title for posts [\#400](https://github.com/owen2345/camaleon-cms/issues/400)
- File upload size limit [\#377](https://github.com/owen2345/camaleon-cms/issues/377)
- Rails Best Practices [\#346](https://github.com/owen2345/camaleon-cms/issues/346)
- Switch to Devise [\#103](https://github.com/owen2345/camaleon-cms/issues/103)
- Tests [\#74](https://github.com/owen2345/camaleon-cms/issues/74)

**Merged pull requests:**

- Added fixes to translations in Pt-BR [\#406](https://github.com/owen2345/camaleon-cms/pull/406) ([RafaelTCostella](https://github.com/RafaelTCostella))
- Corrected comment for theme\_asset\_path [\#401](https://github.com/owen2345/camaleon-cms/pull/401) ([jebingeosil](https://github.com/jebingeosil))
- I fixed some issues that I see. [\#399](https://github.com/owen2345/camaleon-cms/pull/399) ([codem4ster](https://github.com/codem4ster))

## [2.1.2.1](https://github.com/owen2345/camaleon-cms/tree/2.1.2.1) (2016-05-20)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.2.0...2.1.2.1)

**Closed issues:**

- How to ensure only specified plugins and themse are available for subdomains [\#398](https://github.com/owen2345/camaleon-cms/issues/398)
- Adding translation by admin? [\#395](https://github.com/owen2345/camaleon-cms/issues/395)
- Please Deploy to ruby gem frequently [\#335](https://github.com/owen2345/camaleon-cms/issues/335)
- Unable to use cloudfront  [\#280](https://github.com/owen2345/camaleon-cms/issues/280)
- Theme views aren't added to the view path [\#278](https://github.com/owen2345/camaleon-cms/issues/278)

**Merged pull requests:**

- Update custom\_fields\_read.rb [\#396](https://github.com/owen2345/camaleon-cms/pull/396) ([stahor](https://github.com/stahor))

## [2.1.2.0](https://github.com/owen2345/camaleon-cms/tree/2.1.2.0) (2016-04-29)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/v2.1.1.3...2.1.2.0)

**Closed issues:**

- Custom fields api link broken - http://camaleon.tuzitio.com/custom-fields-api [\#394](https://github.com/owen2345/camaleon-cms/issues/394)
- Not a issue but.. Looking for documentation and camaleon website is down [\#391](https://github.com/owen2345/camaleon-cms/issues/391)
- Cannot use asset in localhost [\#390](https://github.com/owen2345/camaleon-cms/issues/390)
- We would like to suggest that external menu items also have visibility settings [\#389](https://github.com/owen2345/camaleon-cms/issues/389)
- I would like to suggest changing the route name for the back end. [\#388](https://github.com/owen2345/camaleon-cms/issues/388)
- Custom theme for admin interface? [\#387](https://github.com/owen2345/camaleon-cms/issues/387)
- Allow site admin to suspend a subdomain [\#386](https://github.com/owen2345/camaleon-cms/issues/386)
- Media folders can not be deleted with local storage [\#385](https://github.com/owen2345/camaleon-cms/issues/385)
- Sub menues? [\#384](https://github.com/owen2345/camaleon-cms/issues/384)
- Authorization issue [\#383](https://github.com/owen2345/camaleon-cms/issues/383)
- Basic install is generating a permission denied error [\#382](https://github.com/owen2345/camaleon-cms/issues/382)
- Compatibility with rails-composer [\#381](https://github.com/owen2345/camaleon-cms/issues/381)
- change search engine [\#380](https://github.com/owen2345/camaleon-cms/issues/380)
- Typo in CamaleonCms::CustomFieldsRead \(post -\> Post\) ? [\#376](https://github.com/owen2345/camaleon-cms/issues/376)
- How to rename post type menu [\#375](https://github.com/owen2345/camaleon-cms/issues/375)
- Paginate Not Working when custom routes [\#374](https://github.com/owen2345/camaleon-cms/issues/374)
- An unhandled lowlevel error occurred while uploading a photo for a user profile. [\#373](https://github.com/owen2345/camaleon-cms/issues/373)
- Undefined local variable or method `admin\_plugins\_contact\_form\_admin\_forms\_path` [\#370](https://github.com/owen2345/camaleon-cms/issues/370)
- Problem with nav menu generation [\#364](https://github.com/owen2345/camaleon-cms/issues/364)
- Theming tutorial [\#361](https://github.com/owen2345/camaleon-cms/issues/361)
- Sending mail on Heroku [\#360](https://github.com/owen2345/camaleon-cms/issues/360)
- How to close down multiple language support in grain? [\#359](https://github.com/owen2345/camaleon-cms/issues/359)
- Subscribe form  [\#357](https://github.com/owen2345/camaleon-cms/issues/357)
- Docker image [\#355](https://github.com/owen2345/camaleon-cms/issues/355)
- How to let users create subdomains using omniauth [\#354](https://github.com/owen2345/camaleon-cms/issues/354)
- Multiple Custom Field with same value [\#353](https://github.com/owen2345/camaleon-cms/issues/353)
- Camaleon documentation broken [\#342](https://github.com/owen2345/camaleon-cms/issues/342)
- undefined method `get\_taxonomy' error  [\#341](https://github.com/owen2345/camaleon-cms/issues/341)
- Custom Fields [\#329](https://github.com/owen2345/camaleon-cms/issues/329)
- Feature: Role management limited to site [\#325](https://github.com/owen2345/camaleon-cms/issues/325)
- "Slug can't be blank" when creating page [\#323](https://github.com/owen2345/camaleon-cms/issues/323)
- Commit "changed datetimepickerr" breaks creating posts. ref =\>55dfe78906c59df3cb873a8e684f14cfef1b9a56 [\#315](https://github.com/owen2345/camaleon-cms/issues/315)
- nav-menu custom fields 500 error [\#307](https://github.com/owen2345/camaleon-cms/issues/307)
- Dutch Flag Image [\#302](https://github.com/owen2345/camaleon-cms/issues/302)
- Allow users to use cloudfront for AWS S3 bucket [\#291](https://github.com/owen2345/camaleon-cms/issues/291)
- Multiple Domain Needed [\#290](https://github.com/owen2345/camaleon-cms/issues/290)
- Shortcode don't have post's content [\#277](https://github.com/owen2345/camaleon-cms/issues/277)
- Tags on posts? [\#268](https://github.com/owen2345/camaleon-cms/issues/268)
- smtp email settings and notifications [\#265](https://github.com/owen2345/camaleon-cms/issues/265)
- How skip User model? [\#252](https://github.com/owen2345/camaleon-cms/issues/252)
- Reintroduced: Admin section breaks if changing slug of main site [\#249](https://github.com/owen2345/camaleon-cms/issues/249)
- Bug and weird behaivor of the create/update/recover/publish button on post edit/creation section [\#239](https://github.com/owen2345/camaleon-cms/issues/239)
- Wrong locale in backend translation [\#233](https://github.com/owen2345/camaleon-cms/issues/233)
- Permalink link not support utf-8 character [\#194](https://github.com/owen2345/camaleon-cms/issues/194)
- Build nav menu for plugins [\#160](https://github.com/owen2345/camaleon-cms/issues/160)
- Override custom post types in sitemaps [\#157](https://github.com/owen2345/camaleon-cms/issues/157)
- Default layout [\#153](https://github.com/owen2345/camaleon-cms/issues/153)
- Move system.json configuration into environment variables [\#141](https://github.com/owen2345/camaleon-cms/issues/141)
- Custom Post Types [\#129](https://github.com/owen2345/camaleon-cms/issues/129)
- Integrate Post/Page links into tinymce [\#96](https://github.com/owen2345/camaleon-cms/issues/96)
- Post Type form is confusing [\#95](https://github.com/owen2345/camaleon-cms/issues/95)
- Performance [\#93](https://github.com/owen2345/camaleon-cms/issues/93)
- Using Camaleon alongside existing app [\#89](https://github.com/owen2345/camaleon-cms/issues/89)

## [v2.1.1.3](https://github.com/owen2345/camaleon-cms/tree/v2.1.1.3) (2016-04-03)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.2...v2.1.1.3)

**Closed issues:**

- Tinymce attempts to load plugins and themes [\#365](https://github.com/owen2345/camaleon-cms/issues/365)
- Assets not found after clobbering and precompiling assets [\#363](https://github.com/owen2345/camaleon-cms/issues/363)
- Excessive memory consumption problem [\#343](https://github.com/owen2345/camaleon-cms/issues/343)
- How can I have grid editor [\#340](https://github.com/owen2345/camaleon-cms/issues/340)
- example for create custom\_field\_groups at theme installation [\#337](https://github.com/owen2345/camaleon-cms/issues/337)
- Method\_missing sender [\#336](https://github.com/owen2345/camaleon-cms/issues/336)
- Search error [\#330](https://github.com/owen2345/camaleon-cms/issues/330)
- File format not allowed [\#317](https://github.com/owen2345/camaleon-cms/issues/317)
- Media manager "shadow" items [\#313](https://github.com/owen2345/camaleon-cms/issues/313)
- Media manager: can't delete items [\#312](https://github.com/owen2345/camaleon-cms/issues/312)
- Opening category page gives page not found error [\#311](https://github.com/owen2345/camaleon-cms/issues/311)
- CMS demo is broken  [\#306](https://github.com/owen2345/camaleon-cms/issues/306)
- Order post by drag drop [\#296](https://github.com/owen2345/camaleon-cms/issues/296)
- Custom Routes [\#275](https://github.com/owen2345/camaleon-cms/issues/275)
- Translation doesn't work when setting menues [\#271](https://github.com/owen2345/camaleon-cms/issues/271)
- undefined method `init\_seo'  [\#266](https://github.com/owen2345/camaleon-cms/issues/266)
- Custom permalink structure [\#158](https://github.com/owen2345/camaleon-cms/issues/158)

**Merged pull requests:**

- Allow change email subject from hooks [\#371](https://github.com/owen2345/camaleon-cms/pull/371) ([raulanatol](https://github.com/raulanatol))
- Fix tinymce issues when using precompiled assets [\#368](https://github.com/owen2345/camaleon-cms/pull/368) ([cmckni3](https://github.com/cmckni3))
- Fixes media folder navigation [\#367](https://github.com/owen2345/camaleon-cms/pull/367) ([cmckni3](https://github.com/cmckni3))
- Custom fields bugs [\#362](https://github.com/owen2345/camaleon-cms/pull/362) ([cmckni3](https://github.com/cmckni3))
- Add image caption as a default option [\#358](https://github.com/owen2345/camaleon-cms/pull/358) ([gcrofils](https://github.com/gcrofils))
- Fixes sidebar in media search [\#352](https://github.com/owen2345/camaleon-cms/pull/352) ([cmckni3](https://github.com/cmckni3))
- Change searches to be case insensitive [\#351](https://github.com/owen2345/camaleon-cms/pull/351) ([cmckni3](https://github.com/cmckni3))
- Add task to generate thumbnails [\#350](https://github.com/owen2345/camaleon-cms/pull/350) ([cmckni3](https://github.com/cmckni3))
- Add media search [\#349](https://github.com/owen2345/camaleon-cms/pull/349) ([cmckni3](https://github.com/cmckni3))
- Update \_media\_manager.js.coffee [\#347](https://github.com/owen2345/camaleon-cms/pull/347) ([raulanatol](https://github.com/raulanatol))
- Verify if the key on get\_meta is a Symbol before compare [\#339](https://github.com/owen2345/camaleon-cms/pull/339) ([raulanatol](https://github.com/raulanatol))
- moment locale error with locale = en [\#338](https://github.com/owen2345/camaleon-cms/pull/338) ([raulanatol](https://github.com/raulanatol))
- Added hook to customize custom fields render. [\#334](https://github.com/owen2345/camaleon-cms/pull/334) ([raulanatol](https://github.com/raulanatol))
- Temporal log removed [\#333](https://github.com/owen2345/camaleon-cms/pull/333) ([raulanatol](https://github.com/raulanatol))
- Include created\_at order by default [\#332](https://github.com/owen2345/camaleon-cms/pull/332) ([raulanatol](https://github.com/raulanatol))
- per\_page do not use the value of the hook [\#331](https://github.com/owen2345/camaleon-cms/pull/331) ([raulanatol](https://github.com/raulanatol))
- Cleaning useless code [\#326](https://github.com/owen2345/camaleon-cms/pull/326) ([gcrofils](https://github.com/gcrofils))
- Prepare reset password to api methods [\#324](https://github.com/owen2345/camaleon-cms/pull/324) ([raulanatol](https://github.com/raulanatol))
- Contact from email [\#322](https://github.com/owen2345/camaleon-cms/pull/322) ([raulanatol](https://github.com/raulanatol))
- optimized get\_meta when using eager\_load [\#320](https://github.com/owen2345/camaleon-cms/pull/320) ([gcrofils](https://github.com/gcrofils))
- added item\_container\_attrs when drawing menus [\#318](https://github.com/owen2345/camaleon-cms/pull/318) ([gcrofils](https://github.com/gcrofils))
- Email helper error [\#316](https://github.com/owen2345/camaleon-cms/pull/316) ([raulanatol](https://github.com/raulanatol))
- Recovery password using template .html.erb [\#314](https://github.com/owen2345/camaleon-cms/pull/314) ([raulanatol](https://github.com/raulanatol))
- Added russian language YAML file for admin panel [\#310](https://github.com/owen2345/camaleon-cms/pull/310) ([SuperMasterBlasterLaser](https://github.com/SuperMasterBlasterLaser))
- fixes call to partial custom\_fields/render [\#308](https://github.com/owen2345/camaleon-cms/pull/308) ([CBlaize](https://github.com/CBlaize))
- added dutch translation to js.yml [\#304](https://github.com/owen2345/camaleon-cms/pull/304) ([TimVNL](https://github.com/TimVNL))
- Dutch translation update [\#301](https://github.com/owen2345/camaleon-cms/pull/301) ([TimVNL](https://github.com/TimVNL))
- better dutch plugin translation [\#300](https://github.com/owen2345/camaleon-cms/pull/300) ([TimVNL](https://github.com/TimVNL))
- better dutch translation [\#299](https://github.com/owen2345/camaleon-cms/pull/299) ([TimVNL](https://github.com/TimVNL))
- added complete dutch plugin translation [\#298](https://github.com/owen2345/camaleon-cms/pull/298) ([TimVNL](https://github.com/TimVNL))
- added complete dutch locale [\#297](https://github.com/owen2345/camaleon-cms/pull/297) ([TimVNL](https://github.com/TimVNL))

## [2.1.2](https://github.com/owen2345/camaleon-cms/tree/2.1.2) (2016-01-17)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/2.1.1...2.1.2)

**Closed issues:**

- Editor and Contributor user roles are cleared when adding a new Post Type [\#289](https://github.com/owen2345/camaleon-cms/issues/289)
- Internal Server Error while trying to upload image on post [\#287](https://github.com/owen2345/camaleon-cms/issues/287)
- NoMethodError if I try to create a subdomain\(slug\) with starting with capital letter [\#286](https://github.com/owen2345/camaleon-cms/issues/286)
- Can't apply font to custom theme [\#284](https://github.com/owen2345/camaleon-cms/issues/284)
- Allow users to create categories on post creation page [\#283](https://github.com/owen2345/camaleon-cms/issues/283)
- Just FYI, your documentation site is down` [\#282](https://github.com/owen2345/camaleon-cms/issues/282)
- How to let users create subdomains  [\#281](https://github.com/owen2345/camaleon-cms/issues/281)
- undefined method `the\_thumb\_url' error if I click on user created tag [\#279](https://github.com/owen2345/camaleon-cms/issues/279)
- Better to have media in current\_site.slug folder [\#272](https://github.com/owen2345/camaleon-cms/issues/272)
- How to use high\_voltage pages as main site home page [\#267](https://github.com/owen2345/camaleon-cms/issues/267)

## [2.1.1](https://github.com/owen2345/camaleon-cms/tree/2.1.1) (2016-01-08)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/v2.0.0...2.1.1)

**Closed issues:**

- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#274](https://github.com/owen2345/camaleon-cms/issues/274)
- Captcha image broken on your demo site [\#273](https://github.com/owen2345/camaleon-cms/issues/273)
- Multi languages with Contents Route Format =\> content/:post\_type\_title/:slug in Content Group [\#264](https://github.com/owen2345/camaleon-cms/issues/264)
- asset-theme-url incorrect path [\#263](https://github.com/owen2345/camaleon-cms/issues/263)
- Error trying to insert image on post [\#262](https://github.com/owen2345/camaleon-cms/issues/262)
- Contents menu icon personalize [\#260](https://github.com/owen2345/camaleon-cms/issues/260)
- Can not load plugin assets [\#258](https://github.com/owen2345/camaleon-cms/issues/258)
- None Favicon [\#257](https://github.com/owen2345/camaleon-cms/issues/257)
- How did you group your navbar by category under documentation? [\#256](https://github.com/owen2345/camaleon-cms/issues/256)
- show the default theme? [\#255](https://github.com/owen2345/camaleon-cms/issues/255)
- Newbie Question [\#254](https://github.com/owen2345/camaleon-cms/issues/254)
- Deployment to heroku : BreadcrumbsOnRails detected it won't be overridden.  [\#251](https://github.com/owen2345/camaleon-cms/issues/251)
- Upgrade guide [\#250](https://github.com/owen2345/camaleon-cms/issues/250)
- ActionView::MissingTemplate in CamaleonCms::Admin::Settings\#site [\#248](https://github.com/owen2345/camaleon-cms/issues/248)
- TypeError in FrontendController\#index [\#244](https://github.com/owen2345/camaleon-cms/issues/244)
- TypeError \(no implicit conversion of Time into String\) [\#243](https://github.com/owen2345/camaleon-cms/issues/243)
- Logout on frontend redirects to dashboard [\#242](https://github.com/owen2345/camaleon-cms/issues/242)
- Bug when creating post simple custom field group [\#240](https://github.com/owen2345/camaleon-cms/issues/240)
- no implicit conversion of Time into String [\#237](https://github.com/owen2345/camaleon-cms/issues/237)
- Could not find "apps" in any of your source paths [\#236](https://github.com/owen2345/camaleon-cms/issues/236)
- loading of S3 assets in admin media index page takes too long [\#235](https://github.com/owen2345/camaleon-cms/issues/235)
- cannot stop intro popups [\#234](https://github.com/owen2345/camaleon-cms/issues/234)
- NoMethodError in CamaleonCms::Admin::SessionsController\#login\_post [\#232](https://github.com/owen2345/camaleon-cms/issues/232)
- theme generator not working [\#231](https://github.com/owen2345/camaleon-cms/issues/231)
- Cannot go to General Setting page [\#230](https://github.com/owen2345/camaleon-cms/issues/230)
- image custom field [\#229](https://github.com/owen2345/camaleon-cms/issues/229)
- Error when creating a custom field group [\#227](https://github.com/owen2345/camaleon-cms/issues/227)
- Custom Fields: undefined local variable or method `post\_data' [\#224](https://github.com/owen2345/camaleon-cms/issues/224)
- Bug after update v2 ActionView::Template::Error \(undefined local variable or method `root\_url' [\#223](https://github.com/owen2345/camaleon-cms/issues/223)
- Missing template themes camaleon\_cms v2 [\#222](https://github.com/owen2345/camaleon-cms/issues/222)
- Posts feature field [\#220](https://github.com/owen2345/camaleon-cms/issues/220)
- Broken Submit button on "Settings\>General Site\>Filesystem Settings"  [\#218](https://github.com/owen2345/camaleon-cms/issues/218)
- undefined local variable or method `admin\_plugins\_contact\_form\_admin\_forms\_path` for CameleonCms::AdminController [\#216](https://github.com/owen2345/camaleon-cms/issues/216)
- awsS3: missing @fog\_connection.endpoint on moduler branch [\#210](https://github.com/owen2345/camaleon-cms/issues/210)
- undefined method when migrating cameleon1x  [\#209](https://github.com/owen2345/camaleon-cms/issues/209)
- Has Comments? Always true.  [\#208](https://github.com/owen2345/camaleon-cms/issues/208)
- install error [\#207](https://github.com/owen2345/camaleon-cms/issues/207)
- missing template [\#206](https://github.com/owen2345/camaleon-cms/issues/206)
- LoadError "cannot load such file -- faraday" [\#204](https://github.com/owen2345/camaleon-cms/issues/204)
- error after installing AWS-S3 plugin [\#189](https://github.com/owen2345/camaleon-cms/issues/189)
- Undefined local variable or method `params` [\#186](https://github.com/owen2345/camaleon-cms/issues/186)
- Add footer text field [\#185](https://github.com/owen2345/camaleon-cms/issues/185)
- shortcodes.html.erb missing [\#178](https://github.com/owen2345/camaleon-cms/issues/178)
- Document to setup multiple domain with application [\#167](https://github.com/owen2345/camaleon-cms/issues/167)
- Expose camaleon view helpers to ActionController::Base.helpers [\#161](https://github.com/owen2345/camaleon-cms/issues/161)
- Cache problems [\#159](https://github.com/owen2345/camaleon-cms/issues/159)
- AJAX [\#146](https://github.com/owen2345/camaleon-cms/issues/146)
- Admin section breaks if changing slug of main site [\#134](https://github.com/owen2345/camaleon-cms/issues/134)
- Alternative File Manager? [\#107](https://github.com/owen2345/camaleon-cms/issues/107)
- OAuth api  [\#101](https://github.com/owen2345/camaleon-cms/issues/101)
- Images upload on heroku [\#100](https://github.com/owen2345/camaleon-cms/issues/100)

**Merged pull requests:**

- Fix Clean Theme to avoid creating duplicate main\_menu [\#276](https://github.com/owen2345/camaleon-cms/pull/276) ([rubyjedi](https://github.com/rubyjedi))
- cama\_print\_i18n\_value method added to evaluate i18n attributes.  [\#269](https://github.com/owen2345/camaleon-cms/pull/269) ([raulanatol](https://github.com/raulanatol))
- Media style updated [\#261](https://github.com/owen2345/camaleon-cms/pull/261) ([raulanatol](https://github.com/raulanatol))
- Clear api rest files and delete old routes [\#259](https://github.com/owen2345/camaleon-cms/pull/259) ([raulanatol](https://github.com/raulanatol))
- Update \_footer.html.erb [\#253](https://github.com/owen2345/camaleon-cms/pull/253) ([raulanatol](https://github.com/raulanatol))
- Activate user after registration [\#247](https://github.com/owen2345/camaleon-cms/pull/247) ([raulanatol](https://github.com/raulanatol))
- pre\_assets\_content [\#246](https://github.com/owen2345/camaleon-cms/pull/246) ([raulanatol](https://github.com/raulanatol))
- Route error admin\_login\_path [\#245](https://github.com/owen2345/camaleon-cms/pull/245) ([raulanatol](https://github.com/raulanatol))
- parse only current fog dir \#235 [\#241](https://github.com/owen2345/camaleon-cms/pull/241) ([momolog](https://github.com/momolog))
- Adding missing namespaces [\#238](https://github.com/owen2345/camaleon-cms/pull/238) ([mmeyerAlitmetrik](https://github.com/mmeyerAlitmetrik))
- \#134 Change how 'main\_site' is determined, and use the class method i… [\#201](https://github.com/owen2345/camaleon-cms/pull/201) ([marksiemers](https://github.com/marksiemers))

## [v2.0.0](https://github.com/owen2345/camaleon-cms/tree/v2.0.0) (2015-11-11)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/0.2.0...v2.0.0)

**Closed issues:**

- Validate user registration with email [\#198](https://github.com/owen2345/camaleon-cms/issues/198)
- custom routing system [\#188](https://github.com/owen2345/camaleon-cms/issues/188)
- Unable to insert/edit image [\#175](https://github.com/owen2345/camaleon-cms/issues/175)
- Custom fields querys [\#174](https://github.com/owen2345/camaleon-cms/issues/174)
- Example don't work [\#172](https://github.com/owen2345/camaleon-cms/issues/172)
- Theme assets not being precompiled [\#168](https://github.com/owen2345/camaleon-cms/issues/168)
- Undefined method `generate\_breadcrumb` [\#162](https://github.com/owen2345/camaleon-cms/issues/162)
- Custom fields not saving for navigation menus [\#156](https://github.com/owen2345/camaleon-cms/issues/156)
- Nav Menu settings JS error [\#154](https://github.com/owen2345/camaleon-cms/issues/154)
- 404 page error [\#152](https://github.com/owen2345/camaleon-cms/issues/152)
- Plugin loader plugins key problem [\#151](https://github.com/owen2345/camaleon-cms/issues/151)
- Cannot change default layout in theme. [\#150](https://github.com/owen2345/camaleon-cms/issues/150)
- Can't insert media into post/page [\#147](https://github.com/owen2345/camaleon-cms/issues/147)
- RSS incorrect controller action [\#145](https://github.com/owen2345/camaleon-cms/issues/145)
- Custom fields readonly [\#144](https://github.com/owen2345/camaleon-cms/issues/144)
- Theme assets not found after precompiling [\#137](https://github.com/owen2345/camaleon-cms/issues/137)
- Deploy on Heroku fails: "No such file" [\#132](https://github.com/owen2345/camaleon-cms/issues/132)
- Escaping JavaScript [\#131](https://github.com/owen2345/camaleon-cms/issues/131)
- We're sorry something went wrong \(500\) [\#128](https://github.com/owen2345/camaleon-cms/issues/128)
- Hooks for post types from plugins? [\#127](https://github.com/owen2345/camaleon-cms/issues/127)
- New plugins format [\#126](https://github.com/owen2345/camaleon-cms/issues/126)
- Can't add fields to contact form [\#124](https://github.com/owen2345/camaleon-cms/issues/124)
- Theme field on contact form [\#123](https://github.com/owen2345/camaleon-cms/issues/123)
- uninitialized constant CamaleonCms::VERSION [\#121](https://github.com/owen2345/camaleon-cms/issues/121)
- Admin login page puts asterisks in password field [\#120](https://github.com/owen2345/camaleon-cms/issues/120)
- Hooks [\#119](https://github.com/owen2345/camaleon-cms/issues/119)
- Theming [\#117](https://github.com/owen2345/camaleon-cms/issues/117)
- Post types [\#114](https://github.com/owen2345/camaleon-cms/issues/114)
- Vendor asset management [\#112](https://github.com/owen2345/camaleon-cms/issues/112)
- Implement new admin template [\#111](https://github.com/owen2345/camaleon-cms/issues/111)
- Use "description" in config.json on plugins instead of "descr" [\#109](https://github.com/owen2345/camaleon-cms/issues/109)
- Add Sitemap information from plugins [\#106](https://github.com/owen2345/camaleon-cms/issues/106)
- Admin UI Helpers [\#105](https://github.com/owen2345/camaleon-cms/issues/105)
- Menu builder customization [\#102](https://github.com/owen2345/camaleon-cms/issues/102)
- hardcoded alt="Nature Image 1" in Featured Image \(Admin Page\) [\#97](https://github.com/owen2345/camaleon-cms/issues/97)
- Disable captcha [\#90](https://github.com/owen2345/camaleon-cms/issues/90)
- Plugin custom\_models append new attribute to Users [\#88](https://github.com/owen2345/camaleon-cms/issues/88)
- Google analytics plugin [\#86](https://github.com/owen2345/camaleon-cms/issues/86)
- AGPL vs GPL [\#85](https://github.com/owen2345/camaleon-cms/issues/85)
- Mandrill plugin [\#84](https://github.com/owen2345/camaleon-cms/issues/84)
- NameError in AdminController\#dashboard [\#83](https://github.com/owen2345/camaleon-cms/issues/83)
- Changing layouts [\#82](https://github.com/owen2345/camaleon-cms/issues/82)
- Plugin isolation [\#81](https://github.com/owen2345/camaleon-cms/issues/81)
- Better support for migrations inside of plugins [\#80](https://github.com/owen2345/camaleon-cms/issues/80)
- Ecommerce plugin free shipment [\#79](https://github.com/owen2345/camaleon-cms/issues/79)
- Deploy on AWS ElasticBeanstalk [\#78](https://github.com/owen2345/camaleon-cms/issues/78)
- Shorter asset paths [\#75](https://github.com/owen2345/camaleon-cms/issues/75)
- Create image tag for an image in the themes folder [\#72](https://github.com/owen2345/camaleon-cms/issues/72)
- Ecommerce plugin [\#70](https://github.com/owen2345/camaleon-cms/issues/70)
- Bootstrap navbar in admin [\#65](https://github.com/owen2345/camaleon-cms/issues/65)
- Bootstrap colors [\#64](https://github.com/owen2345/camaleon-cms/issues/64)
- .html URL extension [\#63](https://github.com/owen2345/camaleon-cms/issues/63)
- Customize frontend routes [\#62](https://github.com/owen2345/camaleon-cms/issues/62)
- Move user profile information from left sidebar [\#60](https://github.com/owen2345/camaleon-cms/issues/60)
- Strong Parameters [\#59](https://github.com/owen2345/camaleon-cms/issues/59)
- Uploader integration [\#57](https://github.com/owen2345/camaleon-cms/issues/57)
- Sass style support [\#56](https://github.com/owen2345/camaleon-cms/issues/56)
- rails generate camaleon\_cms:install fails [\#55](https://github.com/owen2345/camaleon-cms/issues/55)
- Sprockets::Rails::Helper::AbsoluteAssetPathError in Admin::Sessions\#login  [\#53](https://github.com/owen2345/camaleon-cms/issues/53)

**Merged pull requests:**

- fix lastmod date format in sitemap.xml.builder to be Google-compliant [\#200](https://github.com/owen2345/camaleon-cms/pull/200) ([Silvaire](https://github.com/Silvaire))
- Fixes sitemap concern [\#199](https://github.com/owen2345/camaleon-cms/pull/199) ([cmckni3](https://github.com/cmckni3))
- fix syntax api\_controller for Heroku [\#193](https://github.com/owen2345/camaleon-cms/pull/193) ([Silvaire](https://github.com/Silvaire))
- ActiveModel::ArraySerializer error fixed [\#192](https://github.com/owen2345/camaleon-cms/pull/192) ([raulanatol](https://github.com/raulanatol))
- Api with active\_model\_serializers [\#190](https://github.com/owen2345/camaleon-cms/pull/190) ([raulanatol](https://github.com/raulanatol))
- RU translation [\#184](https://github.com/owen2345/camaleon-cms/pull/184) ([sanata-](https://github.com/sanata-))
- Prepare contact\_form to use Api methods. [\#183](https://github.com/owen2345/camaleon-cms/pull/183) ([raulanatol](https://github.com/raulanatol))
- Add theme asset file path helper [\#182](https://github.com/owen2345/camaleon-cms/pull/182) ([cmckni3](https://github.com/cmckni3))
- Fixed indentation [\#181](https://github.com/owen2345/camaleon-cms/pull/181) ([pulkit21](https://github.com/pulkit21))
- Removed the hardcoded text and placed in en.yml file [\#180](https://github.com/owen2345/camaleon-cms/pull/180) ([pulkit21](https://github.com/pulkit21))
- Removed the text and placed in en.yml file [\#179](https://github.com/owen2345/camaleon-cms/pull/179) ([pulkit21](https://github.com/pulkit21))
- Removes hardcoded "Required Login" text [\#176](https://github.com/owen2345/camaleon-cms/pull/176) ([cmckni3](https://github.com/cmckni3))
- Swagger docs [\#173](https://github.com/owen2345/camaleon-cms/pull/173) ([raulanatol](https://github.com/raulanatol))
- Fixes syntax errors in api controller [\#171](https://github.com/owen2345/camaleon-cms/pull/171) ([cmckni3](https://github.com/cmckni3))
- Fixes css theme link tag in theme generator [\#170](https://github.com/owen2345/camaleon-cms/pull/170) ([cmckni3](https://github.com/cmckni3))
- Raise error when visiting unexisting urls. [\#169](https://github.com/owen2345/camaleon-cms/pull/169) ([flaranda](https://github.com/flaranda))
- Allow email domains up to 10 characters in the contact form plugin [\#166](https://github.com/owen2345/camaleon-cms/pull/166) ([flaranda](https://github.com/flaranda))
- Unify current\_user - Api login bug fixed [\#165](https://github.com/owen2345/camaleon-cms/pull/165) ([raulanatol](https://github.com/raulanatol))
- Added generic API response methods, render\_json\_error & render\_json\_ok [\#164](https://github.com/owen2345/camaleon-cms/pull/164) ([raulanatol](https://github.com/raulanatol))
- Version number space [\#163](https://github.com/owen2345/camaleon-cms/pull/163) ([raulanatol](https://github.com/raulanatol))
- Change nil to null [\#155](https://github.com/owen2345/camaleon-cms/pull/155) ([cmckni3](https://github.com/cmckni3))
- Fixes sitemap controller action [\#149](https://github.com/owen2345/camaleon-cms/pull/149) ([cmckni3](https://github.com/cmckni3))
- Fixes seo helper for alternate links [\#148](https://github.com/owen2345/camaleon-cms/pull/148) ([cmckni3](https://github.com/cmckni3))
- Cleans up plugin routes [\#143](https://github.com/owen2345/camaleon-cms/pull/143) ([cmckni3](https://github.com/cmckni3))
- Captcha enable/disable on user registration. [\#140](https://github.com/owen2345/camaleon-cms/pull/140) ([raulanatol](https://github.com/raulanatol))
- New hook to more actions outside the user form [\#139](https://github.com/owen2345/camaleon-cms/pull/139) ([raulanatol](https://github.com/raulanatol))
- Show layout selector even when there are no templates [\#138](https://github.com/owen2345/camaleon-cms/pull/138) ([cmckni3](https://github.com/cmckni3))
- Two hooks more [\#136](https://github.com/owen2345/camaleon-cms/pull/136) ([raulanatol](https://github.com/raulanatol))
- Page and Post api controllers added [\#135](https://github.com/owen2345/camaleon-cms/pull/135) ([raulanatol](https://github.com/raulanatol))
- Doorkeeper integration. [\#133](https://github.com/owen2345/camaleon-cms/pull/133) ([raulanatol](https://github.com/raulanatol))
- Decorates nav menu item inside of helper [\#130](https://github.com/owen2345/camaleon-cms/pull/130) ([cmckni3](https://github.com/cmckni3))
- Adds ability to customize email submission template from theme [\#125](https://github.com/owen2345/camaleon-cms/pull/125) ([cmckni3](https://github.com/cmckni3))
- Adds current version number to admin footer [\#122](https://github.com/owen2345/camaleon-cms/pull/122) ([cmckni3](https://github.com/cmckni3))
- User update more actions hook [\#116](https://github.com/owen2345/camaleon-cms/pull/116) ([raulanatol](https://github.com/raulanatol))
- Add form\_for f variable to user\_register\_form [\#115](https://github.com/owen2345/camaleon-cms/pull/115) ([raulanatol](https://github.com/raulanatol))
- Update en.yml [\#110](https://github.com/owen2345/camaleon-cms/pull/110) ([cmckni3](https://github.com/cmckni3))
- Adds eager load path [\#108](https://github.com/owen2345/camaleon-cms/pull/108) ([cmckni3](https://github.com/cmckni3))
- Content Types -\> Post Type [\#94](https://github.com/owen2345/camaleon-cms/pull/94) ([cmckni3](https://github.com/cmckni3))
- Adds migration documentation [\#92](https://github.com/owen2345/camaleon-cms/pull/92) ([cmckni3](https://github.com/cmckni3))
- Updates post\_type translations [\#91](https://github.com/owen2345/camaleon-cms/pull/91) ([cmckni3](https://github.com/cmckni3))
- Update html\_mailer.rb [\#87](https://github.com/owen2345/camaleon-cms/pull/87) ([raulanatol](https://github.com/raulanatol))
- Updates font awesome to 4.4.0 [\#77](https://github.com/owen2345/camaleon-cms/pull/77) ([cmckni3](https://github.com/cmckni3))
- Update jquery validate: Only alphabetical characters [\#76](https://github.com/owen2345/camaleon-cms/pull/76) ([froilanq](https://github.com/froilanq))
- Fix missing gems [\#73](https://github.com/owen2345/camaleon-cms/pull/73) ([cmckni3](https://github.com/cmckni3))
- Fix plugin contact\_form [\#71](https://github.com/owen2345/camaleon-cms/pull/71) ([pabloespa](https://github.com/pabloespa))
- Fixes theme thumbnail URL [\#67](https://github.com/owen2345/camaleon-cms/pull/67) ([cmckni3](https://github.com/cmckni3))
- Moves sidebar profile information to dropdown [\#66](https://github.com/owen2345/camaleon-cms/pull/66) ([cmckni3](https://github.com/cmckni3))
- Fix various [\#61](https://github.com/owen2345/camaleon-cms/pull/61) ([froilanq](https://github.com/froilanq))
- Use UTC time for theme installation time [\#58](https://github.com/owen2345/camaleon-cms/pull/58) ([cmckni3](https://github.com/cmckni3))
- Update en.yml [\#54](https://github.com/owen2345/camaleon-cms/pull/54) ([cmckni3](https://github.com/cmckni3))
- Fix name fields on user profile form [\#46](https://github.com/owen2345/camaleon-cms/pull/46) ([cmckni3](https://github.com/cmckni3))

## [0.2.0](https://github.com/owen2345/camaleon-cms/tree/0.2.0) (2015-09-05)
[Full Changelog](https://github.com/owen2345/camaleon-cms/compare/0.1.7...0.2.0)

**Closed issues:**

- Localization TinyMCE [\#51](https://github.com/owen2345/camaleon-cms/issues/51)
- Error with theme generator [\#43](https://github.com/owen2345/camaleon-cms/issues/43)
- re-adding footer to default theme? [\#25](https://github.com/owen2345/camaleon-cms/issues/25)

**Merged pull requests:**

- Don't use Gemfile.lock in Gems [\#52](https://github.com/owen2345/camaleon-cms/pull/52) ([cmckni3](https://github.com/cmckni3))
- Custom fields tinymce language should be the current locale [\#50](https://github.com/owen2345/camaleon-cms/pull/50) ([tavaresb](https://github.com/tavaresb))
- Don't rescue generic exception. This will hang the process [\#49](https://github.com/owen2345/camaleon-cms/pull/49) ([cmckni3](https://github.com/cmckni3))
- Elfinder initializer cleanup [\#48](https://github.com/owen2345/camaleon-cms/pull/48) ([cmckni3](https://github.com/cmckni3))
- Remove unnecessary SSL hack [\#47](https://github.com/owen2345/camaleon-cms/pull/47) ([cmckni3](https://github.com/cmckni3))
- Code style [\#45](https://github.com/owen2345/camaleon-cms/pull/45) ([cmckni3](https://github.com/cmckni3))
- Italian locale [\#44](https://github.com/owen2345/camaleon-cms/pull/44) ([mukkoo](https://github.com/mukkoo))

## [0.1.7](https://github.com/owen2345/camaleon-cms/tree/0.1.7) (2015-09-01)
**Closed issues:**

- "rails generate camaleon\_cms:install"  freezes [\#42](https://github.com/owen2345/camaleon-cms/issues/42)
- fix\_ssl.rb conflicts [\#40](https://github.com/owen2345/camaleon-cms/issues/40)
- AssetsFilteredError clean installation using gem [\#39](https://github.com/owen2345/camaleon-cms/issues/39)
- Can't install with the latest jruby [\#37](https://github.com/owen2345/camaleon-cms/issues/37)
- Error - Reorder custom fields groups [\#36](https://github.com/owen2345/camaleon-cms/issues/36)
- Feature Request: AWS s3 media upload [\#35](https://github.com/owen2345/camaleon-cms/issues/35)
- No such file or directory @ rb\_sysopen  [\#30](https://github.com/owen2345/camaleon-cms/issues/30)
- RTL Support [\#27](https://github.com/owen2345/camaleon-cms/issues/27)
- undefined method `translate'  [\#26](https://github.com/owen2345/camaleon-cms/issues/26)
- Unable to run migrations [\#24](https://github.com/owen2345/camaleon-cms/issues/24)
- Heroku app.json [\#23](https://github.com/owen2345/camaleon-cms/issues/23)
- Captcha Missing [\#22](https://github.com/owen2345/camaleon-cms/issues/22)
- Gems specified as Windows only in Gemfile [\#15](https://github.com/owen2345/camaleon-cms/issues/15)
- Commands in bin point to ruby.exe [\#14](https://github.com/owen2345/camaleon-cms/issues/14)
- Slug suffix [\#10](https://github.com/owen2345/camaleon-cms/issues/10)
- Layout Support [\#6](https://github.com/owen2345/camaleon-cms/issues/6)
- Upgrade Path [\#3](https://github.com/owen2345/camaleon-cms/issues/3)
- Does it work with PostgreSQL? [\#1](https://github.com/owen2345/camaleon-cms/issues/1)

**Merged pull requests:**

- Render widgets translated to the current locale [\#41](https://github.com/owen2345/camaleon-cms/pull/41) ([tavaresb](https://github.com/tavaresb))
- Added editorconfig file [\#33](https://github.com/owen2345/camaleon-cms/pull/33) ([raulanatol](https://github.com/raulanatol))
- \(Update\) Fix admin: left menus and breadcrum [\#31](https://github.com/owen2345/camaleon-cms/pull/31) ([froilanq](https://github.com/froilanq))
- Fix admin: left menus and breadcrumb [\#29](https://github.com/owen2345/camaleon-cms/pull/29) ([froilanq](https://github.com/froilanq))
- changed application controller name into camaleon controller [\#21](https://github.com/owen2345/camaleon-cms/pull/21) ([owen2345](https://github.com/owen2345))
- Fix gemfile indentation [\#20](https://github.com/owen2345/camaleon-cms/pull/20) ([cmckni3](https://github.com/cmckni3))
- Fixes unnecessary empty interpolation [\#19](https://github.com/owen2345/camaleon-cms/pull/19) ([cmckni3](https://github.com/cmckni3))
- Adds rubocop [\#18](https://github.com/owen2345/camaleon-cms/pull/18) ([cmckni3](https://github.com/cmckni3))
- Changes inactivated to deactivated [\#17](https://github.com/owen2345/camaleon-cms/pull/17) ([cmckni3](https://github.com/cmckni3))
- Ignores system.json [\#16](https://github.com/owen2345/camaleon-cms/pull/16) ([cmckni3](https://github.com/cmckni3))
- Database configuration samples [\#13](https://github.com/owen2345/camaleon-cms/pull/13) ([cmckni3](https://github.com/cmckni3))
- Cleans up .gitignore [\#12](https://github.com/owen2345/camaleon-cms/pull/12) ([cmckni3](https://github.com/cmckni3))
- Fixes .gitignore [\#11](https://github.com/owen2345/camaleon-cms/pull/11) ([cmckni3](https://github.com/cmckni3))
- Change actived translation to Activated [\#9](https://github.com/owen2345/camaleon-cms/pull/9) ([cmckni3](https://github.com/cmckni3))
- Remove extra plugin title in breadcrumbs [\#7](https://github.com/owen2345/camaleon-cms/pull/7) ([cmckni3](https://github.com/cmckni3))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*