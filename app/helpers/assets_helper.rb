module AssetsHelper
  # Get the translation of the categories of an Asset object
  # @param type [Asset.category]
  def asset_category_label(category)
    key = "asset.categories.#{category}"

    I18n.exists?(key) ? I18n.t(key) : category.to_s.titleize
  end
end
