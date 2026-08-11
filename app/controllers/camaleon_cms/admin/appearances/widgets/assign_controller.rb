module CamaleonCms
  module Admin
    module Appearances
      module Widgets
        class AssignController < CamaleonCms::AdminController
          include CamaleonCms::Admin::CustomFieldsConcern

          before_action :check_permission_role
          before_action :find_sidebar
          before_action :find_assigned_sidebar, only: %i[update destroy]

          def new
            @widget = current_site.widgets.find(params[:widget_id])
            @assigned = @sidebar.assigned.create!({ title: 'Default', widget_id: @widget.id })
            render partial: 'form', locals: { assigned: @assigned, widget: @widget, sidebar: @sidebar },
                   layout: 'camaleon_cms/admin/ajax'
          end

          def update
            # sidebar_id (post_parent) and widget_id (visibility) identify the tenant-scoped sidebar and
            # widget this assignment belongs to; they are set from @sidebar/@widget on create and must
            # not be reassigned from the request, or the assignment could be re-pointed into another
            # site's sidebar or widget (audit finding H9). Reordering has its own current-site-scoped
            # action (sidebar#reorder).
            if @assigned.update(params.require(:assign).permit(:title, :content, :item_order))
              @assigned.set_field_values(cama_permitted_field_options('Main'))
              flash[:notice] = t('camaleon_cms.admin.widgets.assign.updated')
            else
              flash[:error] = t('camaleon_cms.admin.widgets.assign.error_updated')
            end
            redirect_to cama_admin_appearances_widgets_main_index_path
          end

          def destroy
            @assigned.destroy
            render plain: ''
          end

          private

          def find_sidebar
            @sidebar = current_site.sidebars.find(params[:sidebar_id])
          end

          def find_assigned_sidebar
            @assigned = @sidebar.assigned.find(params[:id])
          end

          def check_permission_role
            authorize! :manage, :widgets
          end
        end
      end
    end
  end
end
