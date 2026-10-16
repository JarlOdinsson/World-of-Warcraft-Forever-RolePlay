local Fixture = dofile("tests/helpers/client_fixture.lua")
local checks, cases = 0, 0
local function Check(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)); checks=checks+1 end
local peer="Spencer Raven-ClassicBetaPvE2"
local base="A2|v|0|public|10|1|100.0|200.0|1|IC|NORMAL|0|"
local layer="L1|10|4621:0:1469|3|0|99:3"
local function Snapshot(session,seq,body,proof)
    return "A3|"..session.."|"..seq.."|"..(body=="OFF" and body or (body or base).."~"..(proof or layer))
end
local function Test(name,run)
    local f=Fixture(); local a=ForeverRP.Activity
    ForeverRP.Database:SetActivitySetting("enabled",true); a:Initialize(); a:Tick()
    dofile("experiments/beta17/Discovery/LayerEvidence.lua")
    run(f,a,ForeverRP); cases=cases+1; print("PASS "..name)
end
local function Last(a) return a.trace.records[#a.trace.records] end
Test("channel validation uses receiver metadata and excludes unknown isolation arrivals",function(f,a,addon)
    a:SetChannelOnly(true)
    for _,p in ipairs({base,"T1|test",layer,"OFF",Snapshot("s",1)}) do
        Check(a:Receive(p,"CHANNEL",peer,99,"OtherChannel"),false)
        Check(Last(a).reason,"unrelated-channel-id")
        Check(a:Receive(p,"CHANNEL",peer,nil,nil),false)
        Check(Last(a).reason,"channel-unverifiable")
        Check(a:Receive(p,"CHANNEL",peer,f.secret,f.secret),false)
    end
    Check(#a:QueryDirectory(),0)
    Check(a:Receive("T1|test","CHANNEL",peer,7,nil),true)
    Check(a:Receive("T1|test","CHANNEL",peer,nil,"foreverrpactivity"),true)
    Check(a:Receive("T1|test","CHANNEL",peer,7,"OtherChannel"),false)
    Check(a:Receive(Snapshot("s",1),"CHANNEL",peer,7,"ForeverRPActivity"),true)
    Check(#a:QueryDirectory(),1)
    GetChannelName=function() return 12 end
    Check(a:Receive("T1|test","CHANNEL",peer,7,"ForeverRPActivity"),false)
    Check(a:Receive("T1|test","CHANNEL",peer,12,"ForeverRPActivity"),true)
end)
Test("ordered withdrawal fences older snapshots and all legacy copies across routes",function(f,a,addon)
    Check(a:Receive(Snapshot("s",1),"GUILD",peer),true)
    local entry=a:GetPeer(peer); Check(entry.x,100); Check(entry.layerEvidence.at,100)
    f.now=110
    Check(a:Receive(Snapshot("s",1),"PARTY",peer),false)
    Check(Last(a).outcome,"duplicate"); Check(entry.at,100)
    Check(a:Receive(base,"PARTY",peer),false); Check(Last(a).reason,"legacy-after-ordered")
    Check(a:Receive(Snapshot("s",2,"OFF"),"GUILD",peer),true)
    Check(a:GetPeer(peer),nil)
    for _,p in ipairs({Snapshot("s",1),base,"A1|v|0|public|10|1|100|200",layer,"OFF"}) do
        Check(a:Receive(p,"CHANNEL",peer,7,"ForeverRPActivity"),false)
        Check(a:GetPeer(peer),nil)
    end
    a:SetChannelOnly(true); a:SetChannelOnly(false)
    Check(a:Receive(base,"GUILD",peer),false)
    local hidden="A2|v|0|public|0|-|-|-|1|IC|NORMAL|0|"
    Check(a:Receive(Snapshot("s",3,hidden,"L1|OFF"),"GUILD",peer),true)
    Check(a:GetPeer(peer).x,nil); Check(a:GetPeer(peer).layerEvidence,nil)
    Check(a:Receive(Snapshot("s",2,"OFF"),"PARTY",peer),false)
    Check(a:GetPeer(peer).zone,0)
end)
Test("malformed envelopes cannot consume generations or lock out valid peers",function(f,a)
    Check(a:Receive("A3|s|100|bad","GUILD",peer),false)
    Check(a:OrderState("directory",peer),nil)
    Check(a:Receive("A3|s|100|A2|broken~L1|OFF","GUILD",peer),false)
    Check(a:OrderState("directory",peer),nil)
    Check(a:Receive(Snapshot("s",1),"GUILD",peer),true)
    Check(a:Receive("A3|s|0|OFF","GUILD",peer),false)
    Check(a:Receive("A3|s|1000000000|OFF","GUILD",peer),false)
    Check(a:GetPeer(peer)~=nil,true)
end)
Test("layer high water survives newer evidence withdrawals and lost listing objects",function(f,a,addon)
    Check(a:Receive(base,"GUILD",peer),true)
    Check(a:Receive(layer,"GUILD",peer),true)
    f.now=110
    local newer="L1|10|4621:0:506|3|0|99:4"
    Check(a:Receive(newer,"GUILD",peer),true)
    f.now=120
    Check(a:Receive(layer,"PARTY",peer),false)
    Check(a:GetPeer(peer).layerEvidence.id,"4621:0:506")
    Check(a:Receive(newer,"PARTY",peer),false)
    Check(a:GetPeer(peer).layerEvidence.at,110)
    Check(a:Receive("L1|OFF","GUILD",peer),true)
    Check(a:Receive(newer,"GUILD",peer),false); Check(a:GetPeer(peer).layerEvidence,nil)
    Check(a:Receive("OFF","GUILD",peer),true)
    f.now=130; Check(a:Receive(base,"GUILD",peer),true)
    Check(a:Receive(layer,"GUILD",peer),false)
    Check(a:Receive(newer,"GUILD",peer),false)
    Check(a:Receive("L1|10|4621:0:506|3|0|99:5","GUILD",peer),true)
    Check(a:GetPeer(peer).layerEvidence.at,130)
end)
Test("opaque session changes require quiet then retire previous sessions",function(f,a)
    Check(a:Receive(Snapshot("zzz",100),"GUILD",peer),true)
    f.now=110; Check(a:Receive(Snapshot("aaa",1),"GUILD",peer),false)
    Check(Last(a).reason,"session-change-awaiting-quiet")
    f.now=249; Check(a:Receive(Snapshot("zzz",100),"PARTY",peer),false)
    f.now=250; Check(a:Receive(Snapshot("aaa",1),"GUILD",peer),true)
    Check(a:OrderState("directory",peer).session,"aaa")
    f.now=410; Check(a:Receive(Snapshot("zzz",101),"GUILD",peer),false)
    Check(Last(a).reason,"retired-session")
    -- Layer sessions use the same equality/retirement policy, independently.
    Check(a:Receive(base,"GUILD","Cheese Spy-Realm"),true)
    Check(a:Receive(layer,"GUILD","Cheese Spy-Realm"),true)
    Check(a:Receive("L1|10|4621:0:506|3|0|1:1","GUILD","Cheese Spy-Realm"),false)
    f.now=560; Check(a:Receive(base,"GUILD","Cheese Spy-Realm"),true)
    Check(a:Receive("L1|10|4621:0:506|3|0|1:1","GUILD","Cheese Spy-Realm"),true)
    Check(a:Receive("L1|10|4621:0:1469|3|0|99:100","GUILD","Cheese Spy-Realm"),false)
end)
Test("bounded guard capacity does not evict active tombstones and expires explicitly",function(f,a)
    a.orderCap=2
    Check(a:Receive(Snapshot("s",1,"OFF"),"GUILD","One-Realm"),true)
    Check(a:Receive(Snapshot("s",1,"OFF"),"GUILD","Two-Realm"),true)
    Check(a:Receive(Snapshot("s",1),"GUILD","Three-Realm"),false)
    Check(Last(a).reason,"ordering-capacity")
    f.now=1899; Check(a:Receive(Snapshot("s",1,"OFF"),"GUILD","One-Realm"),false)
    Check(a:Receive(base,"GUILD","One-Realm"),false)
    f.now=1900; a:PruneOrdering()
    Check(next(a.orderBanks.directory),nil)
    Check(a:Receive(Snapshot("new",1),"GUILD","Three-Realm"),true)
    -- This explicitly demonstrates the bounded-retention limit, not permanent replay protection.
    Check(a:Receive(base,"GUILD","One-Realm"),true)
end)
Test("atomic snapshot keeps layer age on duplicate proof and excludes legacy layer overwrite",function(f,a)
    Check(a:Receive(Snapshot("s",1),"GUILD",peer),true)
    f.now=160; Check(a:Receive(Snapshot("s",2),"GUILD",peer),true)
    Check(a:GetPeer(peer).layerEvidence.at,100)
    Check(a:Receive("L1|OFF","PARTY",peer),false)
    Check(a:GetPeer(peer).layerEvidence.at,100)
    Check(a:Receive(Snapshot("s",3,base,"L1|OFF"),"GUILD",peer),true)
    Check(a:GetPeer(peer).layerEvidence,nil)
    Check(a:Receive(Snapshot("s",4),"GUILD",peer),true)
    Check(a:GetPeer(peer).layerEvidence,nil) -- same proof cannot undo withdrawal
end)
Test("session history is capped without discarding retired-session protection",function(f,a)
    Check(a:Receive(Snapshot("s0",1,"OFF"),"GUILD",peer),true)
    for i=1,8 do
        f.now=100+i*150
        Check(a:Receive(Snapshot("s"..i,1,"OFF"),"GUILD",peer),true)
    end
    f.now=f.now+150
    Check(a:Receive(Snapshot("s9",1),"GUILD",peer),false)
    Check(Last(a).reason,"session-history-full")
    Check(a:Receive(Snapshot("s0",100),"GUILD",peer),false)
    Check(Last(a).reason,"retired-session")
    Check(a:Receive(Snapshot("s8",2,"OFF"),"GUILD",peer),true)
    f.now=f.now+1800; a:PruneOrdering()
    Check(a:OrderState("directory",peer),nil)
end)
Test("oversized optional fields cannot exceed the wire bound or prevent a snapshot",function(f,a)
    local big="A2|"..string.rep("v",32).."|999999999|connections|99999|99999|100000.0|100000.0|1|LFRP|NORMAL|99999|"..string.rep("Z",64)
    local proof="L1|99999|999999999:999999999:999999999|8|119|999999999:999999999"
    local wire=a:OrderedPayload(big,proof)
    Check(type(wire),"string"); Check(#wire<=200,true)
    Check(wire:sub(-6),"L1|OFF")
    Check(a:Receive(wire,"GUILD",peer),true)
    Check(a:GetPeer(peer).layerEvidence,nil)
    local before=a:OrderState("directory",peer).at
    f.now=f.now+10; Check(a:Receive(wire,"PARTY",peer),false)
    Check(a:OrderState("directory",peer).at,before)
end)
Test("real sender packet bounds legacy stages and monotonic withdrawal sequence",function(f,a,addon)
    addon.Profile:SetField("status","IC")
    addon.Database:SetActivitySetting("directory",true)
    addon.Database:SetActivitySetting("location","precise")
    f.subzone=string.rep("Z",64); addon.Database:SetActivitySetting("subzone",true)
    f.now=130; a:Tick(); f.now=131; a:Tick(); f.now=132; a:Tick()
    local ordered,legacy
    for _,p in ipairs(f.sent) do
        Check(#p.payload<=200,true)
        if p.payload:sub(1,3)=="A3|" then ordered=p.payload end
        if p.payload:sub(1,3)=="A2|" then legacy=p.payload end
    end
    Check(ordered~=nil,true); Check(legacy~=nil,true)
    local seq=tonumber(ordered:match("^A3|[^|]+|(%d+)|"))
    f.now=150; a:Withdraw()
    local off=f.sent[#f.sent-1].payload
    Check(off:match("^A3|[^|]+|%d+|OFF$")~=nil,true)
    Check(tonumber(off:match("^A3|[^|]+|(%d+)|"))>seq,true)
    Check(#a.queue,0); Check(f.sent[#f.sent].payload,"OFF")
    if arg and arg[1] then
        dofile(arg[1].."/Discovery/Activity.lua")
        local old=addon.Activity
        Check(old:Receive(ordered,"GUILD",peer),false)
        Check(old:Receive(legacy,"GUILD",peer),true)
        Check(#old:QueryDirectory(),1)
        Check(old:Receive("OFF","GUILD",peer),true)
        Check(#old:QueryDirectory(),0)
    end
end)
print(string.format("PASS: %d ordering cases; %d checks",cases,checks))
