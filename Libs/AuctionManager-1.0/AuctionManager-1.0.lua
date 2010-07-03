local AuctionManager, oldminor = LibStub:NewLibrary("AuctionManager-1.0", 1)

if not AuctionManager then return end

AuctionManager.database = {}
AuctionManager.scan_queue = {}
AuctionManager.last_scanned = {}
AuctionManager.buy_queue = {}
AuctionManager.temp_buy_queue = {}
AuctionManager.selected_buys = {}
AuctionManager.scanning = false
AuctionManager.buying   = false

AuctionManager.on_scan = function(item, page) end
AuctionManager.on_scan_complete = function() end
AuctionManager.on_buy_approval = function(name, count, cost) end

-- PUBLIC API ################################################################

function AuctionManager:Scan(name)
  if self:AlreadyScanned(name) then return end
  self.scanning = true
  self.last_scanned[name] = GetTime()
  self:ClearItem(name)
  self.scan_queue[name] = 0
  self:StartScanning()
  self:ScheduleTimer("ScanNext", 0.5)
end

function AuctionManager:Buy(name, count)
  self:Print("will buy "..count.." of "..name)
  self.buying = true
  self.buy_queue[name] = count
  self.scan_queue[name] = 0
  self:StartScanning()
end

function AuctionManager:MinimumPrice(name)
  local prices = {}
  self:EachItem(name, function(item)
    table.insert(prices, item.price)
  end)
  table.sort(prices)
  return prices[1]
end

function AuctionManager:MedianPrice(name)
  local prices = {}
  self:EachItem(name, function(item)
    table.insert(prices, item.price)
  end)
  table.sort(prices)
  return prices[math.floor(#prices/2)]
end

function AuctionManager:AvailableUnderMedian(name)
  local median = self:MedianPrice(name)
  local count  = 0
  if not median then return nil end
  self:EachItem(name, function(item)
    if item.price <= median then
      count = count + item.count
    end
  end)
  return count
end

-- EVENTS ####################################################################

function AuctionManager:OnScan(func)
  AuctionManager.on_scan = func
end

function AuctionManager:OnScanComplete(func)
  AuctionManager.on_scan_complete = func
end

function AuctionManager:OnBuyApproval(func)
  AuctionManager.on_buy_approval = func
end

-- PRIVATE ###################################################################

function AuctionManager:AlreadyScanned(name)
  if self.last_scanned[name] then
    if self.last_scanned[name] > (GetTime() - 30) then
      return true
    end
  end
  return false
end

function AuctionManager:EachItem(name, func)
  local i
  if not self.database[name] then return end
  for _, item in pairs(self.database[name]) do
    func(item)
  end
end

function AuctionManager:StartScanning()
  if not self.scanning then
    self:ScheduleTimer("ScanNext", 0.5)
  end
end

function AuctionManager:ClearItem(item)
  self.database[item] = {}
end

function AuctionManager:SaveItem(item)
  if not self.database[item.name] then
    self.database[item.name] = {}
  end
  table.insert(self.database[item.name], item)
end

function AuctionManager:ScanNext()
  if not CanSendAuctionQuery() then
    if self.scanning then
      self:ScheduleTimer("ScanNext", 0.5)
      return
    end
  end

  local item, page

  for item, page in pairs(self.scan_queue) do
    if page then
      self.scan_auction_item = item
      self.scan_auction_page = page
      self.on_scan(item, page)
      --self:Print("scanning reagent "..item.." on page "..page)
      QueryAuctionItems(item, nil, nil, 0, 0, 0, page)
      return
    end
  end

  self.scanning = false
  self.buying = false
  self.on_scan_complete()
end

function AuctionManager:AUCTION_ITEM_LIST_UPDATE()
  if not (self.scanning or self.buying) then return end

  self:Print("scan happened")

  local num_auctions = GetNumAuctionItems("list")
  local name, texture, count, quality, canUse, level, minBid, minIncrement
  local buyoutPrice, bidAmount, highBidder, owner, saleStatus
  local i, item

  if num_auctions == 0 then
    self.scan_queue[self.scan_auction_item] = nil
  else
    num_ownerless = 0
    for i = 1, num_auctions do
      name, texture, count, quality, canUse, level, minBid, minIncrement,
      buyoutPrice, bidAmount, highBidder, owner,
      saleStatus = GetAuctionItemInfo("list", i);
      if not owner then num_ownerless = num_ownerless + 1 end
    end

    if num_ownerless > 0 then return end

    for item, count in pairs(AuctionManager.temp_buy_queue) do
      AuctionManager.temp_buy_queue[item] = nil
    end

    for item, count in pairs(AuctionManager.buy_queue) do
      AuctionManager.temp_buy_queue[item] = count
    end

    self:Print("temp buy queue")
    for item, count in pairs(AuctionManager.temp_buy_queue) do
      self:Print(item.." "..count)
    end

    local items = {}

    for i = 1, num_auctions do
      name, texture, count, quality, canUse, level, minBid, minIncrement,
      buyoutPrice, bidAmount, highBidder, owner,
      saleStatus = GetAuctionItemInfo("list", i);

      if self.scan_auction_item == name then
        item = {
          name  = name,
          count = count,
          page  = self.scan_auction_page,
          price = math.floor(buyoutPrice / count / 100) / 100,
          total = math.floor(buyoutPrice / 100) / 100,
          index = i,
          real_total = buyoutPrice
        }
      end
      table.insert(items, item)
    end

    table.sort(items, function(a, b)
      return a.price < b.price
    end)

    for _, item in pairs(items) do
      if self.scanning then self:ParseScan(item) end
      if self.buying then self:ParseBuy(item) end
    end

    self.scan_queue[self.scan_auction_item] = self.scan_queue[self.scan_auction_item] + 1
  end

  if self.scanning then self:ScheduleTimer("ScanNext", 0.5) end
  if self.buying then self:PresentBuysForApproval() end
end

function AuctionManager:ParseScan(item)
  self:SaveItem(item)
end

function AuctionManager:ParseBuy(item)
  if self.buy_queue[item.name] <= 0 then return end

  if item.price <= self:MedianPrice(item.name) then
    if self.temp_buy_queue[item.name] > 0 then
      self:Print("selected "..item.index.." to be bought for "..item.real_total)
      self.selected_buys[item.index] = item
      self.temp_buy_queue[item.name] = self.temp_buy_queue[item.name] - item.count
    end
  end
end

function AuctionManager:PresentBuysForApproval()
  local count = 0
  local cost = 0
  local name

  for index, item in pairs(self.selected_buys) do
    name = item.name
    count = count + item.count
    cost = cost + item.total
  end

  if count > 0 then
    self:Print("seeking approval")
    self.buying = false
    self.on_buy_approval(name, count, cost)
  else
    self:Print("continuing scan")
    self:ScheduleTimer("ScanNext", 0.5)
  end
end

function AuctionManager:ApproveBuys()
  local item

  for _, item in pairs(self.selected_buys) do
    self.buy_queue[item.name] = self.buy_queue[item.name] - item.count
    PlaceAuctionBid("list", item.index, item.real_total)
    self.selected_buys[index] = nil
  end

  self:Print("continuing scan")
  self.buying = true
  self:ScheduleTimer("ScanNext", 3)
end

function AuctionManager:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(message)
end

-- SETUP #####################################################################

local AceEvent = LibStub("AceEvent-3.0")
local AceTimer = LibStub("AceTimer-3.0")

AceEvent:Embed(AuctionManager)
AceTimer:Embed(AuctionManager)

AuctionManager:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
