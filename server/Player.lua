class "Player"
function Player:__init(player)
	self.player = player
    self.type = nil
    self.spectating = nil
    self.dead = false
	self.playerId = player:GetId()
    self.start_pos = player:GetPosition()
    self.start_world = player:GetWorld()
    self.inventory = player:GetInventory()

end

function Player:Leave()
    self.player:SetWorld(self.start_world)
    self.player:SetPosition(self.start_pos)

    self.player:ClearInventory()
    for k,v in pairs(self.inventory) do
        self.player:GiveWeapon(k, v)
    end
end