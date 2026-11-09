# The forum: Thredded's models, forms and permission rules, used by the JSON
# forum API (ForumApiController, ForumModerationController). Its web pages are
# not mounted: the forum's interface is the IDE's Forum window.
# Settings not given here keep Thredded's defaults.

# ---- users ------------------------------------------------------------------
Thredded.user_class = "User"
Thredded.user_name_column = :name            # unique, used for @-mentions

# @-mentions in posts become links to this; there are no profile pages.
Thredded.user_path = ->(_user) { "#" }

# A coloured circle with the name's first letter, made here: no Gravatar, so no
# hash of anyone's email address leaves the site.
Thredded.avatar_url = lambda do |user|
  name = user.try(:name).to_s
  letter = ERB::Util.html_escape(name[0].to_s.upcase.presence || "?")
  hue = Zlib.crc32(name) % 360
  svg = <<~SVG.delete("\n")
    <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
    <circle cx="32" cy="32" r="32" fill="hsl(#{hue},50%,45%)"/>
    <text x="32" y="43" font-family="sans-serif" font-size="30" fill="#fff" text-anchor="middle">#{letter}</text>
    </svg>
  SVG
  "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
end

# ---- permissions and moderation -------------------------------------------
# Administrators come from ADMIN_USERS (User#thredded_admin?); moderators are
# administrators and users with forum_moderator set (User#forum_staff?).
Thredded.moderator_column = :forum_moderator

# Pre-emptive moderation: a new user's posts are hidden until a moderator
# approves the user. After that their posts appear at once.
Thredded.content_visible_while_pending_moderation = false

# For learners: no private messages, and no list of who is online.
Thredded.private_messaging_enabled = false
Thredded.currently_online_enabled = false

# ---- email --------------------------------------------------------------------
# No email: Thredded's notification emails link to its web pages, which are
# not served. Followed topics show up in the IDE's Unread topics instead.
Thredded.notifiers = []
