class "LobbyManager"
function LobbyManager:__init()


	self.count = 0
	self.players = {}
	self.playerIds = {}

	self.events = {}
	self:CreateDerbyEvent()

	Events:Subscribe("PlayerChat", self, self.ChatMessage)
end

function LobbyManager:CreateDerbyEvent()
	self.currentDerby = self:DerbyEvent(self:GenerateName())
end
function LobbyManager:DerbyEvent(name)
	local Derby = Derby(name, self, World.Create())
	table.insert(self.events, Derby)

	self.count = self.count + 1
	return Derby
end

function LobbyManager:GenerateName()
	return "Derby-"..tostring(self.count)
end

-------------
--CHAT SHIT--
-------------
function LobbyManager:MessagePlayer(player, message)
	player:SendChatMessage( "[Derby-" .. tostring(self.count) .."] " .. message, Color(30, 200, 220) )
end

function LobbyManager:MessageGlobal(message)
	Chat:Broadcast( "[Derby-" .. tostring(self.count) .."] " .. message, Color(0, 255, 255) )
end

function LobbyManager:HasPlayer(player)
	return self.playerIds[player:GetId()]
end
function LobbyManager:RemovePlayer(player)
	for index, event in ipairs(self.events) do
		if (event.players[player:GetId()]) then
			event:RemovePlayer(player, "You have been removed from the Derby event.")
		end
	end
end

function LobbyManager:ChatMessage(args)
	local msg = args.text
	local player = args.player
	
	-- If the string is't a command, we're not interested!
	if ( msg:sub(1, 1) ~= "/" ) then
		return true
	end    
	
	local cmdargs = {}
	for word in string.gmatch(msg, "[^%s]+") do
		table.insert(cmdargs, word)
	end
	
	if (cmdargs[1] == "/derby") then 
		if (self.currentDerby:HasPlayer(player)) then
			self.currentDerby:RemovePlayer(player, "You have been removed from the Derby event.")
		else        
			if (self:HasPlayer(player)) then
				self:RemovePlayer(player, "You have been removed from the Derby event.")
			else
				self.currentDerby:JoinPlayer(player)
			end
		end
	end
	if (cmdargs[1] == "/debugstart") then
		self.currentDerby:Start()
	end
	return false
end