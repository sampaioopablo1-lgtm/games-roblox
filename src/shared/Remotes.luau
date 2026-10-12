--!strict
-- Cria (no servidor) ou aguarda (no cliente) os RemoteEvents/RemoteFunctions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Notify" }
local FUNCTIONS = { "Rebirth", "ClaimDaily" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

Remotes.Notify = folder:WaitForChild("Notify") :: RemoteEvent
Remotes.Rebirth = folder:WaitForChild("Rebirth") :: RemoteFunction
Remotes.ClaimDaily = folder:WaitForChild("ClaimDaily") :: RemoteFunction

return Remotes
