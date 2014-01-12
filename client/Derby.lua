class 'Derby'

function Derby:__init()
	Network:Subscribe("SetState", self, self.SetState)

	Network:Subscribe("TriggerEvent", self, self.TriggerEvent)

	Network:Subscribe("OutOfArena", self, self.OutOfArena)
	Network:Subscribe("BackInArena", self, self.BackInArena)
	Network:Subscribe("enterVehicle", self, self.enterVehicle)
	Network:Subscribe("exitVehicle", self, self.exitVehicle)

	Network:Subscribe("PlayerCount", self, self.PlayerCount)

	Events:Subscribe("Render", self, self.Render)
	Events:Subscribe("ModuleLoad", self, self.ModulesLoad)
	Events:Subscribe("ModulesLoad", self, self.ModulesLoad)
	Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

	Events:Subscribe("LocalPlayerInput" , self , self.LocalPlayerInput)

	self.handbrake = nil
	--states
	self.state = "Inactive"
	self.playerCount = nil
	self.countdownTimer = nil
	self.blockedKeys = { Action.StuntJump, Action.StuntposEnterVehicle, Action.ParachuteOpenClose, Action.ExitVehicle, Action.EnterVehicle, Action.UseItem }

	self.outOfArena = false
	self.inVehicleTimer = nil
	self.vehicleHealthLost = -5
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------NETWORK EVENTS-------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:SetState(newstate)
	self.state = newstate
	if (newstate == "Inactive") then
		if (IsValid(self.handbrake)) then
			Events:Unsubscribe(self.handbrake)
		end
		self:BackInArena()
	end
	if (newstate == "Lobby") then
		self.state = "Lobby"
		self:BackInArena()
	elseif (newstate == "Setup") then
		self.state = "Setup"
		self.handbrake = Events:Subscribe("InputPoll", function() Input:SetValue(Action.Handbrake, 1) end)
	elseif (newstate == "Countdown") then
		self.state = "Countdown"
		self.countdownTimer = Timer()
	elseif (newstate == "Running") then
		self.state = "Running"
		self.countdownTimer = nil
		Events:Unsubscribe(self.handbrake)
	end
end
function Derby:PlayerCount(amount)
	self.playerCount = amount
end
function Derby:enterVehicle()
	self.inVehicleTimer = nil
end
function Derby:exitVehicle()
	self.inVehicleTimer = Timer()
end
function Derby:OutOfArena()
	self.outOfArena = true
	self.vehicleHealthLost = self.vehicleHealthLost + 5
end
function Derby:BackInArena()
	self.outOfArena = false
	self.vehicleHealthLost = -5
end
function Derby:TriggerEvent(event)
	Game:FireEvent(event)
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:ModulesLoad()
	Events:Fire("HelpAddItem",
		{
			name = "Derby",
			text = 
				"The derby is a free-for-all vehicle deathmatch in the dish.\n\n" ..
				"To enter the derby lobby, type /derby in chat and hit enter.\n" ..
				"You will be placed in a lobby for the next Derby event.\n\n" ..
				"Prize Money is awarded to the user depending on what position you finish in.\n"..
				"You are removed after 20 seconds of being out of your vehicle, and your vehicle\n"..
				"is slowly destroyed if you are outside of the arena boundaries for too long.\n\n"..
				"You can exit both the lobby and the derby event by typing /derby in chat.\n\n"
		} )
end

function Derby:ModuleUnload()
	Events:Fire("HelpRemoveItem",
		{
			name = "Derby"
		} )
end

function Derby:LocalPlayerInput(args)
	if (self.state == "Running") then
		if LocalPlayer:InVehicle() then
			for i, action in ipairs(self.blockedKeys) do
				if args.input == action then
					return false
				end
			end
		end
	elseif (self.state == "Setup" or self.state == "Countdown") then
		return false
	end
end
function Derby:TextPos(text, size, offsetx, offsety)
	local text_width = Render:GetTextWidth(text, size)
	local text_height = Render:GetTextHeight(text, size)
	local pos = Vector2((Render.Width - text_width + offsetx)/2, (Render.Height - text_height + offsety)/2)

	return pos
end
function Derby:Render()
	if (self.state == "Inactive") then return end
	if Game:GetState() ~= GUIState.Game then return end

	if (self.state ~= "Inactive") then
		local pos = Vector2(3, Render.Height - 32)
		Render:DrawText(pos, "Derby v0.1 By Patawic", Color(255, 255, 255), TextSize.Default) 
	end
	if (self.state == "Lobby") then
		local pos = Vector2(3, Render.Height -  49)
		Render:DrawText(pos, "Players Joined: " .. self.playerCount, Color(255, 255, 255), TextSize.Default) 
	end
	if (self.state == "Setup") then
		local pos = Vector2(3, Render.Height -  49)
		Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default)

		local text = "Initializing"
		local textinfo = self:TextPos(text, TextSize.VeryLarge, 0, -200)
		Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.VeryLarge)    

		local text = "Please Wait..."
		local textinfo = self:TextPos(text, TextSize.Default, 0, -155)
		Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Default)        

	elseif (self.state == "Countdown") then
		local pos = Vector2(3, Render.Height -  49)
		Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default)

		local time = 3 - math.floor(math.clamp(self.countdownTimer:GetSeconds(), 0 , 3))
		local message = {"Go!", "One", "Two", "Three"}
		local text = message[time + 1]
		local textinfo = self:TextPos(text, TextSize.Huge, 0, -200)
		Render:DrawText(textinfo, text, Color( 255, 69, 0 ), TextSize.Huge)  
		
	elseif (self.state == "Running") then
		local pos = Vector2(3, Render.Height -  49)
		Render:DrawText(pos, "Players Left: " .. self.playerCount, Color(255, 255, 255), TextSize.Default) 
		--OUT OF ARENA
		if (self.outOfArena) then
			local text = "Out Of Arena"
			local text_width = Render:GetTextWidth(text, TextSize.VeryLarge)
			local text_height = Render:GetTextHeight(text, TextSize.VeryLarge)
			local pos = Vector2((Render.Width - text_width)/2, (Render.Height - text_height - 200)/2)
			Render:DrawText(pos, text, Color( 255, 69, 0 ), TextSize.VeryLarge)
			local text = self.vehicleHealthLost .. "% vehicle health lost! Please re-enter the Arena"
			pos.y = pos.y + 45
			pos.x = (Render.Width - Render:GetTextWidth(text, TextSize.Default))/2
			Render:DrawText(pos, text, Color(255, 255, 255), TextSize.Default)
		end
		--OUT OF VEHICLE
		if (self.inVehicleTimer ~= nil) then
			Render:FillArea(Vector2(Render.Width - 110, 70), Vector2(Render.Width - 110, 110), Color(0, 0, 0, 165))
			local time = 20 - math.floor(math.clamp(self.inVehicleTimer:GetSeconds(), 0, 20 ))
			if time <= 0 then return end
			local text = tostring(time)
			local text_width = Render:GetTextWidth(text, TextSize.Huge)
			local text_height = Render:GetTextHeight(text, TextSize.Huge)
			local pos = Vector2(((110 - text_width)/2) + Render.Width - 110, (text_height))
			Render:DrawText( pos, text, Color( 255, 69, 0 ), TextSize.Huge)
			pos.y = pos.y + 70
			pos.x = Render.Width - 106
			Render:DrawText( pos, "Seconds to re-enter", Color( 255, 255, 255 ), 12)
			pos.y = pos.y + 15
			Render:DrawText( pos, "Vehicle", Color( 255, 255, 255 ), 12)
		end
	end
end
Derby = Derby()