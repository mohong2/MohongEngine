--无敌的黑化制作
Notes = 0
mustPress = 1
function onEvent(name,value1,value2)
if name == 'Change Character' then
if value1 == '0' or value1 == 'bf' then
bfimage = getProperty('boyfriend.imageFile')
bfframe = getProperty('boyfriend.animation.frameName')
bfx = getProperty('boyfriend.x')
bfy = getProperty('boyfriend.y')
bfscaleX = getProperty('boyfriend.scale.x')
bfscaleY = getProperty('boyfriend.scale.y')
bfoffsetX = getProperty('boyfriend.offset.x')
bfoffsetY = getProperty('boyfriend.offset.y')
bfflipX = getProperty('boyfriend.flipX')
bfflipY = getProperty('boyfriend.flipY')
removeLuaSprite('bfPhantom',true)
Notes = 0
end
end
end
function onCreatePost()
for i=0,getProperty('unspawnNotes.length') do
if not getPropertyFromGroup('unspawnNotes',i+1,'mustPress') then
mustPress = 2
if not getPropertyFromGroup('unspawnNotes',i+2,'mustPress') then
mustPress = 3
end
end
if getPropertyFromGroup('unspawnNotes',i,'mustPress') and not getPropertyFromGroup('unspawnNotes',i,'isSustainNote') and not getPropertyFromGroup('unspawnNotes',i+mustPress,'isSustainNote') and getPropertyFromGroup('unspawnNotes',i,'strumTime') == getPropertyFromGroup('unspawnNotes',i+mustPress,'strumTime') and getPropertyFromGroup('unspawnNotes',i,'noteType') == '' then
setPropertyFromGroup('unspawnNotes',i,'noteType','bfPhantom')
end
mustPress = 1
end
bfimage = getProperty('boyfriend.imageFile')
bfframe = getProperty('boyfriend.animation.frameName')
bfx = getProperty('boyfriend.x')
bfy = getProperty('boyfriend.y')
bfscaleX = getProperty('boyfriend.scale.x')
bfscaleY = getProperty('boyfriend.scale.y')
bfoffsetX = getProperty('boyfriend.offset.x')
bfoffsetY = getProperty('boyfriend.offset.y')
bfflipX = getProperty('boyfriend.flipX')
bfflipY = getProperty('boyfriend.flipY')
setObjectOrder('bfPhantom',getObjectOrder('boyfriendGroup')-1)
end
function goodNoteHit(id,direction,noteType,isSustainNote)
if not isSustainNote and noteType == 'bfPhantom' then
Notes = Notes + 1
makeAnimatedLuaSprite('bfPhantom',bfimage,bfx,bfy)
addAnimationByPrefix('bfPhantom','b',bfframe,24,false)
addLuaSprite('bfPhantom',false)
setProperty('bfPhantom.offset.x',bfoffsetX)
setProperty('bfPhantom.offset.y',bfoffsetY)
setProperty('bfPhantom.alpha',0.5)
runTimer('alphaalpha',0.3)
if Notes == 1 then
setProperty('bfPhantom.scale.x',bfscaleX)
setProperty('bfPhantom.scale.y',bfscaleY)
setProperty('bfPhantom.flipX',bfflipX)
setProperty('bfPhantom.flipY',bfflipY)
setObjectOrder('bfPhantom',getObjectOrder('boyfriendGroup')-1)
end
bfimage = getProperty('boyfriend.imageFile')
bfframe = getProperty('boyfriend.animation.frameName')
bfoffsetX = getProperty('boyfriend.offset.x')
bfoffsetY = getProperty('boyfriend.offset.y')
if Notes == 1 then
bfx = getProperty('boyfriend.x')
bfy = getProperty('boyfriend.y')
bfscaleX = getProperty('boyfriend.scale.x')
bfscaleY = getProperty('boyfriend.scale.y')
bfflipX = getProperty('boyfriend.flipX')
bfflipY = getProperty('boyfriend.flipY')
end
end
end
function onTimerCompleted(tag)
if tag == 'alphaalpha' then
doTweenAlpha('bfPhantom','bfPhantom',0,0.5,'linear')
end
if tag == 'removeLuaSprite' then
removeLuaSprite('bfPhantom',true)
end
end
--无敌的黑化制作