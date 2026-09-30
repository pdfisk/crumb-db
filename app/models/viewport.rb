# A saved FastBlip screen: the JSON a program's Viewport writes with
# toJson / save ({ "format": "fastblip-viewport", "version": 1, ... }).
class Viewport < ApplicationRecord
  self.table_name = "viewport"

  FORMAT = "fastblip-viewport".freeze

  validates :name, presence: true, uniqueness: true
  validate :content_must_be_a_saved_viewport

  private

  def content_must_be_a_saved_viewport
    unless content.is_a?(Hash)
      errors.add(:content, "must be a JSON object")
      return
    end
    errors.add(:content, %(must have "format": "#{FORMAT}")) unless content["format"] == FORMAT
  end
end
