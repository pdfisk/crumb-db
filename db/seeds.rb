Script.find_or_create_by!(name: "hello.py", language: "python") { |r| r.content = 'print("Hello, world!")' }

# The forum's board groups and boards (also: bin/rails forum:seed).
load Rails.root.join("db/seeds/forum.rb")
