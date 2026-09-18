-- Hyltaria : mode "un seul Hunter contre tous les Props"
-- Le système d'équilibrage d'origine visait des équipes de taille égale ;
-- ici on garantit un Hunter unique, choisi aléatoirement à chaque rotation.

local function announceTeam(ply, teamId, text)
	local ct = ChatText()
	ct:Add(ply:Nick())
	ct:Add(text)
	ct:Add(team.GetName(teamId), team.GetColor(teamId))
	ct:SendAll()
end

function GM:TeamsSetupPlayer(ply)
	-- S'il y a déjà un Hunter, le nouveau joueur est Prop, sinon il devient Hunter
	if team.NumPlayers(2) >= 1 then
		ply:SetTeam(3)
	else
		ply:SetTeam(2)
	end
end

concommand.Add("car_jointeam", function (ply, com, args)
	local curteam = ply:Team()
	local newteam = tonumber(args[1] or "") or 0
	if newteam == 1 && curteam != 1 then

		-- si c'était le seul Hunter, on le remplace avant qu'il parte
		GAMEMODE:ReplaceHunterIfNeeded(ply)

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

		-- Hyltaria : les équipes sont attribuées automatiquement
		local ct = ChatText()
		ct:Add("Team full, you cannot join")
		ct:Send(ply)

	end

end)

-- Remplace immédiatement le Hunter `leaving` s'il était le seul Hunter
-- (déconnexion ou passage en spectateur pendant une manche).
function GM:ReplaceHunterIfNeeded(leaving)
	if !IsValid(leaving) || leaving:Team() != 2 then return end

	for k, ply in pairs(team.GetPlayers(2)) do
		if ply != leaving then return end // il reste un autre Hunter
	end

	// hors manche, BalanceTeams() s'en chargera au lancement de la prochaine
	local state = self:GetGameState()
	if state != 1 && state != 2 then return end

	local candidates, aliveProps = {}, 0
	for k, ply in pairs(team.GetPlayers(3)) do
		if ply != leaving && ply:GetNWBool("RoundInGame") then
			table.insert(candidates, ply)
			if ply:Alive() then
				aliveProps = aliveProps + 1
			end
		end
	end

	// on évite de prendre le dernier Prop vivant (sinon victoire immédiate des Hunters)
	local pool = {}
	for k, ply in pairs(candidates) do
		if !(ply:Alive() && aliveProps <= 1) then
			table.insert(pool, ply)
		end
	end
	if #pool == 0 then return end // pas assez de joueurs : la manche se terminera normalement

	local newHunter = pool[math.random(#pool)]
	newHunter:SetTeam(2)
	newHunter:KillSilent()
	newHunter:Spawn()

	local col = team.GetColor(2)
	newHunter:SetPlayerColor(Vector(col.r / 255, col.g / 255, col.b / 255))

	if state == 1 then
		newHunter:Freeze(true) // les Hunters restent gelés pendant la préparation
	end

	announceTeam(newHunter, 2, " remplace le Hunter et rejoint les ")
end

function GM:CheckTeamBalance()
	-- Note : comme dans la version d'origine, cette fonction n'est appelée nulle part.
	-- L'équilibrage réel se fait via BalanceTeams() au début de chaque manche.
	if !self.TeamBalanceCheck || self.TeamBalanceCheck < CurTime() then
		self.TeamBalanceCheck = CurTime() + 1 * 60 // vérification toutes les minutes

		local hunters = team.NumPlayers(2)
		if hunters > 1 || (hunters == 0 && team.NumPlayers(3) >= 2) then // il doit y avoir un seul Hunter
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

function GM:BalanceTeams(nokill)
	local hunters = team.GetPlayers(2)

	// trop de Hunters : on renvoie les surplus (choisis parmi les Hunters) chez les Props
	while #hunters > 1 do
		local ply = table.remove(hunters, math.random(#hunters))
		ply:SetTeam(3)
		if !nokill && ply:Alive() then
			ply:Kill()
		end
		announceTeam(ply, 3, " passe chez les ")
	end

	// aucun Hunter : on en désigne un parmi les Props
	if #hunters == 0 then
		local props = team.GetPlayers(3)
		if #props >= 2 then
			local ply = props[math.random(#props)]
			ply:SetTeam(2)
			if !nokill && ply:Alive() then
				ply:Kill()
			end
			announceTeam(ply, 2, " passe chez les ")
		end
	end
end

function GM:SwapTeams()
	-- Tout le monde (spectateurs compris) passe Prop, puis un joueur aléatoire devient le Hunter
	local players = player.GetAll()
	if #players == 0 then return end

	for k, ply in pairs(players) do
		ply:SetTeam(3)
	end

	local hunter = players[math.random(#players)]
	hunter:SetTeam(2)
end
