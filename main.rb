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
queues = {} #Queues example: { :queue_a => { size: 3, ids: [ ID, ID ] }, :queue_b => { size: 1, ids: [ ID, ID ] } }
bot.command(:queue, channels: [CONFIG['bot_channel']]) do |event, action, *args| #!queue join <name>,  !queue next <name>, !queue join 
	if action == ""
		event.channel.send_embed do |embed|
			embed.fields = [
				{ name: 'Usage:', value: '`!queue join queuename queuename2`
				`!queue position queuename queuename2`
				`!queue leave queuename queuename2`'},
				{ name: 'Valid queues:', value: "`#{queues.keys.join("` `")}`" }
			]
			embed.color = CONFIG['colors']['error']
		end
		return
	end
	# No permission for these
	case action
	when "join" # Join given queue(s)
		if args.length == 0
			event.message.react '❓'
			return
		elsif args.length == 1 # Join all queues
			if args[0] == "all"
				args = queues.keys
			end
		end
		# foreach try to add, react "?" if no queue found, "X" if already in queue, checkmark success
		args.each do |queue_name|
			if !queues.key?(:"#{queue_name}") # Does not exist
				event.message.react '❓'
			elsif queues[:"#{queue_name}"][:ids].include?(event.author.id) # Already in queue
				event.message.react '❌'
			else # Good to go
				queues[:"#{queue_name}"][:ids].append(event.author.id)
				event.message.react '✅'
			end
		end
		
		return
	when "position" # Number in queue
		if args.length ==  0 
			args = queues.keys
		elsif args.length == 1 # Get position for all queues
			if args[0] == "all"
				args = queues.keys
			end
		end
		embed_fields = []
		args.each do |queue_name|
			queue_sym = :"#{queue_name}"
			return event.message.react '❓' unless queues.key?(queue_sym) #Does not exist
			
			if queues[queue_sym][:ids].include?(event.author.id) # In queue
				size = queues[queue_sym][:size]
				#puts "Queue has active size of #{size}"
				userIndex = queues[queue_sym][:ids].find_index(event.author.id)
				#puts "User at index #{userIndex}"
				pos = userIndex - size
				embed_fields.append({ name: "#{queue_name} position:", value: "`#{pos}`" })
			end
		end
		if embed_fields.length > 0
			event.channel.send_embed do |embed|
				embed.fields = embed_fields
				embed.color = CONFIG['colors']['success']
			end
			#event.message.react '✅'
		else
			event.channel.send_embed do |embed|
				embed.description = "You are not\tin any queues."
				embed.color = CONFIG['colors']['info']
			end
			#event.message.react '❌'
		end
		return
	when "leave" # Leave given queue(s)
		if args.length == 0 # Leave all queues
			event.message.react '❓'
			return
		elsif args.length == 1 # Could be "all"
			if args[0] == "all"
				args = queues.keys
			end
		end
		args.each do |queue_name|
			event.message.react '❓' unless queues.key?(:"#{queue_name}") #Does not exist
			event.message.react '❌' unless queues[:"#{queue_name}"][:ids].include?(event.author.id) #Not in queue
			
			queues[:"#{queue_name}"][:ids].delete(event.author.id)
		end
		event.message.react '✅'
		return
	end
	
	# Permission admin needed for these
	if event.author.roles.any? { |r| r.id == CONFIG['roles']['admin'] }
		case action
		when "new" # Create new queue by name
			if args.length == 2 # We need a queue name and size
				queue_name = args[0]
				size = args[1]
				if !queues.key?(:"#{queue_name}") # Queue doesn't exist
					# Create new queue
					queues.merge!(:"#{queue_name}" => { size: size.to_i, ids: Array.new(size.to_i, 0) })
					return event.message.react '✅'
				else
					# Queue already exists
					event.channel.send_embed do |embed|
						embed.description = "Queue #{queue_name} already exists."
						embed.color = CONFIG['colors']['error']
					end
					return
				end
			end
			# 'help new' here
			return
		when "next" # Remove first n entries from the queue # If no number follows the queue name, assume n = 1
			if (1..2) === args.length # Name at least, optionally a number
				queue_sym = :"#{args[0]}"
				if queues.key?(queue_sym) # Make sure queue exists
					n = args.length == 2 ? args[1].to_i > 0 ? args[1].to_i : 1 : 1 # Force n > 0
					queues[queue_sym][:ids].shift(n)
					return event.message.react '✅'
				else
					return event.message.react '❓'
				end
			end
			# 'help next' here
			return
		when "remove" # Delete queue by name
			if args.length == 1 # Need the name of queue to remove
				queue_sym = :"#{args[0]}"
				if queues.key?(queue_sym) # Queue exists
					#TODO: Maybe add confirm message with a timeout and positive reaction as confirmiation
					queues.delete(queue_sym)
					#TODO: Delete confirm message after timeout or confirmation
					return event.message.react '✅'
				else
					# Queue does not exist
					event.channel.send_embed do |embed|
						embed.description = "Queue #{queue_name} does not exist."
						embed.color = CONFIG['colors']['error']
					end
					return
				end
			end
			# 'help remove' here
			return
		end
	end
	
	event.channel.send_embed do |embed|
			embed.fields = [
				{ name: 'Usage:', value: '`!queue join` (Joins ALL queues)
				`!queue join queuename queuename2`
				`!queue position queuename queuename2`
				`!queue leave queuename queuename2`
				`!queue leave` (Leaves ALL queues)' },
				{ name: 'Valid queues:', value: "`#{queues.keys.join("` `")}`" }
			]
			embed.color = CONFIG['colors']['error']
		end
	
	return event.message.react '❓'
end

# Start bot
bot.ready { puts 'Bot is ready.' }
at_exit { bot.stop }
bot.run