namespace :forum do
  desc "Create the forum's board groups and boards that are missing (safe to run again)"
  task seed: :environment do
    load Rails.root.join("db/seeds/forum.rb")
  end
end
