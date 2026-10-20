require "io/console"

namespace :users do
  desc "Set (or reset) a user's password and sign them out everywhere: bin/rails \"users:set_password[peter]\""
  task :set_password, [ :name ] => :environment do |_task, args|
    user = User.find_by("lower(name) = ?", args[:name].to_s.downcase)
    abort "No user called #{args[:name].inspect}." unless user

    password = $stdin.getpass("New password for #{user.name}: ")
    abort "The two passwords differ." unless password == $stdin.getpass("Again: ")

    user.password = password
    abort user.errors.full_messages.to_sentence unless user.save
    user.api_tokens.delete_all
    puts "Password set for #{user.name}."
  end

  desc "Lists the users who have no password yet (they cannot sign in)"
  task without_password: :environment do
    User.where(password_digest: nil).order(:name).each { |u| puts u.name }
  end
end
