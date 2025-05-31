--无敌的黑化制作
dadNotes = 0
dadmustPress = 1
function onEvent(name,value1,value2)
if name == 'Change Character' then
if value1 == '1' or value1 == 'dad' then
dadimage = getProperty('dad.imageFile')
dadframe = getProperty('dad.animation.frameName')
dadx = getProperty('dad.x')
dady = getProperty('dad.y')
dadscaleX = getProperty('dad.scale.x')
dadscaleY = getProperty('dad.scale.y')
dadoffsetX = getProperty('dad.offset.x')
dadoffsetY = getProperty('dad.offset.y')
dadflipX = getProperty('dad.flipX')
dadflipY = getProperty('dad.flipY')
removeLuaSprite('dadPhantom',true)
Notes = 0
end
end
end
function onCreatePost()
for i=0,getProperty('unspawnNotes.length') do
if getPropertyFromGroup('unspawnNotes',i+1,'mustPress') then
dadmustPress = 2
if getPropertyFromGroup('unspawnNotes',i+2,'mustPress') then
dadmustPress = 3
end
end
if not getPropertyFromGroup('unspawnNotes',i,'mustPress') and not getPropertyFromGroup('unspawnNotes',i,'isSustainNote') and not getPropertyFromGroup('unspawnNotes',i+dadmustPress,'isSustainNote') and getPropertyFromGroup('unspawnNotes',i,'strumTime') == getPropertyFromGroup('unspawnNotes',i+dadmustPress,'strumTime') and getPropertyFromGroup('unspawnNotes',i,'noteType') == '' then
setPropertyFromGroup('unspawnNotes',i,'noteType','dadPhantom')
end
dadmustPress = 1
end
dadimage = getProperty('dad.imageFile')
dadframe = getProperty('dad.animation.frameName')
dadx = getProperty('dad.x')
dady = getProperty('dad.y')
dadscaleX = getProperty('dad.scale.x')
dadscaleY = getProperty('dad.scale.y')
dadoffsetX = getProperty('dad.offset.x')
dadoffsetY = getProperty('dad.offset.y')
dadflipX = getProperty('dad.flipX')
dadflipY = getProperty('dad.flipY')
setObjectOrder('dadPhantom',getObjectOrder('dadGroup')-1)
end
function opponentNoteHit(id,direction,noteType,isSustainNote)
if not isSustainNote and noteType == 'dadPhantom' then
dadNotes = dadNotes + 1
makeAnimatedLuaSprite('dadPhantom',dadimage,dadx,dady)
addAnimationByPrefix('dadPhantom','b',dadframe,24,false)
addLuaSprite('dadPhantom',false)
setProperty('dadPhantom.offset.x',dadoffsetX)
setProperty('dadPhantom.offset.y',dadoffsetY)
setProperty('dadPhantom.alpha',0.5)
runTimer('alphaalpha',0.3)
if dadNotes == 1 then
setProperty('dadPhantom.scale.x',dadscaleX)
setProperty('dadPhantom.scale.y',dadscaleY)
setProperty('dadPhantom.flipX',dadflipX)
setProperty('dadPhantom.flipY',dadflipY)
setObjectOrder('dadPhantom',getObjectOrder('dadGroup')-1)
end
dadimage = getProperty('dad.imageFile')
dadframe = getProperty('dad.animation.frameName')
dadoffsetX = getProperty('dad.offset.x')
dadoffsetY = getProperty('dad.offset.y')
if dadNotes == 1 then
dadx = getProperty('dad.x')
dady = getProperty('dad.y')
dadscaleX = getProperty('dad.scale.x')
dadscaleY = getProperty('dad.scale.y')
dadflipX = getProperty('dad.flipX')
dadflipY = getProperty('dad.flipY')
end
end
end
function onTimerCompleted(tag)
if tag == 'alphaalpha' then
doTweenAlpha('dadPhantom','dadPhantom',0,0.5,'linear')
end
if tag == 'removeLuaSprite' then
removeLuaSprite('dadPhantom',true)
end
end
--无敌的黑化制作