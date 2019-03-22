class CamaleonCms::Admin::FormsController < CamaleonCms::AdminController

  def index
  end

  def materials
    @posts = MaterialsForm.order(created_at: :desc)
  end

  def nutritions
    @posts = NutritionsForm.order(created_at: :desc)
  end

  def pharmacy 
    @posts = PharmacyForm.order(created_at: :desc)
  end

  def media_inquiry 
    @posts = MediaInquiryForm.order(created_at: :desc)
  end

  def product_change 
    @posts = ProductChangeForm.order(created_at: :desc).with_attached_images
  end

end