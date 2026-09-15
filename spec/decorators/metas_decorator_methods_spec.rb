# frozen_string_literal: true

# the_meta and the_option translate the read, which only a String or an Array can do: a meta or option
# stored as a number or a boolean raised once the record was loaded again, and on the writing instance
# too now that it reads the stored form.
RSpec.describe CamaleonCms::MetasDecoratorMethods do
  let(:post_type) { CamaleonCms::Site.first.post_types.find_by!(slug: 'post') }
  let(:post) { create(:post, post_type: post_type) }
  let(:translatable) { { en: 'Hello', es: 'Hola' }.to_translate }

  def decorated(record)
    record.decorate.tap { |decorator| decorator.set_decoration_locale(:es) }
  end

  it 'returns a meta stored as a number or a boolean as read, on the writing instance and after a reload' do
    post.set_metas(year: '2024', featured: 'true')
    reloaded = CamaleonCms::Post.find(post.id)

    expect([decorated(post).the_meta('year'), decorated(post).the_meta('featured')]).to eq([2024, true])
    expect([decorated(reloaded).the_meta('year'), decorated(reloaded).the_meta('featured')]).to eq([2024, true])
  end

  it 'translates a String meta and the Strings of an Array meta' do
    post.set_meta('greeting', translatable)
    post.set_meta('greetings', [translatable, 'plain'])

    expect(decorated(post).the_meta('greeting')).to eq('Hola')
    expect(decorated(post).the_meta('greetings')).to eq(%w[Hola plain])
  end

  it 'returns an option stored as a number as read and translates a String option' do
    post.set_options(year: '2024', greeting: translatable)
    reloaded = CamaleonCms::Post.find(post.id)

    expect([decorated(post).the_option('year'), decorated(post).the_option('greeting')]).to eq([2024, 'Hola'])
    expect([decorated(reloaded).the_option('year'), decorated(reloaded).the_option('greeting')]).to eq([2024, 'Hola'])
  end
end
