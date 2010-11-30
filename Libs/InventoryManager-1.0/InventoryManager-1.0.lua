local InventoryManager, oldminor = LibStub:NewLibrary("InventoryManager-1.0", 1)

if not InventoryManager then return end

InventoryManager.database = {}

-- PUBLIC API ################################################################

function InventoryManager:Scan()
  self:Clear()

  local container, slot
  local item_link
  local color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique, link_level, name
  local texture, itemCount, locked, quality, readable

  for container = 0, 4 do
     for slot = 1, GetContainerNumSlots(container) do
       item_link = GetContainerItemLink(container, slot)
       if item_link then
         color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique,
           link_level, name = self:ParseItemLink(item_link)
         texture, itemCount, locked, quality, readable = GetContainerItemInfo(container, slot)
         if not self.database[name] then
           self.database[name] = 0
         end
         self.database[name] = self.database[name] + itemCount
       end
     end
  end
end

function InventoryManager:Clear()
  for item, num in pairs(self.database) do
    self.database[item] = nil
  end
end

function InventoryManager:OnHand(name)
  if self.database[name] then
    return self.database[name]
  else
    return 0
  end
end

function InventoryManager:Use(use_name)
  local container, slot
  local item_link
  local color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique, link_level, name
  local texture, itemCount, locked, quality, readable

  for container = 0, 4 do
     for slot = 1, GetContainerNumSlots(container) do
       item_link = GetContainerItemLink(container, slot)
       if item_link then
         color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique,
           link_level, name = self:ParseItemLink(item_link)
         texture, itemCount, locked, quality, readable = GetContainerItemInfo(container, slot)

         if use_name == name then
           UseContainerItem(container, slot)
          end
       end
     end
  end
end

-- PRIVATE ###################################################################

function InventoryManager:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(message)
end

function InventoryManager:ParseItemLink(link)
  local _, _, color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique, link_level, unk, name =
    string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
  return color, ltype, id, enchant, gem1, gem2, gem3, gem4, suffix, unique, link_level, name
end

-- SETUP #####################################################################

local AceEvent = LibStub("AceEvent-3.0")

AceEvent:Embed(InventoryManager)

--InventoryManager:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
