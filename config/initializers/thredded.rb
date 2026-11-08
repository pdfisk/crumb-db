# The forum: Thredded, mounted at "/" on the forum host (config/routes.rb).
# Its controllers inherit from ApplicationController and use the "forum" layout.
# Settings not given here keep Thredded's defaults.

# ---- users ------------------------------------------------------------------
Thredded.user_class = "User"
Thredded.user_name_column = :name            # unique, used for @-mentions
Thredded.current_user_method = :current_forum_user

# No public profile pages yet: a name links to the forum's front page.
Thredded.user_path = ->(_user) { "/" }

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

# ---- pages --------------------------------------------------------------------
Thredded.layout = "forum"

# ---- email --------------------------------------------------------------------
Thredded.email_from = ENV.fetch("FORUM_EMAIL_FROM", "FastBlips Forum <forum@fastblips.com>")
Thredded.email_outgoing_prefix = "[FastBlips Forum] "

# No mail is sent until a mail provider is set up (Phase 7): then set
# FORUM_EMAIL=1 to notify users of replies in topics they follow.
Thredded.notifiers = ENV["FORUM_EMAIL"] == "1" ? [Thredded::EmailNotifier.new] : []

# ---- signing in ---------------------------------------------------------------
# A page that needs someone signed in goes to the sign-in form (and back after),
# rather than Thredded's "forbidden" page.
Rails.application.config.to_prepare do
  Thredded::ApplicationController.class_eval do
    rescue_from Thredded::Errors::LoginRequired do
      redirect_to main_app.forum_sign_in_path(return_to: request.fullpath)
    end
  end
end
