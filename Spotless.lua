local Spotless = {}
Spotless.__index = Spotless

type SpotlessFunc = "Disconnect" | "Destroy" | "ClearChildren" | "Clear"

export type Void = (...any) -> ()

export type ValidThing =
	RBXScriptConnection |
	Instance |
	() -> () |
	{ [any]: any } 

type TaskRecord = {
	thing: ValidThing,
	cleanupFunc: Void,
}
--Hello from AbsoluteObliviation
function Spotless.Construct()
	local self = setmetatable({}, Spotless)
	self._tasks = {} :: { TaskRecord }
	return self
end

function Spotless:Add(thing: ValidThing, method: SpotlessFunc?)
	if not thing then
		warn("[Spotless] Add called with nil thing")
		return false
	end
	
	if not method then
		if typeof(thing) == "RBXScriptConnection" then
			method = "Disconnect"
		elseif typeof(thing) == "Instance" then
			method = "Destroy"
		elseif typeof(thing) == "table" then
			if typeof(thing.Destroy) == "function" then
				method = "Destroy"
			elseif typeof(thing.Disconnect) == "function" then
				method = "Disconnect"
			elseif typeof(thing.ClearChildren) == "function" then
				method = "ClearChildren"
			elseif typeof(thing.Clear) == "function" then
				method = "Clear"
			end
		elseif typeof(thing) == "function" then
			method = nil
		else
			warn("[Spotless] Could not infer cleanup method for:", typeof(thing))
			return false
		end
	end
	
	local cleanupFunc: Void
	if typeof(thing) == "function" then
		cleanupFunc = thing
	elseif method and typeof(thing) == "table" and typeof(thing[method]) == "function" then
		cleanupFunc = function()
			thing[method](thing)
		end
	else
		warn("[Spotless] Invalid method or thing for cleanup:", method, typeof(thing))
		return false
	end
	
	table.insert(self._tasks, { thing = thing, cleanupFunc = cleanupFunc })
	return true
end

function Spotless:Cleanup()
	for _, task in ipairs(self._tasks) do
		local success, err = pcall(task.cleanupFunc)
		if not success then
			warn("[Spotless] Error cleaning up:", err)
		end
	end
	self._tasks = {}
end

function Spotless:DestroyThing(which: ValidThing)
	for i = #self._tasks, 1, -1 do
		local task = self._tasks[i]
		if task.thing == which then
			local success, err = pcall(task.cleanupFunc)
			if not success then
				warn("[Spotless] Error cleaning up specific thing:", err)
			end
			table.remove(self._tasks, i)
			return true
		end
	end
	return false
end

function Spotless:ReturnList()
	return self._tasks
end









return Spotless
