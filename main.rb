# frozen_string_literal: true

require 'discordrb'
require 'yaml'

CONFIG = YAML.load_file('config.yml')

bot = Discordrb::Commands::CommandBot.new token: CONFIG['token'], prefix: CONFIG['prefix']

# Command for role assignment
bot.command(:role, channels: [CONFIG['bot_channel']]) do |event, action, *roles|
  if %w[add remove].include? action
    roles.each do |r|
      return event.message.react '❓' unless CONFIG['class_roles'][r]

      if action == 'add'
        event.author.add_role(CONFIG['class_roles'][r])
      else
        event.author.remove_role(CONFIG['class_roles'][r])
      end
    end
    event.message.react '✅'
  else # list roles if no action given
    event.channel.send_embed do |embed|
      embed.fields = [
        { name: 'Usage:', value: '`!role add role role2 ...`
        `!role remove role role2 ...`' },
        { name: 'Valid roles:', value: "`#{CONFIG['class_roles'].keys.join('` `')}`" }
      ]
      embed.color = CONFIG['colors']['error']
    end
  end
end

# command to create new class role & channel
bot.command(:newclass, required_roles: [CONFIG['roles']['admin']]) do |event, name|
  return event.message.react '❓' unless name && name =~ /\w+\d+/

  server = event.server

  new_role = server.create_role(name: name)

  # update !role list with new role
  CONFIG['class_roles'][name] = new_role.id
  File.write('config.yml', CONFIG.to_yaml)

  can_view = Discordrb::Permissions.new
  can_view.can_read_messages = true # AKA view_channel

  new_channel = server.create_channel(
    "#{name.insert(name =~ /\d/, '-')}-questions",
    parent: CONFIG['class_category'],
    permission_overwrites: [
      Discordrb::Overwrite.new(new_role, allow: can_view),
      Discordrb::Overwrite.new(CONFIG['class_roles']['all'], allow: can_view),
      Discordrb::Overwrite.new(server.everyone_role, deny: can_view)
    ]
  )

  event.channel.send_embed do |embed|
    embed.description = "Channel #{new_channel.mention} and role #{new_role.mention} created."
    embed.color = CONFIG['colors']['success']
  end
end

# Command to tally and acknowledge praises to the God King Evan
bot.command :praise do |event|
  praises = File.open('praises').read.to_i
  praises += 1
  event.channel.send_embed do |embed|
    embed.title = '🙏 Praise be to Evan! 🙏'
    embed.description = "*Praises x#{praises}*"
    embed.color = CONFIG['colors']['success']
    embed.thumbnail = {
      url: 'https://media.discordapp.net/attachments/758182759683457035/758243415459627038/TempDorime.png'
    }
  end
  File.open('praises', 'w') { |f| f.write praises }
  nil
end

# add :pray: react to the God King (praise be btw)
bot.message do |event|
  event.message.react '🙏' if event.author.roles.any? { |r| r.id == CONFIG['roles']['god'] }
end

# add role on member join
bot.member_join do |event|
  event.user.add_role(CONFIG['roles']['disciple'])
end

# Queueing commands, allowing users to join and leave FIFO queues
queues = {} #Queues example: { queue_a: { size: 3, queue: [ ID, ID, ... ] }, queue_b: { size: 1, queue: [ ID, ID, ... ] } }
bot.command(:queue, channels: [CONFIG['bot_channel']]) do |event, action, *args| #!queue join <name>,  !queue next <name>, !queue join 
	# No permission for these
	case action
	when "join"
	when "leave" # Leave given queue(s)
	when "" #Help embed
		event.channel.send_embed do |embed|
			embed.fields = [
				{ name: 'Usage:', value: '`!queue join queuename`
				`!role leave queuename queuename2`
				`!role leave all`' },
				{ name: 'Valid queues:', value: "`#{queues.keys.join("` `")}`" }
			]
			embed.color = CONFIG['colors']['error']
		end
	end
	
	# Permissions (admin) for these
	if event.author.roles.any? { |r| r.id == CONFIG['roles']['god'] }
		case action
		when "new" # Create new queue by name
			if args.length == 1 #We need queue name
				if !queues.key?(args[0])
					# Create new queue
					return event.message.react '✅'
				else
					return event.message.react '❓'
				end
			else
				return event.message.react '❓'
			end
		when "next" # Remove first n entries from the queue # If no number follows "next", assume n = 1
			if queues.key?(args[0]) # Make sure queue exists
				n = args.length == 2 : args[1] ? 1
				queues[args[0]].shift(n)
				return event.message.react '✅'
			else
				return event.message.react '❓'
			end
		when "remove" # Delete queue by name
			
		end
	end
	return event.message.react '❓'
end

# Start bot
bot.ready { puts 'Bot is ready.' }
at_exit { bot.stop }
bot.run