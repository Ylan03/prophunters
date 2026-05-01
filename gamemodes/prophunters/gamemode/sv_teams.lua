

// Returns the number of hunters that should currently be in game.
// totalPlayers = number of non-spectator players (teams 2 + 3)
// Always at least 1 hunter, and never more hunters than (totalPlayers - 1) so there's at least 1 prop.
function GM:GetTargetHunterCount(totalPlayers)
	local desired = self.HunterCount and self.HunterCount:GetInt() or 1
	if desired < 1 then desired = 1 end
	if totalPlayers <= 1 then
		return math.min(desired, totalPlayers)
	end
	return math.Clamp(desired, 1, totalPlayers - 1)
end

function GM:TeamsSetupPlayer(ply)
	local hunters = team.NumPlayers(2)
	local props = team.NumPlayers(3)
	local total = hunters + props + 1 // +1 because the new player isn't counted yet
	local targetHunters = self:GetTargetHunterCount(total)

	if hunters < targetHunters then
		ply:SetTeam(2)
	else
		ply:SetTeam(3)
	end
end

concommand.Add("car_jointeam", function (ply, com, args)
	local curteam = ply:Team()
	local newteam = tonumber(args[1] or "") or 0
	if newteam == 1 && curteam != 1 then

		ply:SetTeam(newteam)
		if ply:Alive() then
			ply:Kill()
		end
		local ct = ChatText()
		ct:Add(ply:Nick())
		ct:Add(" changed team to ")
		ct:Add(team.GetName(newteam), team.GetColor(newteam))
		ct:SendAll()

	elseif newteam >= 2 && newteam <= 3 && newteam != curteam then

		// enforce the hunter quota
		local hunters = team.NumPlayers(2)
		local props = team.NumPlayers(3)
		local total = hunters + props
		local targetHunters = GAMEMODE:GetTargetHunterCount(total)

		local canSwitch = false
		if newteam == 2 then
			// can only join hunters if hunters are below quota
			if hunters < targetHunters then
				canSwitch = true
			end
		elseif newteam == 3 then
			// can only join props if leaving team 2 wouldn't drop hunters below quota
			if curteam != 2 || hunters - 1 >= targetHunters then
				canSwitch = true
			end
		end

		if canSwitch then
			ply:SetTeam(newteam)
			if ply:Alive() then
				ply:Kill()
			end
			local ct = ChatText()
			ct:Add(ply:Nick())
			ct:Add(" changed team to ")
			ct:Add(team.GetName(newteam), team.GetColor(newteam))
			ct:SendAll()
		else
			local ct = ChatText()
			ct:Add("Cannot switch team, hunter quota would be violated")
			ct:Send(ply)
		end

	end

end)

function GM:CheckTeamBalance()
	if !self.TeamBalanceCheck || self.TeamBalanceCheck < CurTime() then
		self.TeamBalanceCheck = CurTime() + 3 * 60 // check every 3 minutes

		local hunters = team.NumPlayers(2)
		local props = team.NumPlayers(3)
		local total = hunters + props
		local targetHunters = self:GetTargetHunterCount(total)

		if hunters != targetHunters then
			self.TeamBalanceTimer = CurTime() + 30 // balance in 30 seconds
			for k,ply in pairs(player.GetAll()) do
				ply:ChatPrint("Auto team balance in 30 seconds")
			end
		end
	end
	if self.TeamBalanceTimer && self.TeamBalanceTimer < CurTime() then
		self.TeamBalanceTimer = nil
		self:BalanceTeams()
	end
end

// Ensure exactly GetTargetHunterCount() players are on hunters and the rest on props.
// If the count is already correct, leaves teams as-is (preserves SwapTeams selection).
// If not, randomly fixes it. Spectators (team 1) are left alone.
function GM:BalanceTeams(nokill)
	// gather all non-spectator players
	local active = {}
	local hunters = {}
	local props = {}
	for k, ply in pairs(player.GetAll()) do
		if IsValid(ply) && ply:Team() != 1 then
			table.insert(active, ply)
			if ply:Team() == 2 then
				table.insert(hunters, ply)
			else
				table.insert(props, ply)
			end
		end
	end

	local total = #active
	if total < 1 then return end

	local targetHunters = self:GetTargetHunterCount(total)

	// already balanced? nothing to do.
	if #hunters == targetHunters then
		return
	end

	if #hunters > targetHunters then
		// too many hunters, demote random ones to props
		local need = #hunters - targetHunters
		for i = #hunters, 2, -1 do
			local j = math.random(i)
			hunters[i], hunters[j] = hunters[j], hunters[i]
		end
		for i = 1, need do
			local ply = hunters[i]
			if IsValid(ply) then
				ply:SetTeam(3)
				if !nokill && ply:Alive() then
					ply:Kill()
				end
			end
		end
	else
		// not enough hunters, promote random props
		local need = targetHunters - #hunters
		for i = #props, 2, -1 do
			local j = math.random(i)
			props[i], props[j] = props[j], props[i]
		end
		for i = 1, math.min(need, #props) do
			local ply = props[i]
			if IsValid(ply) then
				ply:SetTeam(2)
				if !nokill && ply:Alive() then
					ply:Kill()
				end
			end
		end
	end

	local ct = ChatText()
	ct:Add("Teams balanced (" .. targetHunters .. " hunter" .. (targetHunters > 1 and "s" or "") .. ")", Color(50, 220, 150))
	ct:SendAll()
end

// Used between rounds. Instead of literally swapping (which doesn't make sense
// when there's only 1 hunter for many props), reroll random hunters but
// avoid picking previous hunters again so everyone gets a turn.
function GM:SwapTeams()
	local previousHunters = {}
	local pool = {}
	for k, ply in pairs(player.GetAll()) do
		if IsValid(ply) && ply:Team() != 1 then
			if ply:Team() == 2 then
				previousHunters[ply] = true
			end
			table.insert(pool, ply)
		end
	end

	local total = #pool
	if total < 1 then return end

	local targetHunters = self:GetTargetHunterCount(total)

	// candidates = players who weren't hunters last round
	local candidates = {}
	for k, ply in ipairs(pool) do
		if !previousHunters[ply] then
			table.insert(candidates, ply)
		end
	end

	// shuffle candidates
	for i = #candidates, 2, -1 do
		local j = math.random(i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end

	local newHunters = {}
	for i = 1, math.min(targetHunters, #candidates) do
		newHunters[candidates[i]] = true
	end

	// if not enough fresh candidates, fill remaining slots with previous hunters
	if table.Count(newHunters) < targetHunters then
		local fallback = {}
		for ply, _ in pairs(previousHunters) do
			if !newHunters[ply] then
				table.insert(fallback, ply)
			end
		end
		for i = #fallback, 2, -1 do
			local j = math.random(i)
			fallback[i], fallback[j] = fallback[j], fallback[i]
		end
		local need = targetHunters - table.Count(newHunters)
		for i = 1, math.min(need, #fallback) do
			newHunters[fallback[i]] = true
		end
	end

	// apply
	for k, ply in ipairs(pool) do
		local newTeam = newHunters[ply] and 2 or 3
		if ply:Team() != newTeam then
			ply:SetTeam(newTeam)
		end
	end

	local ct = ChatText()
	ct:Add("Teams have been re-rolled", Color(50, 220, 150))
	ct:SendAll()
end
