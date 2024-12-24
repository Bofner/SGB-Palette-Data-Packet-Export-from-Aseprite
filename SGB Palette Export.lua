--Sprite constants
local sprite = app.activeSprite
local spriteFullPath
local spriteFileName
--Palette Constants
local currentPal = Palette(sprite.palettes[1])
local currentPalNumColors = #sprite.palettes[1]
local sharedColor = currentPal:getColor(0)
local paletteSGB0 = Palette(4)
local paletteSGB1 = Palette(4)
local paletteSGB2 = Palette(4)
local paletteSGB3 = Palette(4)

-- Check constraints
if sprite == nil then
	app.alert("No Sprite...")
	return
end

--More colors than allowed by the Super Game Boy
if currentPalNumColors > 16 then
	local dlg = Dialog{title = "SGB color limit exceeded!"}
	dlg:label{ 	id    = "manyColors",
				label = "Warning!",
				text  = "Only the first 16 colors in the palette will be used!" }
	dlg:button{ id="continue", text="Continue" }
	dlg:button{ id="cancel", text="Cancel" }
	dlg:show()
	local data = dlg.data
	if data.cancel then
		return
	end
end

--Too few colors
if currentPalNumColors < 16 then
	currentPal:resize(16)
end

--The Shared Color is not saved properly
if sharedColor ~= currentPal:getColor(4) or sharedColor ~= currentPal:getColor(8) or sharedColor ~= currentPal:getColor(12) then
	local dlg = Dialog{title = "Shared Color isn't the same!"}
	dlg:label{ 	id    = "offSharedColor",
				label = "Warning!",
				text  = "Only color at index 0 will be used as the shared color. Do you want to continue?" }
	dlg:button{ id="continue", text="Continue" }
	dlg:button{ id="cancel", text="Cancel" }
	dlg:show()
	local data = dlg.data
	if data.cancel then
		return
	end
end

--Grab the title of our aseprite file
if sprite then
    spriteFullPath = sprite.filename
    spriteFilePath = spriteFullPath:match("(.+)%..+$")
    spriteFileName = spriteFullPath:match("([^/\\]+)$"):match("(.+)%..+$")
end

--Convert our 32-bit Aseprite color into SGB 15-bit color
local function convert32BitTo15BitColor(color)
	--Isolate the 32-bit components of the color
	local hexR = color.red
	local hexG = color.green
	local hexB = color.blue
	--Convert them into 15-bit color 
	local sgbR = hexR & ~0x07
	sgbR = sgbR >> 3
	local sgbG = hexG & ~0x07
	sgbG = sgbG >> 3
	local sgbB = hexB & ~0x07
	sgbB = sgbB >> 3
	--Put them into the 15-bit word in the form XBBBBBGG GGGRRRRR
	local sgb15BitColor = 0x0000
	sgb15BitColor = sgb15BitColor | (sgbB << 10)
	sgb15BitColor = sgb15BitColor | (sgbG << 5)
	sgb15BitColor = sgb15BitColor | (sgbR)

	return sgb15BitColor
end

local function printChange(text)
	print(text)
end

----------------------------------------------------------------------------------------
--Main Execution of the script
----------------------------------------------------------------------------------------
--Menu that pops up in Aseprite
local dlg = Dialog{title = "Select SGB palettes to export"}
dlg:file{ id="exportFile",
          label="File",
          title="SGB Color Palette file",
          open=false,
          save=true,
          filename= spriteFilePath .. "Pal.inc",
          filetypes={"inc"}}
dlg:combobox{ id="headerType",
		  	  label="SGB Palettes",
		  	  option="Export 4 palettes",
		  	  options={ "Export 4 palettes","Export 0 & 1","Export 2 & 3","Export 0 & 3","Export 1 & 2" },
			}
dlg:button{ id="ok", text="Export" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()
local data = dlg.data
if data.ok then
	--Make the palette file
    local incFile = io.open(data.exportFile, "w")
	--Set up the header
	local sgbPalettesHeader0
	local sgbPalettes0
	if data.headerType == "Export 0 & 1" or data.headerType == "Export 4 palettes" then
		sgbPalettes0 = "0 and 1"
		sgbPalettesHeader0 =  "$01"
	elseif data.headerType == "Export 2 & 3" then
		sgbPalettes0 = "2 and 3"
		sgbPalettesHeader0 = "$09"
	elseif data.headerType == "Export 0 & 3" then
		sgbPalettes0 = "0 and 3"
		sgbPalettesHeader0 = "$11"
	elseif data.headerType == "Export 1 & 2" then
		sgbPalettes0 = "1 and 2"
		sgbPalettesHeader0 = "$19"
	else
		return
	end
	incFile:write(";Data for 16 byte packet that sets SGB Palettes " .. sgbPalettes0 .. "\n") 
	incFile:write(";Header\n")
	incFile:write(".DB " .. sgbPalettesHeader0 .. "\n")
	
	--Set our SGB palettes
	for i = 0, 3, 1 do
		paletteSGB0:setColor(i, currentPal:getColor(i))
		paletteSGB1:setColor(i, currentPal:getColor(i+4))
		paletteSGB2:setColor(i, currentPal:getColor(i+8))
		paletteSGB3:setColor(i, currentPal:getColor(i+12))
	end

	--Convert the SGB Shared Color into 15-bit SGB color
	local sharedColorSGB = convert32BitTo15BitColor(paletteSGB0:getColor(0))

	--Write the first half of the palette data for the first packet
	if data.headerType == "Export 4 palettes" or data.headerType == "Export 0 & 1" or  data.headerType == "Export 0 & 3" then
		--Convert the colors in the 0th palette to 15-bit SGB color
		local p0Color1SGB    = convert32BitTo15BitColor(paletteSGB0:getColor(1))
		local p0Color2SGB    = convert32BitTo15BitColor(paletteSGB0:getColor(2))
		local p0Color3SGB    = convert32BitTo15BitColor(paletteSGB0:getColor(3))
		--Write to the .inc file
		incFile:write(";Color Data\n")
		incFile:write(".DW " .. "$" .. string.format("%04X", sharedColorSGB) .. " ")
		incFile:write("$" .. string.format("%04X", p0Color1SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p0Color2SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p0Color3SGB) .. " ")

		--Write the second half of the palette data for the first packet
		if data.headerType == "Export 4 palettes" or data.headerType == "Export 0 & 1" then
			--Convert the colors in the 1st palette to 15-bit SGB color
			local p1Color1SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(1))
			local p1Color2SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(2))
			local p1Color3SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(3))
			--Write to the .inc file
			incFile:write("$" .. string.format("%04X", p1Color1SGB) .. " ")
			incFile:write("$" .. string.format("%04X", p1Color2SGB) .. " ")
			incFile:write("$" .. string.format("%04X", p1Color3SGB))
			--And pad out the rest of the data packet
			incFile:write("\n;Extra Byte")
			incFile:write("\n.DB $00")
			incFile:write("\n;End of SGB Packet")

			--Write the second data packet
			if data.headerType == "Export 4 palettes" then
				--Convert the colors in the 2nd palette to 15-bit SGB color
				local p2Color1SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(1))
				local p2Color2SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(2))
				local p2Color3SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(3))
				--Write to the .inc file
				incFile:write("\n\n;Data for 16 byte packet that sets SGB Palettes 2 and 3\n") 
				incFile:write(";Header\n")
				incFile:write(".DB $09\n")
				incFile:write(";Color Data\n")
				incFile:write(".DW " .. "$" .. string.format("%04X", sharedColorSGB) .. " ")
				incFile:write("$" .. string.format("%04X", p2Color1SGB) .. " ")
				incFile:write("$" .. string.format("%04X", p2Color2SGB) .. " ")
				incFile:write("$" .. string.format("%04X", p2Color3SGB) .. " ")
				--Export 4 palettes will finish up in next IF statement
			end
		end
	end
	--Write the first half of the data packet
	if data.headerType == "Export 2 & 3" then
		--Convert the colors in the 0th palette to 15-bit SGB color
		local p2Color1SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(1))
		local p2Color2SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(2))
		local p2Color3SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(3))
		--Write to the .inc file
		incFile:write(";Color Data\n")
		incFile:write(".DW " .. "$" .. string.format("%04X", sharedColorSGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color1SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color2SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color3SGB) .. " ")
	end
	--Write the second half of the data packet
	if data.headerType == "Export 0 & 3" or data.headerType == "Export 4 palettes" or data.headerType == "Export 2 & 3"then
		--Convert the colors in the 1st palette to 15-bit SGB color
		local p3Color1SGB    = convert32BitTo15BitColor(paletteSGB3:getColor(1))
		local p3Color2SGB    = convert32BitTo15BitColor(paletteSGB3:getColor(2))
		local p3Color3SGB    = convert32BitTo15BitColor(paletteSGB3:getColor(3))
		--Write to the .inc file
		incFile:write("$" .. string.format("%04X", p3Color1SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p3Color2SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p3Color3SGB))
		--And pad out the rest of the data packet
		incFile:write("\n;Extra Byte")
		incFile:write("\n.DB $00")
		incFile:write("\n;End of SGB Packet")
	end
	--Write both halves of the packet for exporting to palettes 1 and 2
	if data.headerType == "Export 1 & 2" then
		--Convert the colors in the 0th palette to 15-bit SGB color
		local p1Color1SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(1))
		local p1Color2SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(2))
		local p1Color3SGB    = convert32BitTo15BitColor(paletteSGB1:getColor(3))
		local p2Color1SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(1))
		local p2Color2SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(2))
		local p2Color3SGB    = convert32BitTo15BitColor(paletteSGB2:getColor(3))
		--Write to the .inc file
		incFile:write(";Color Data\n")
		incFile:write(".DW " .. "$" .. string.format("%04X", sharedColorSGB) .. " ")
		incFile:write("$" .. string.format("%04X", p1Color1SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p1Color2SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p1Color3SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color1SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color2SGB) .. " ")
		incFile:write("$" .. string.format("%04X", p2Color3SGB))
		--And pad out the rest of the data packet
		incFile:write("\n;Extra Byte")
		incFile:write("\n.DB $00")
		incFile:write("\n;End of SGB Packet")
	end
	

	incFile:close()

end





