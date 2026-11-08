# The forum's board groups and boards (Thredded).
#
#   bin/rails forum:seed        (also run by db:seed, and on each Heroku release)
#
# Creates only what is missing, found by group name and board slug, so it is
# safe to run again: a board renamed or re-described on the site is left as it
# is. Positions set the order on the front page.

forum_boards = [
  {
    group: "FastBlips",
    boards: [
      { slug: "announcements", name: "Announcements", locked: true,
        description: "News about FastBlips: new features, changes and events. Only moderators start topics here; anyone can reply." },
      { slug: "ideas", name: "Ideas and feature requests",
        description: "Something FastBlips should do? Suggest it here, or add your support to someone else's idea." },
      { slug: "bugs", name: "Bugs",
        description: "Something not working? Say what you did, what you expected and what happened. A link to your BLIP helps." },
    ],
  },
  {
    group: "Learning",
    boards: [
      { slug: "getting-started", name: "Getting started",
        description: "New to FastBlips or to programming? Ask anything here: no question is too small." },
      { slug: "python", name: "BlipPy (Python)",
        description: "Writing Python in FastBlips: the language, errors and how to do things." },
      { slug: "widgets", name: "Widgets and the Designer",
        description: "Building screens: widgets, layouts and the visual Designer." },
    ],
  },
  {
    group: "Community",
    boards: [
      { slug: "show-and-tell", name: "Show and tell",
        description: "Share what you've made. Post a link to your BLIP so others can run it and open a copy." },
    ],
  },
]

board_position = 0
forum_boards.each_with_index do |entry, group_index|
  group = Thredded::MessageboardGroup.find_or_create_by!(name: entry[:group]) do |g|
    g.position = group_index + 1
  end

  entry[:boards].each do |attrs|
    board_position += 1
    next if Thredded::Messageboard.exists?(slug: attrs[:slug])

    Thredded::Messageboard.create!(
      slug: attrs[:slug],
      name: attrs[:name],
      description: attrs[:description],
      locked: attrs.fetch(:locked, false),
      messageboard_group_id: group.id,
      position: board_position
    )
    puts "forum: created board #{attrs[:name]} (/#{attrs[:slug]})" unless Rails.env.test?
  end
end
