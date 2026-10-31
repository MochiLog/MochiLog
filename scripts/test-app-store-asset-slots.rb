require "minitest/autorun"
require_relative "app-store-asset-slots"

class AppStoreAssetSlotsTest < Minitest::Test
  def placement(id, locale: "draft-ja", group: "duo", type: "APP_SCREENSHOT")
    {"id" => id, "attributes" => {"placementType" => type, "placementGroup" => group},
      "relationships" => {"image" => {"data" => {"id" => "image-#{id}"}},
        "appStoreVersionLocalization" => {"data" => {"id" => locale}}}}
  end

  def select(rows, desired: [])
    AppStoreAssetSlots.replacements(rows, desired_ids: desired, localization: "draft-ja", group: "duo")
  end

  def test_eight_inherited_images_do_not_need_a_slot_yet
    assert_empty select(8.times.map { |i| placement(i.to_s) })
  end

  def test_ten_images_keep_new_images_and_free_one_inherited_slot
    rows = 10.times.map { |i| placement(i.to_s) }
    assert_equal [rows[2]], select(rows, desired: ["image-0", "image-1"])
  end

  def test_other_device_groups_and_creatives_are_ignored
    rows = 8.times.map { |i| placement(i.to_s) }
    rows += [placement("ipad", group: "ipad"), placement("header", type: "PRODUCT_PAGE_HEADER_ASSET")]
    assert_empty select(rows)
  end

  def test_never_detaches_another_version_or_localization
    rows = 10.times.map { |i| placement(i.to_s, locale: "public-ja") }
    assert_raises(RuntimeError) { select(rows) }
  end

  def test_never_removes_a_desired_image_to_fit
    rows = 10.times.map { |i| placement(i.to_s) }
    assert_raises(RuntimeError) { select(rows, desired: rows.map { |r| "image-#{r['id']}" }) }
  end

  def test_unresolved_localization_must_be_fetched_before_detaching
    rows = 10.times.map { |i| placement(i.to_s) }
    rows.each { |row| row["relationships"].delete("appStoreVersionLocalization") }
    assert_raises(RuntimeError) { select(rows) }
  end
end
