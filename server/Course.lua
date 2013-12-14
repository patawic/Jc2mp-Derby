class "Course"
function Course:__init()
	self.manifestPath = "server/Courses/Manifest.txt"
	self.courseNames = {}
	self.numCourses = 0

	self:LoadManifest(self.manifestPath)
end
---------------------------------------------------------------------------------------------------------------------
------------------------------------------------MANIFEST LOADING-----------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Course:LoadManifest(path)
	local tempFile , tempFileError = io.open(path , "r")
	if tempFileError then
			print()
			print("*ERROR*")
			print(tempFileError)
			print()
			fatalError = true
			return
	else
			io.close(tempFile)
	end
	-- Loop through each line in the manifest.
	for line in io.lines(path) do
		-- Make sure this line has stuff in it.
		if string.find(line , "%S") then
				-- Add the entire line, sans comments, to self.courseNames
				table.insert(self.courseNames , line)
				self.numCourses = self.numCourses + 1
		end
	end
end
---------------------------------------------------------------------------------------------------------------------
-----------------------------------------------COURSE FILE PARSING---------------------------------------------------
---------------------------------------------------------------------------------------------------------------------
function Course:LoadCourse(name)
	if name == nil then
		name = self:PickRandomCourse()
	end
	local path = "server/Courses/" .. name .. ".course"
	--check if path is invalid
	if path == nil then
		print("*ERROR* - Course path is nil!")
		return nil
	end	
	local file = io.open(path , "r") 
	--check if file exists
	if not file then
		print("*ERROR* - Cannot open course file: "..path)
		return nil
	end

	local course = {}
	course.Location = nil
	course.minPlayers = nil
	course.maxPlayers = nil
	course.SpawnPoint = {}
	course.Boundary = {}
	course.MinimumY = nil
	course.MaximumY = nil

	--loop through file line by line
	for line in file:lines() do
		if line:sub(1,1) == "L" then
			course.Location =  self:Location(line)
		elseif line:sub(1,1) == "P" then
			local playerCount = self:Players(line)
			course.minPlayers = playerCount.minPlayers
			course.maxPlayers = playerCount.maxPlayers
		elseif line:sub(1,1) == "B" then
			local boundary = self:Boundary(line)
			course.Boundary.position = boundary.position
			course.Boundary.radius = boundary.radius
		elseif line:sub(1,1) == "M" and line:sub(2,2) == "i"then
			course.MinimumY = self:MinimumY(line)
		elseif line:sub(1,1) == "M" and line:sub(2,2) == "a"then
			course.MaximumY = self:MaximumY(line)
		elseif line:sub(1,1) == "S" then
			table.insert(course.SpawnPoint, self:Spawn(line))
		end
	end
	return course
end
function Course:Location(line)
	line = line:gsub("Location%(", "")
	line = line:gsub("%)", "")

	return line
end
function Course:Players(line)
	line = line:gsub("Players%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}

	args.minPlayers = tonumber(tokens[1])
	args.maxPlayers = tonumber(tokens[2])

	return args
end
function Course:Boundary(line)
	line = line:gsub("Boundary%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	-- Create tables containing appropriate strings
	args.position	= Vector(tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3]))
	args.radius		= tonumber(tokens[4])

	return args
end
function Course:MinimumY(line)
	line = line:gsub("MinimumY%(", "")
	line = line:gsub("%)", "")

	return tonumber(line)
end
function Course:MaximumY(line)
	line = line:gsub("MaximumY%(", "")
	line = line:gsub("%)", "")

	return tonumber(line)
end
function Course:Spawn(line)
	line = line:gsub("Spawn%(", "")
	line = line:gsub("%)", "")
	line = line:gsub(" ", "")

	local tokens = line:split(",")   
	local args = {}
	--model id
	args.model  = tonumber(tokens[1])
	-- Create tables containing appropriate strings
	args.position	= Vector(tonumber(tokens[2]), tonumber(tokens[3]), tonumber(tokens[4]))
	args.angle		= Angle(tonumber(tokens[5]), tonumber(tokens[6]), tonumber(tokens[7]))

	return args
end

function Course:PickRandomCourse()
	return table.randomvalue(self.courseNames)
end