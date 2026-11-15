# frozen_string_literal: true

RSpec.describe CamaleonRecord, type: :model do
  describe '.polymorphic_class_for' do
    it 'resolves legacy user polymorphic names' do
      expected = CamaManager.get_user_class_name.to_s.constantize

      expect(described_class.polymorphic_class_for('User')).to eq(expected)
    end

    it 'resolves legacy custom field owner types for post type variants' do
      expect(described_class.polymorphic_class_for('PostType_Post')).to eq(CamaleonCms::PostType)
    end

    it 'ignores internal marker polymorphic names' do
      expect(described_class.polymorphic_class_for('_fields')).to be_nil
    end

    context 'when the host app defines a top-level class with the name of a Camaleon model' do
      %w[Post Site Theme Category PostTag PostType NavMenuItem NavMenu CustomField CustomFieldGroup].each do |name|
        it "resolves '#{name}' to CamaleonCms::#{name}" do
          stub_const(name, Class.new)

          expect(described_class.polymorphic_class_for(name)).to eq("CamaleonCms::#{name}".constantize)
        end
      end

      it "resolves 'User' to the user class of Camaleon" do
        stub_const('User', Class.new)

        expect(described_class.polymorphic_class_for('User')).to eq(CamaManager.get_user_class_name.to_s.constantize)
      end

      it "resolves 'User' to a configured user class of the host app" do
        stub_const('User', Class.new)
        stub_const('HostAdmin', Class.new)
        allow(CamaManager).to receive(:get_user_class_name).and_return('HostAdmin')

        expect(described_class.polymorphic_class_for('User')).to eq(HostAdmin)
      end

      it "resolves 'User' to the host User when the configured user class does not exist" do
        stub_const('User', Class.new)
        allow(CamaManager).to receive(:get_user_class_name).and_return('MissingHostAdmin')

        expect(described_class.polymorphic_class_for('User')).to eq(User)
      end

      it 'gives the Camaleon post as the owner of a meta of that post' do
        post = create(:post)
        post.set_meta('host_owner_check', 'value')
        # A host model. The dummy app has no ApplicationRecord.
        stub_const('Post', Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
          self.table_name = CamaleonCms::Post.table_name
          self.inheritance_column = nil
        end)

        meta = CamaleonCms::Meta.find_by!(object_class: 'Post', objectid: post.id, key: 'host_owner_check')

        expect(meta.owner).to eq(post)
        expect(CamaleonCms::Meta.includes(:owner).find(meta.id).owner).to eq(post)
      end
    end

    it "resolves 'User' to CamaleonCms::User when the configured user class does not exist" do
      allow(CamaManager).to receive(:get_user_class_name).and_return('MissingHostAdmin')

      expect(described_class.polymorphic_class_for('User')).to eq(CamaleonCms::User)
    end

    it "resolves the widget scope 'Main' to CamaleonCms::Widget::Main" do
      expect(described_class.polymorphic_class_for('Main')).to eq(CamaleonCms::Widget::Main)
    end

    it "resolves 'Main' to the widget class also when the host app defines a top-level Main" do
      stub_const('Main', Class.new)

      expect(described_class.polymorphic_class_for('Main')).to eq(CamaleonCms::Widget::Main)
    end

    it "resolves the widget scopes 'Sidebar' and 'Assigned' to their widget classes" do
      expect(described_class.polymorphic_class_for('Sidebar')).to eq(CamaleonCms::Widget::Sidebar)
      expect(described_class.polymorphic_class_for('Assigned')).to eq(CamaleonCms::Widget::Assigned)
    end

    it 'gives the widget as the owner of a meta of that widget' do
      widget = create(:site).widgets.create!(name: 'Owner widget', slug: 'owner-widget')
      widget.set_meta('widget_owner_check', 'value')

      meta = CamaleonCms::Meta.find_by!(object_class: 'Main', objectid: widget.id, key: 'widget_owner_check')

      expect(meta.owner).to eq(widget)
    end

    it 'resolves a short name with no Camaleon model to the top-level class' do
      stub_const('HostDownload', Class.new)

      expect(described_class.polymorphic_class_for('HostDownload')).to eq(HostDownload)
    end

    it "resolves 'Ability' to the top-level class, as CamaleonCms::Ability is no model" do
      stub_const('Ability', Class.new)

      expect(described_class.polymorphic_class_for('Ability')).to eq(Ability)
    end

    it 'resolves a name with :: to the class of that name' do
      stub_const('Plugins::HostShop::Post', Class.new)

      expect(described_class.polymorphic_class_for('Plugins::HostShop::Post')).to eq(Plugins::HostShop::Post)
      expect(described_class.polymorphic_class_for('CamaleonCms::Post')).to eq(CamaleonCms::Post)
    end
  end
end
