# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Frontend::NavMenuHelper do
  init_site

  before do
    @menu = create(:nav_menu, name: 'Main Menu', slug: 'main_menu', parent: @site)
    allow(helper).to receive_messages(site_current_path: '/', cama_root_url: '/')
  end

  describe '#cama_menu_draw_items' do
    let(:default_args) do
      {
        menu_slug: 'main_menu',
        container: 'ul',
        container_class: 'nav navbar-nav',
        item_container: 'li',
        item_class: 'menu-item',
        item_class_parent: 'dropdown',
        item_current: 'current-menu-item',
        sub_container: 'ul',
        sub_class: 'dropdown-menu',
        link_class: 'menu_link',
        link_class_parent: 'dropdown-toggle',
        link_current: 'current-link',
        levels: -1,
        callback_item: ->(args) {},
        before: '',
        after: '',
        link_before: '',
        link_after: '',
        container_prepend: '',
        container_append: '',
        container_id: ''
      }
    end

    context 'with a single menu item' do
      before do
        @menu_item = create(:nav_menu_item, name: 'Home', url: '/home', kind: 'external', target: '', parent: @menu)
      end

      it 'renders the item as an li tag with an a tag inside' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include('<li')
        expect(result).to include("class='menu-item'")
        expect(result).to include('<a')
        expect(result).to include("href='/home'")
        expect(result).to include("class='menu_link'")
        expect(result).to include('</li>')
      end

      it 'does not escape HTML entities in the output' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).not_to include('&lt;li&gt;')
        expect(result).not_to include('&lt;a ')
      end
    end

    context 'with current menu item' do
      before do
        @menu_item = create(:nav_menu_item, name: 'About', url: '/about', kind: 'external', target: '', parent: @menu)
        allow(helper).to receive(:site_current_path).and_return('/about')
      end

      it 'adds the current item class to the li element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("class='menu-item current-menu-item'")
      end

      it 'adds the link current class to the a element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("class='current-link menu_link'")
      end
    end

    context 'with menu item that has children' do
      before do
        @parent_item =
          create(:nav_menu_item, name: 'Services', url: '/services', kind: 'external', target: '', parent: @menu)
        @child_item = create(
          :nav_menu_item, name: 'Design', url: '/design', kind: 'external', target: '', parent_item: @parent_item
        )
      end

      it 'adds the parent class to the li element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("class='menu-item dropdown'")
      end

      it 'adds the dropdown-toggle class to the a element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("class='dropdown-toggle menu_link'")
      end

      it 'adds data-toggle attribute to the a element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("data-toggle='dropdown'")
      end

      it 'renders children inside a sub ul container' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("<ul class='dropdown-menu level-1'>")
        expect(result).to include('Design')
        expect(result).to include('</ul>')
      end

      context 'when child item is current' do
        before { allow(helper).to receive(:site_current_path).and_return('/design') }

        it 'adds current-menu-ancestor class to the parent li' do
          result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

          expect(result).to include('current-menu-ancestor')
        end

        it 'adds parent-current class to the sub ul' do
          result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

          expect(result).to include('parent-current-menu-item')
        end
      end
    end

    context 'with target attribute' do
      before do
        @menu_item = create(
          :nav_menu_item,
          name: 'External', url: 'https://example.com', kind: 'external', target: '_blank', parent: @menu
        )
      end

      it 'renders the target attribute on the a tag' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("target='_blank'")
      end
    end

    context 'with unsafe menu values' do
      before do
        @menu_item = create(
          :nav_menu_item,
          name: 'Embedded',
          url: "/search?q=' onclick='alert(1)",
          kind: 'external',
          target: "_blank' rel='bad",
          parent: @menu
        )
        allow(helper).to receive(:cama_parse_menu_item).and_return(
          link: "/search?q=' onclick='alert(1)",
          name: '<iframe src="https://example.test/embed"></iframe>',
          current: false
        )
      end

      it 'keeps trusted HTML labels while escaping attribute values' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include('<iframe src="https://example.test/embed"></iframe>')
        expect(result).to include("href='/search?q=&#39; onclick=&#39;alert(1)'")
        expect(result).to include("target='_blank&#39; rel=&#39;bad'")
      end
    end

    context 'with before/after content' do
      before do
        @menu_item =
          create(:nav_menu_item, name: 'Contact', url: '/contact', kind: 'external', target: '', parent: @menu)

        default_args[:before] = '<span class="icon">'
        default_args[:after] = '</span>'
      end

      it 'includes before content inside the a tag' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include('<span class="icon">Contact</span>')
      end
    end

    context 'with link_before/link_after wrapper' do
      before do
        @menu_item = create(:nav_menu_item, name: 'Blog', url: '/blog', kind: 'external', target: '', parent: @menu)

        default_args[:link_before] = '<em>'
        default_args[:link_after] = '</em>'
      end

      it 'wraps the link with link_before and link_after' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include('<em><a ')
        expect(result).to include('</a></em>')
      end
    end

    context 'with custom item_container_attrs from callback' do
      before do
        @menu_item = create(:nav_menu_item, name: 'Custom', url: '/custom', kind: 'external', target: '', parent: @menu)

        default_args[:callback_item] = lambda { |args|
          args[:item_container_attrs] = "id='custom-id' data-role='nav'"
        }
      end

      it 'includes custom item container attributes' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("id='custom-id'")
        expect(result).to include("data-role='nav'")
      end
    end

    context 'with custom link_attrs from callback' do
      before do
        @menu_item = create(:nav_menu_item, name: 'Custom', url: '/custom', kind: 'external', target: '', parent: @menu)

        default_args[:callback_item] = lambda { |args|
          args[:link_attrs] = "id='custom-link' data-action='click'"
        }
      end

      it 'includes custom link attributes' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include("id='custom-link'")
        expect(result).to include("data-action='click'")
      end
    end

    context 'when item is skipped via cama_parse_menu_item' do
      before do
        @menu_item = create(:nav_menu_item, name: 'Hidden', url: '/hidden', kind: 'external', target: '', parent: @menu)
        allow(helper).to receive(:cama_parse_menu_item).and_return(false)
      end

      it 'does not render the item' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to be_blank
      end
    end

    context 'with multiple items' do
      before do
        @item1 = create(:nav_menu_item, name: 'First', url: '/first', kind: 'external', target: '', parent: @menu)
        @item2 = create(:nav_menu_item, name: 'Second', url: '/second', kind: 'external', target: '', parent: @menu)
      end

      it 'renders all items concatenated' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result).to include('First')
        expect(result).to include('Second')
      end

      it 'renders each item as a separate li element' do
        result = helper.cama_menu_draw_items(default_args, @menu.children.reorder(:term_order))

        expect(result.scan(/<li/).count).to eq(2)
        expect(result.scan(%r{</li>}).count).to eq(2)
      end
    end
  end
end
