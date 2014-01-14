function math.round(x)
	if x%2 ~= 0.5 then
		return math.floor(x+0.5)
	end
	return x-0.5
end
class "Derby"
function Derby:__init(name, manager, world)
	self.name = name
	self.derbyManager = manager
	self.world = world

	self.state = "Lobby"
	self.startTimer = Timer()

	self.players = {}
	self.eventPlayers = {}

	self.course = Course(self.derbyManager)
	self.spawns = self.course:LoadCourse()
	self.courseType = self.spawns.courseType
	self.event = Event(self, self.spawns.Event)
	self.minPlayers = self.spawns.minPlayers
	self.maxPlayers = self.spawns.maxPlayers


	self.world:SetTime(self.spawns.Time[1])
	self.world:SetTimeStep(self.spawns.Time[2])
	self.world:SetWeatherSeverity(self.spawns.Weather)

	self.startPlayers = 0
	self.numPlayers = 0
	self.highestMoney = 0
	self.scaleFactor = 0

	self.globalStartTimer = Timer()
	self.setupTimer = nil
	self.countdownTimer = nil
	self.derbyTimer = nil

	Events:Subscribe("PostTick", self, self.PostTick)

	Events:Subscribe("JoinGamemode", self, self.JoinGamemode)
	Events:Subscribe("PlayerEnterVehicle", self, self.enterVehicle)
	--Events:Subscribe("PlayerExitVehicle", self, self.exitVehicle)
	Events:Subscribe("PlayerDeath", self, self.PlayerDeath)
	Events:Subscribe("PlayerQuit", self, self.PlayerLeave)

	Events:Subscribe("ModuleUnload", self, self.ModuleUnload)

	self:MessageGlobal("A Derby event is about to begin! (Location: " .. self.spawns.Location .. ", Maximum Players: " .. self.maxPlayers ..") /derby to join")
end

---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------EVENTS----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:PostTick()
	if (self.state == "Lobby") then
		if (Server:GetPlayerCount() >= self.minPlayers) then
			if ((self.numPlayers >= self.minPlayers and self.startTimer:GetSeconds() > 30) or (self.numPlayers >= self.minPlayers and self.globalStartTimer:GetSeconds() > 300)) then
				self:Start()
			end
		else
			if ((Server:GetPlayerCount() >= 2 and self.startTimer:GetSeconds() > 30) or (Server:GetPlayerCount() >= 2 and self.globalStartTimer:GetSeconds() > 300)) then
				self:Start()
			end
		end
	elseif (self.state == "Setup") then
		if (self.setupTimer:GetSeconds() > 10) then
			self.countdownTimer = Timer()
			--set state
			self.state = "Countdown"
			self:SetClientState()
			self.setupTimer = nil

		end
	elseif (self.state == "Countdown") then
		if (self.countdownTimer:GetSeconds() > 4) then
			--set state
			self.state = "Running"
			self:SetClientState()
			self.countdownTimer = nil
			self.derbyTimer = Timer()

			self:RespawnPlayers()
		end
	elseif (self.state == "Running") then
		--check player and vehicle health
		self:CheckHealth()
		--player loses health when out of boundaries
		if (self.derbyTimer:GetSeconds() > 5) then
			self:CheckBoundaries()
			--remove player if they go above the Y axis cap
			self:CheckMaximumY()
		end
		--remove player if they go below the Y axis cap
		self:CheckMinimumY()
		--Actively check for players & handle derby ending
		self:CheckPlayers()
		--Update Events
		self.event:Update()
	end
end

function Derby:PlayerDeath(args)
	if self:HasPlayer(args.player) then
		if (self.state ~= "Lobby" and args.player:GetWorld() == self.world) then
			local numberEnding = ""
			local lastDigit = self.numPlayers % 10
			if ((self.numPlayers < 10) or (self.numPlayers > 20 and self.numPlayers < 110) or (self.numPlayers > 120)) then
				if (lastDigit  == 1) then
					numberEnding = "st"
				elseif (lastDigit == 2) then
					numberEnding = "nd"
				elseif (lastDigit == 3) then
					numberEnding = "rd"
				else
					numberEnding = "th"
				end
			else
				numberEnding = "th"
			end
			self:MessagePlayer(args.player, "Congratulations you came " ..tostring(self.numPlayers) .. numberEnding)
			self:RemovePlayer(args.player)

			local currentMoney = args.player:GetMoney()
			local addMoney = math.ceil(100 * math.exp(self.scaleFactor * (self.startPlayers - self.numPlayers))) / 2
			args.player:SetMoney(currentMoney + addMoney)
		end
	end
end

function Derby:PlayerLeave(args)
	if (self:HasPlayer(args.player)) then
		self:RemovePlayer(args.player)
	end
end

function Derby:enterVehicle(args)
	if (self.state ~= "Lobby" and self:HasPlayer(args.player)) then
		if (self.eventPlayers[args.player:GetId()].derbyVehicle:GetId() ~= args.vehicle:GetId()) then
			self:MessagePlayer(args.player, "This vehicle does not belong to you")
			self.eventPlayers[args.player:GetId()].hijackCount = self.eventPlayers[args.player:GetId()].hijackCount + 1
			if (self.eventPlayers[args.player:GetId()].hijackCount >= 3) then
				self:RemovePlayer(args.player, "You have been removed for multiple hijacking offences")
			end
			args.player:SetPosition(args.player:GetPosition())
			for index, p in pairs(self.eventPlayers) do
				if (p.derbyVehicle:GetId() == args.vehicle:GetId()) then
					p.player:EnterVehicle(args.vehicle, VehicleSeat.Driver)
				end
			end
		else
			self.eventPlayers[args.player:GetId()].vtimer = nil
			Network:Send(args.player, "enterVehicle")
		end
	end
end

function Derby:exitVehicle(args)
	if (self.state ~= "Lobby" and self:HasPlayer(args.player)) then
		if args.player:GetHealth() > 0.1 then
			self.eventPlayers[args.player:GetId()].vtimer = Timer()
			Network:Send(args.player, "exitVehicle")
		end
	end
end

function Derby:SetClientState(newstate)
	for index,player in pairs(self.players) do
		if newstate == nil then
			Network:Send(player, "SetState", self.state)
		else
			Network:Send(player, "SetState", newstate)
		end
	end
end

function Derby:UpdatePlayerCount()  
	for id ,player in pairs(self.players) do
		Network:Send(player, "PlayerCount", self.numPlayers)
	end
end

function Derby:ModuleUnload()
	for k,p in pairs(self.eventPlayers) do
		if (self.state ~= "Lobby") then
			p:Leave()
			self:MessagePlayer(p.player, "Derby script unloaded. You have been restored to your starting position.")
			self:SetClientState("Inactive")
		end
	end
end
function Derby:JoinGamemode( args )
	if args.name ~= "Derby" then
		self:RemovePlayer(args.player)
	end
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:RespawnPlayers()
	for k,p in pairs(self.eventPlayers) do
		if (p.player:InVehicle() == false) then
			local vehicle = p.derbyVehicle
			p.player:EnterVehicle(vehicle, VehicleSeat.Driver)
		else
			if (p.derbyPosition:Distance(p.player:GetPosition()) > 5) then
				p.derbyVehicle:SetPosition(p.derbyPosition)
				p.derbyVehicle:SetAngle(p.derbyAngle)
				p.derbyVehicle:SetLinearVelocity(Vector3(0,0,0))
			end
			p.player:GetVehicle():SetHealth(1)
		end
	end
end
function Derby:CheckBoundaries()
	for k,p in pairs(self.players) do
		local boundary = self.spawns.Boundary.position
		local radius = self.spawns.Boundary.radius
		local distanceSqr = (p:GetPosition() - boundary):LengthSqr()

		--CHECK IS PLAYER IS OUTSIDE THE EVENT BOUNDARIES
		if ((distanceSqr > radius or p:GetPosition().y > self.spawns.MaximumY) and p:InVehicle() and p:GetWorld() == self.world) then
			if (p.timer ~= nil) then
				if p.timer:GetSeconds() > 2 then
					local vhealth = p:GetVehicle():GetHealth()
					p:GetVehicle():SetHealth(vhealth - 0.025)
					p.timer = nil
				end
			else
				p.timer = Timer()
				p.outOfArena = true
				Network:Send(p, "OutOfArena")
			end
		elseif (distanceSqr <= radius and p.outOfArena) then
			p.outOfArena = false
			Network:Send(p, "BackInArena")
		end
		--handle the out of vehicle timer
		local dp = self.eventPlayers[p:GetId()]
		if dp.vtimer ~= nil then
			if (dp.vtimer:GetSeconds() > 20) then
			   p:SetHealth(0)
			end
		end
	end
end
function Derby:CheckMinimumY()
	for k,p in pairs(self.players) do
		if (p:GetPosition().y < self.spawns.MinimumY and p:InVehicle()) then
			p:SetHealth(0)
		end
	end
end
function Derby:CheckMaximumY()
	for k,p in pairs(self.players) do
		if (p:InVehicle() == false) then
			if (p:GetPosition().y > self.spawns.MaximumY) then
				self:RemovePlayer(p, "You have been removed from the derby event!")
			end
		end
	end	
end
function Derby:CheckHealth()
	for k,p in pairs(self.players) do
		if (p:InVehicle()) then
			if (p:GetVehicle():GetHealth() == 0) then
				p:SetHealth(0)
			end
		end
	end
end
function Derby:CheckPlayers()
	if (self.numPlayers == 1 and self.state ~= "Lobby") then
	--kick everyone out and broadcast the winner
		for k,p in pairs(self.players) do
			self:MessageGlobal(p:GetName() .. " has won the Demolition Derby!")
			print("[" ..self.name .. "] " .. p:GetName() .. " won the derby event")


			local currentMoney = p:GetMoney()
			local addMoney = math.ceil(100 * math.exp(self.scaleFactor * (self.startPlayers - self.numPlayers))) / 2
			p:SetMoney(currentMoney + addMoney)
			self:RemovePlayer(p, "Congratulations you came 1st!")
		end
		self:Cleanup()
	elseif (self.numPlayers == 0) then
		print ("no players left")
		self:Cleanup()
	end
end
---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------EVENT START--------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:Start()
	self.state = "Setup"
	self.startPlayers = self.numPlayers
	self.setupTimer = Timer()
	self.event:ResetTimer()
	self:SetClientState()


	local tempPlayers = {}
	for id , player in pairs(self.players) do
				table.insert(tempPlayers , player)
	end
	local divider = math.floor(self.maxPlayers / self.numPlayers)
	local idInc = 1

	for index, player in ipairs(tempPlayers)do 
		if (player:GetHealth() == 0) then
			self:RemovePlayer(player, "You have been removed from the Derby event.")
		else
			self:SpawnPlayer(player, tonumber(math.round(idInc)))
		end
		idInc = idInc + divider
	end
	self:MessageGlobal("Starting Derby event with " .. tostring(self.numPlayers) .. " players.")
	print("[" ..self.name .. "] Started Event at (Location: " .. self.spawns.Location .. ", Players: " .. self.startPlayers .. ")")
	self.derbyManager:CreateDerbyEvent()

	self.highestMoney = self.startPlayers * 400
	self.scaleFactor = math.log(self.highestMoney/100)/self.startPlayers
end

function Derby:SpawnPlayer(player, index)
	if (IsValid(self.spawns.SpawnPoint[index]) ~= nil) then
		--CREATE THE VEHICLE
		local vehicleid = tonumber(table.randomvalue(self.spawns.Vehicles))
		local vehicle = Vehicle.Create(vehicleid, self.spawns.SpawnPoint[index].position, self.spawns.SpawnPoint[index].angle)
		local color = Color(math.random(255),math.random(255),math.random(255))
		vehicle:SetEnabled(true)
		vehicle:SetHealth(1)
		vehicle:SetDeathRemove(true)
		vehicle:SetUnoccupiedRemove(true)
		vehicle:SetWorld(self.world)
		vehicle:SetColors(color, color)

		--TELEPORT THE PLAYER
		player:SetWorld(self.world)
		player:SetPosition(self.spawns.SpawnPoint[index].position)
		player:ClearInventory()

		--PLACE PLAYER IN THE VEHICLE
		player:EnterVehicle(vehicle, VehicleSeat.Driver)

		local p = self.eventPlayers[player:GetId()]
		p.derbyPosition = self.spawns.SpawnPoint[index].position
		p.derbyAngle = self.spawns.SpawnPoint[index].angle
		p.derbyVehicle = vehicle

	else
		self:RemovePlayer(player, "An error occured, you were removed from the derby.")
	end

end
---------------------------------------------------------------------------------------------------------------------
-------------------------------------------PLAYER JOINING/LEAVING----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:HasPlayer(player)
	return self.players[player:GetId()] ~= nil
end

function Derby:JoinPlayer(player)
	if (player:GetWorld() ~= DefaultWorld) then
		self:MessagePlayer(player, "You must exit other gamemodes before you can join.")
	else
		if (self.state == "Lobby") then
			local p = Player(player)
			self.eventPlayers[player:GetId()] = p
			self.players[player:GetId()] = player

			self.derbyManager.playerIds[player:GetId()] = true
			self.numPlayers = self.numPlayers + 1
			self:MessagePlayer(player, "You have been entered into the next Derby event! It will begin shortly.") 

			Network:Send(player, "SetState", "Lobby")
			Network:Send(player, "CourseName", self.spawns.Location)
			self:UpdatePlayerCount()
			self.startTimer:Restart()

			if (self.numPlayers == self.maxPlayers) then
				self:Start()
			end
		end
	end
end

function Derby:RemovePlayer(player, message)
	if message ~= nil then
		self:MessagePlayer(player, message)    
	end
	local p = self.eventPlayers[player:GetId()]
	if p == nil then return end
	if (IsValid(self.eventPlayers[player:GetId()].derbyVehicle)) then
		self.eventPlayers[player:GetId()].derbyVehicle:Remove()
	end
	self.players[player:GetId()] = nil
	self.eventPlayers[player:GetId()] = nil
	self.derbyManager.playerIds[player:GetId()] = nil
	self.numPlayers = self.numPlayers - 1
	if (self.state ~= "Lobby") then
		p:Leave()
	end
	Network:Send(player, "SetState", "Inactive")
	self:UpdatePlayerCount()
end
---------------------------------------------------------------------------------------------------------------------
---------------------------------------------------CLEANUP-----------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:Cleanup()
	self.state = "Cleanup"
	if self.courseType == "large" then
		self.derbyManager.largeActive = false
	end
	self.world:Remove()
	self.derbyManager:RemoveDerby(self)
	for index, player in pairs(self.players) do
		self:RemovePlayer(player)
	end
end
---------------------------------------------------------------------------------------------------------------------
----------------------------------------------------CHAT-------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Derby:MessagePlayer(player, message)
	player:SendChatMessage("[" ..self.name .. "] " .. message, Color(30, 200, 220) )
end

function Derby:MessageGlobal(message)
	Chat:Broadcast("[" ..self.name .. "] " .. message, Color(0, 255, 255) )
end